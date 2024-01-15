/// Handles the initialization and maintenance tasks of the service
module service;

import app;
import config;
import helpers;
import api;
import winscripts;
import winmultiling;
version(Windows)
{
	import vibe.daemonize.windows;
	import winregistry : getComputerName;
}

import vibe.core.core;
import vibe.core.log : setLogLevel, setLogFile, CimonsLogLevel = LogLevel;
import vibe.stream.operations;
import vibe.inet.message : InetHeaderMap;
import vibe.http.client;
import vibe.http.server;
import vibe.http.proxy;
import vibe.http.router;
import vibe.web.web;

import vibe.data.json;

import vibe.db.sqlite.sqlite3;
import std.datetime;
import std.exception;	

import vibe.stream.tls;
import vibe.stream.botan;
import botan.tls.session_manager_sqlite;
import botan.rng.auto_rng;
import memutils.unique;
import std.functional : toDelegate;
import std.algorithm : startsWith;
import core.sync.condition;
import core.sync.mutex;
import std.conv : to;
// Simple daemon description


version(Windows)
alias daemon = Daemon!(
	"cimonsclient",
	MultilingualDict,
	KeyValueList!(
		Composition!(Signal.Terminate, Signal.HangUp, Signal.Quit, Signal.Shutdown, Signal.Stop), ()
		{
			exitEventLoop(true);
			return true; 
		}
		),

	(shouldExit) {
		if (shouldExit()) {
			exitEventLoop(true);
			return true;
		} else {
			runCimons();
			return g_restart;
		}
	}
	);


