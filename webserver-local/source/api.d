module api;

import std.process;
import std.file : getcwd;
import std.algorithm : joiner, startsWith, min, canFind, splitter, countUntil;
import std.array : array, Appender;
import std.uuid : randomUUID;
import std.random : uniform;
import std.exception : enforce;
  
import vibe.core.core : runTask;
import vibe.core.log;
import vibe.core.driver;
import vibe.core.concurrency;
import vibe.core.file;
import vibe.http.client;
import vibe.http.server;
import vibe.stream.operations;
import vibe.web.web;
import vibe.http.cookiejar;
import vibe.core.core;
import vibe.data.json;
import vibe.core.core : sleep;
import std.datetime;
import std.string : strip, toLower, indexOf, replace, lastIndexOf, indexOf;
import std.conv : to;
import botan.constructs.cryptobox;
import botan.rng.auto_rng;
import std.typecons : scoped;
import memutils.hashmap;
import memutils.unique;
import core.cpuid : threadsPerCPU;

import config;
import helpers;

HTTPClientSettings rp_settings;
bool is_downloading_requirements;
void delegate() updater_del;
void delegate(Duration) updater_rearm_del;

class Cimons 
{
	version(PrivateAPI) {

		@path("/test_server_connect")
		void getServerConnect(scope HTTPServerRequest req, scope HTTPServerResponse res)
		{
			import updater;
			string ret_data;
			import vibe.http.client;
			requestHTTP(TORR_COM_URL ~ "poll/", 
				(scope HTTPClientRequest creq) {
					creq.writeInstallationGUID();
				}, 
				(scope HTTPClientResponse cres) {
					//version(CimonsRequestDebugger) logErrorFile("Download response");
					ret_data = cast(string)cres.bodyReader.readAll(size_t.max, 1024, 1.minutes);
				}, s_updater.settings);
			res.writeBody(ret_data, "application/json");
		}
	}

	@path("/ping")
	void getPing(scope HTTPServerRequest req, scope HTTPServerResponse res)
	{
		res.writeVoidBody();
	}

	@path("/restart")
	void getRestart(scope HTTPServerRequest req, scope HTTPServerResponse res) 
	{
		g_restart = true;
		setTimer(100.msecs, { exitEventLoop(true); });
		res.writeBody(`{"status":"ok"}`);
	}

    @path("/reboot")
    void getReboot(scope HTTPServerRequest req, scope HTTPServerResponse res) {
        import winscripts;
        res.writeVoidBody();
        setTimer(100.msecs, { restart(); });
        
    }

	@path("/api/configuration")
	void getConfiguration(scope HTTPServerRequest req, scope HTTPServerResponse res)
	{
		mixin(Trace);
		res.setDefaultHeaders();
		Json ret = Json.emptyObject;
		ret["cimons_version"] = TORR_VERSION;
		ret["cimons_arch"] = TORR_ARCH_BITS;

		Globals.locale = req.headers.get("Accept-Language", "en-US");

		res.writeBody(ret.toString());
	}

}

static SysTime last_user_activity;
private void setDefaultHeaders(scope HTTPServerResponse res) {
	last_user_activity = Clock.currTime(UTC());
	version(PrivateAPI) {
		res.headers.addField("Access-Control-Allow-Origin", "*");
		res.headers.addField("Access-Control-Allow-Credentials", "true");
		res.headers.addField("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
		res.headers.addField("Access-Control-Allow-Headers", "DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type");
	} else {		
		res.headers.addField("Access-Control-Allow-Origin", "cimons.com");
	}
	res.headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
	res.headers["Pragma"] = "no-cache";
	res.headers["Expires"] = "0";
}

public: // will be used in updater

void forwardCookies(scope HTTPClientRequest creq, scope HTTPServerRequest req)
{
	if ("Cookie" !in req.headers) return;
	creq.headers["Cookie"] = req.headers["Cookie"];
}

void forwardSetCookies(scope HTTPClientResponse cres, scope HTTPServerResponse res)
{
	import vibe.utils.string : icmp2;
	if ("Set-Cookie" !in cres.headers) return;
	import std.array : replace;
	cres.headers.getAll("set-cookie", (const string value) { res.headers.addField("Set-Cookie", (cast()value).replace("Secure; ", "")); });
}


HTTPClientSettings getClientSettings() {
	static HTTPClientSettings csettings;
	if (!csettings) {
		csettings = new HTTPClientSettings;
		auto f = openFile(DATA_FOLDER_PATH() ~ "web.ini", FileMode.createTrunc);
		f.close();
		csettings.cookieJar = new FileCookieJar(DATA_FOLDER_PATH() ~ "web.ini");
		csettings.http2.disable = true;
	}
	return csettings;
}