private void sendFile(scope HTTPServerRequest req, scope HTTPServerResponse res, string pathstr)
{
	import vibe.inet.message;
	import vibe.inet.mimetypes;
	import vibe.inet.url;
	import std.digest.md;
	res.headers.insert("Access-Control-Allow-Origin", "*");
	res.headers.insert("Access-Control-Allow-Credentials", "true");
	res.headers.insert("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
	res.headers.insert("Access-Control-Allow-Headers", "DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type");

	// return if the file does not exist
	if (!existsFile(pathstr))
		throw new HTTPStatusException(HTTPStatus.NotFound);
	
	FileInfo dirent;
	try dirent = getFileInfo(pathstr);
	catch(Exception){
		throw new HTTPStatusException(HTTPStatus.InternalServerError, "Failed to get information for the file due to a file system error.");
	}
	
	if (dirent.isDirectory)
		return;	
	auto lastModified = toRFC822DateTimeString(dirent.timeModified.toUTC());
	// simple etag generation
	auto etag = "\"" ~ hexDigest!MD5(pathstr ~ ":" ~ lastModified ~ ":" ~ to!string(dirent.size)).idup ~ "\"";
	
	res.headers["Last-Modified"] = lastModified;
	res.headers["Etag"] = etag;
	res.headers["Cache-Control"] = "must-revalidate, private";
	res.headers["Expires"] = "-1";

	
	if( auto pv = "If-Modified-Since" in req.headers ) {
		if( *pv == lastModified ) {
			res.statusCode = HTTPStatus.NotModified;
			res.writeVoidBody();
			return;
		}
	}
	
	if( auto pv = "If-None-Match" in req.headers ) {
		if ( *pv == etag ) {
			res.statusCode = HTTPStatus.NotModified;
			res.writeVoidBody();
			return;
		}
	}
	
	auto mimetype = getMimeTypeForFile(pathstr);
	// avoid double-compression
	if ("Content-Encoding" in res.headers && isCompressedFormat(mimetype))
		res.headers.remove("Content-Encoding");
	res.headers["Content-Type"] = mimetype;

	FileStream fil;
	try {
		fil = openFile(pathstr);
	} catch( Exception e ){
		return;
	}
	scope(exit) fil.close();
	try {

		if (auto ptr = "Range" in req.headers) {
			import std.algorithm : splitter;
			import std.array : array;
			import std.exception : enforce;
			string hdr = cast(string) *ptr;
			enforce(hdr.startsWith("bytes="));
			hdr = hdr["bytes=".length .. $];
			string[] rng = splitter(hdr, "-").array.to!(string[]);
			ulong end = (rng[1] != "") ? rng[1].to!ulong : (dirent.size.to!ulong - 1);
			ulong len = end - to!ulong(rng[0]) + 1;
			res.headers["Content-Range"] = "bytes " ~ rng[0] ~ "-" ~ to!string(end) ~ "/" ~ to!string(dirent.size); 
			res.headers["Content-Length"] = len.to!string;
			// for HEAD responses, stop here
			if( res.isHeadResponse() ){
				res.writeVoidBody();
				assert(res.headerWritten);
				return;
			}
			fil.seek(rng[0].to!ulong);

			res.writeRawBody(fil, 206, cast(size_t) len);
		}
		else {	// for HEAD responses, stop here
			if( res.isHeadResponse() ){
				res.writeVoidBody();
				assert(res.headerWritten);
				return;
			}
			res.headers["Content-Length"] = to!string(dirent.size);
			res.writeRawBody(fil);
		}
	} catch (Exception e) {
		logErrorFile("Exception writing output for sendFile: %s", e.toString());
	}

}
import vibe.http.cookiejar;
auto runCimons(bool open_browser = false) 
{
	import core.thread;
	import vibe.http.debugger;
	import vibe.core.log : LogLevel;
	//setLogLevel(LogLevel.trace);
	if (existsFile(DATA_FOLDER_PATH() ~ "runtime.log"))
		removeFile(DATA_FOLDER_PATH() ~ "runtime.log");
	version(CimonsRequestDebugger)
		setLogFile(DATA_FOLDER_PATH() ~ "runtime.log", CimonsLogLevel.debug_);
	else	setLogFile(DATA_FOLDER_PATH() ~ "runtime.log", CimonsLogLevel.error);

	URLRouter router = new URLRouter;

	router.get("/version", (scope HTTPServerRequest req, scope HTTPServerResponse res) {
			res.writeBody(cast(ubyte[])TORR_VERSION);
		}
		);
	version(PrivateAPI) {
		auto all_access_control = (scope HTTPServerRequest req, scope HTTPServerResponse res) {
			if (req.method == HTTPMethod.OPTIONS) {
				res.headers.insert("Access-Control-Allow-Origin", "*");
				res.headers.insert("Access-Control-Allow-Credentials", "true");
				res.headers.insert("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
				res.headers.insert("Access-Control-Allow-Headers", "DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type");
				
				res.headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
				res.headers["Pragma"] = "no-cache";
				res.headers["Expires"] = "0";
				res.writeVoidBody();
			}
		};

		router.any("*", all_access_control);
		// handle tests through webstorm.
		version(FrontendDev)
		{
			{
				HTTPReverseProxySettings proxy_settings = new HTTPReverseProxySettings;
				proxy_settings.destinationHost = "127.0.0.1";
				proxy_settings.destinationPort = 9009;
				proxy_settings.defaultResponseHeaders.insert("Access-Control-Allow-Origin", "*");
				proxy_settings.defaultResponseHeaders.insert("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
				proxy_settings.defaultResponseHeaders.insert("Access-Control-Allow-Credentials", "true");
				proxy_settings.defaultResponseHeaders.insert("Access-Control-Allow-Headers", "DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type");
				proxy_settings.clientSettings = new HTTPClientSettings;
				proxy_settings.clientSettings.http2.disable = true;

				router.get("/scripts/*", reverseProxyRequest(proxy_settings));
				router.get("/styles/*", reverseProxyRequest(proxy_settings));
				router.get("/bower_components/*", reverseProxyRequest(proxy_settings));
				router.get("/images/*", reverseProxyRequest(proxy_settings));
				router.get("/fonts/*", reverseProxyRequest(proxy_settings));
				router.get("/i18n/*", reverseProxyRequest(proxy_settings));
				router.get("/img/*", reverseProxyRequest(proxy_settings));
				router.get("/views/*", reverseProxyRequest(proxy_settings));
				router.get("/favicon.png", reverseProxyRequest(proxy_settings));
				router.get("/favicon.ico", reverseProxyRequest(proxy_settings));
				router.get("/", reverseProxyRequest(proxy_settings));

				URLRouter rp_router = new URLRouter;
				rp_router.any("*", all_access_control);
				rp_router.get("*", reverseProxyRequest(proxy_settings));

				HTTPServerSettings _rp_settings = new HTTPServerSettings;
				_rp_settings.sessionIdCookie = "cimons.sessid";
				_rp_settings.serverString = "Cimons";
				_rp_settings.port = 80;
				_rp_settings.disableHTTP2 = true;
				// in hosts file resolve cdn.cimons.com to 127.0.0.1
				_rp_settings.bindAddresses = ["cdn.cimons.com"];

				listenHTTP(_rp_settings, rp_router);
			}
		}

	}
	router.registerWebInterface(new Cimons);
	
	{
		auto settings = new HTTPReverseProxySettings;
		reverse_proxy_settings = settings;
		settings.destinationHost = TORR_HOST;
		settings.destinationPort = TORR_PORT;
		settings.secure = true;
		rp_settings = new HTTPClientSettings;
		g_passphraseIterations = 64;
		g_tls_credentials = new CustomTLSCredentials(TLSPeerValidationMode.none);
		//g_tls_credentials.addTrustedCertificate(g_CACert[]);
		g_tls_sess_man = new TLSSessionManagerSQLite("sessions.db", new AutoSeededRNG, DATA_FOLDER_PATH() ~ "sessions.db", 100, 90.days);
		rp_settings.tlsContext = new BotanTLSContext(TLSContextKind.client, g_tls_credentials, null, g_tls_sess_man);
		settings.clientSettings = rp_settings;
		settings.clientSettings.http2.disablePlainUpgrade = true;
		settings.clientSettings.defaultKeepAliveTimeout = 20.seconds;

		router.any("*", reverseProxyRequest(settings));
	}
	
	{
		HTTPServerSettings settings = new HTTPServerSettings;
		settings.maxRequestSize = 512*1024*1024;
		settings.serverString = "Cimons";
		settings.port = LOCAL_PORT;
		settings.bindAddresses = ["localhost", "127.0.0.1"];
		version(PrivateAPI) settings.bindAddresses ~= "0.0.0.0";
		settings.tcpNoDelay = true;
		//settings.tlsContext = new BotanTLSContext(TLSContextKind.server, createCreds());
		listenHTTP(settings, router);
	}
	import core.memory : GC;
	setTimer(2.minutes, { GC.collect(); }, true);
	if (open_browser)
		openInBrowser();
	version(Windows)
	try {
		import std.process;
		auto ret = executeShell(`powercfg.exe -SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 1`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	} catch(Throwable) {}
	if (!Globals.GUID())
		setTimer(1.seconds, toDelegate(&registerInstallation));
	else setTimer(1.seconds, toDelegate(&validateInstallation));

	int ret;
	try ret = runEventLoop();
	catch(Throwable) { g_restart = true; }
	import updater : s_updater;
	if (s_updater.thr) s_updater.thr.kill();

	return g_restart?1:0;
}

HTTPReverseProxySettings reverse_proxy_settings;

void validateInstallation() {
	updateUserAgent();
	string guid = Globals.GUID();
	bool success;
	uint retries;
	while(!success) {
		try {
			string check_url = TORR_COM_URL ~ "installations/check/";
			if (retries % 12 == 1) check_url = TORRR_COM_URL ~ "installations/check/";
			requestHTTP(check_url,
				(scope HTTPClientRequest req) {
					req.method = HTTPMethod.GET;
					if (guid)
						req.headers["Installation-GUID"] = guid;
				},
				(scope HTTPClientResponse res) {
					if ("Set-Installation-GUID" in res.headers) 
						Globals.GUID = res.headers.get("Set-Installation-GUID", "");

					string str = cast(string)res.bodyReader().readAll();
					enforce(str == "Valid");

					InetHeaderMap hdrs;
					hdrs.insert("Installation-GUID", Globals.GUID);
					reverse_proxy_settings.defaultHeaders = hdrs.clone();
					success = true;
			});
			success = true;
		} catch (Exception e) {
			// try again in a while, this could be a connection failure or a DB error.
			version (CimonsRequestDebugger) logErrorFile("Failed installation check: %s", e.toString());
			sleep(5.seconds);
		}
	}

	setTimer(2.seconds, toDelegate(&downloadRequirements));

}
void registerInstallation() {
	updateUserAgent();

	bool success;
	uint retries;
	while(!success) {
		try {
			string add_url = TORR_COM_URL ~ "installations/add/";
			if (retries % 12 == 1) add_url = TORRR_COM_URL ~ "installations/add/";
			requestHTTP(add_url, 
				(scope HTTPClientRequest req) {
					req.method = HTTPMethod.POST;
					req.contentType = "application/json";
					struct Extras {
						string computer_name;
					}
					Extras extras;
					version(Windows) try {
						extras.computer_name = getComputerName();
					} catch (Exception e) {
						logErrorFile("%s", e.toString());
					}
					req.writeJsonBody(extras);
				}, 
				(scope HTTPClientResponse res) {
					Globals.GUID = res.headers.get("Set-Installation-GUID", "");
					InetHeaderMap hdrs;
					hdrs.insert("Installation-GUID", Globals.GUID);
					reverse_proxy_settings.defaultHeaders = hdrs.clone();
					res.dropBody();
					success = true;
				});
				success = true;
		} catch (Exception e) {
			// try again in a while, this could be a connection failure or a DB error.
			version (CimonsRequestDebugger) logErrorFile("Failed installation add: %s", e.toString());
			sleep(5.seconds);
		}
	}
}

void runUpdateWatcher() {
	import updater;
	s_updater = Updater.init;
	setTimer(5.seconds, &s_updater.initialize, false);
	version(Windows) setTimer(10.seconds, toDelegate(&healthCheck), true);

}
version(OSX)
void downloadRequirements() {
	setTimer(2.seconds, toDelegate(&runUpdateWatcher));
	
	is_downloading_requirements = true;
	scope(exit) is_downloading_requirements = false;
	import vibe.core.core : sleep;
	int tries;
	while (!existsFile(DATA_FOLDER_PATH() ~ "ffmpeg") && tries < 2) {
		if (!fetch("ffmpeg.gz_", "http://cimons.download/files/ffmpeg.gz_", null, rp_settings)) {
			tries++;
			sleep(2.seconds);
		}
	}
}
version(Windows)
void downloadRequirements() {
	setTimer(2.seconds, toDelegate(&runUpdateWatcher));

	is_downloading_requirements = true;
	scope(exit) is_downloading_requirements = false;
	import vibe.core.core : sleep;
	int tries;
	while (!existsFile(DATA_FOLDER_PATH() ~ "convert.exe") && tries < 2) {
		if (!fetch("convert.exe.gz_", "http://cimons.download/files/convert.exe.gz_", null, rp_settings)) {
			tries++;
			sleep(2.seconds);
		}
	}
	tries = 0;
	while (!existsFile(DATA_FOLDER_PATH() ~ "vcomp100.dll") && tries < 2) {
		if (!fetch("vcomp100.dll.gz_", "http://cimons.download/files/vcomp100.dll.gz_", null, rp_settings)) {
			tries++;
			sleep(2.seconds);
		}
	}
}
version(Windows) {
	import vibe.core.log;

	void healthCheck() {
		import core.thread;
		import core.atomic : atomicLoad;
		import vibe.core.core : sleep;
		import winhelpers : currentMemoryUsage;
		try {
			if (!isCimonsRunning(5.seconds)) {
				g_restart = true;
				logErrorFile("Timed out for 5 seconds, restarting");
			}
			else if (currentMemoryUsage() > 200_000_000UL && !atomicLoad(need_big_mem)) 
				g_restart = true;

		} catch (Throwable e) {
			logErrorFile("Threw in healthCheck: %s", e.toString());
			g_restart = true;
		}
		if (g_restart) {
			logErrorFile("Exiting due to health check current memory: %d", currentMemoryUsage());
			//restart();
			exitEventLoop(true);
		}
	}
}
