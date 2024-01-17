import std.stdio;
import std.getopt;
import std.concurrency;

import vibe.d;
import vibe.core.core;
import vibe.http.proxy;
import vibe.stream.botan;
import vibe.db.redis.sessionstore;
import vibe.web.web;

import botan.cert.x509.x509cert;
import botan.pubkey.pkcs8;
import botan.rng.auto_rng;
import botan.tls.session_manager;

//import botan.tls.session_manager_sqlite : TLSSessionManagerSQLite;
import botan.tls.policy;

import std.algorithm : endsWith;
import std.file : getSize;
import core.memory : GC;

import api;

import botan.tls.policy;
import helpers;

void main()
{
	Unique!AutoSeededRNG rng = new AutoSeededRNG;
	import vibe.http.debugger;

	setLogFile("log.txt", LogLevel.error);
	//setLogLevel(LogLevel.trace);
	URLRouter router = new URLRouter;

	version (VibeNoDebug)
	{
	}
	else
		router.setupDebugger();
	router.get("/minimize", (req, res) { GC.minimize(); res.writeVoidBody(); });

	router.get("/collect", (req, res) { GC.collect(); res.writeVoidBody(); });
	router.get("/updates/*", serveStaticFiles("./"));
	router.get("/", serveStaticFile("./public/index.html"));
	router.post("/", serveStaticFile("./public/index.html"));
	WebInterfaceSettings isettings = new WebInterfaceSettings;
	router.registerWebInterface(new InstallationAPI, isettings);

	WebInterfaceSettings usettings = new WebInterfaceSettings;
	usettings.urlPrefix = "/api/";
	router.registerWebInterface(new UserAPI, usettings);

	HTTPReverseProxySettings proxy_settings = new HTTPReverseProxySettings;
	proxy_settings.destinationHost = "192.99.66.147";
	proxy_settings.destinationPort = 9009;
	proxy_settings.clientSettings = new HTTPClientSettings;
	proxy_settings.clientSettings.http2.disable = true;
	// for the rest

	HTTPFileServerSettings fsettings = new HTTPFileServerSettings;
	fsettings.serverPathPrefix = "/files/";
	router.get("/files/*", serveStaticFiles("./files/", fsettings));

	//router.get("*", reverseProxyRequest(proxy_settings));

	mailer = new SMTPClientSettings("localhost", 25);
	mailer.authType = SMTPAuthType.none;
	//mailer.username = "a@b.c";
	//	mailer.password = "asdf";

	HTTPServerSettings settings = new HTTPServerSettings;
	settings.sessionIdCookie = "cimons.sessid";
	settings.serverString = "Cimons";
	settings.port = 4344;
	settings.disableHTTP2 = false;
	settings.sessionStore = new RedisSessionStore("localhost", 0);
	(cast(RedisSessionStore) settings.sessionStore).expirationTime = 7.days;
	settings.bindAddresses = ["localhost", "cimons.com"];
	//settings.options ^= HTTPServerOption.errorStackTraces;
	auto cert = X509Certificate("cert.crt");
	//auto cacert = X509Certificate("ca.crt");
	auto pkey = loadKey("private.pem", *rng, "pwrd128");
	auto creds = new CustomTLSCredentials(cert, X509Certificate.init, pkey);
	auto policy = new LightTLSPolicy;
	auto tls_sess_man = new TLSSessionManagerInMemory(*rng); // new TLSSessionManagerSQLite("some_password", *rng, "tls_sessions.db", 150000, 2.days);

	BotanTLSContext tls_ctx = new BotanTLSContext(TLSContextKind.server, creds, null, tls_sess_man);
	settings.tlsContext = tls_ctx;
	/*tls_ctx.setBeforeHandshake( (scope TLSStream tls_stream) {
                        if (BotanTLSStream botan_stream = cast(BotanTLSStream) tls_stream) {
                                RedisDatabase cache = connectCache();
                                //enforce(!cache.sisMember("tls_blacklist", botan_stream.serverInfo.hostname()));
                        }
                });

        tls_ctx.setAfterHandshake( (scope TLSStream tls_stream) {
                        if (BotanTLSStream botan_stream = cast(BotanTLSStream) tls_stream) {
                                RedisDatabase cache = connectCache();
                                if (cache.sadd("tls_sessions", botan_stream.sessionId()) == 0)
                                        cache.zincrby("tls_handshakes", 1.0, botan_stream.serverInfo.hostname());
                        }
                });
		*/

	settings.disableHTTP2 = false;
	settings.useCompressionIfPossible = true;
	listenHTTP(settings, router);

	URLRouter admin_router = new URLRouter;
	WebInterfaceSettings asettings = new WebInterfaceSettings;
	asettings.urlPrefix = "/api/v1/";
	admin_router.any("*", (scope req, scope res) {
		if (req.method == HTTPMethod.OPTIONS)
		{
			res.headers.insert("Access-Control-Allow-Origin", "*");
			res.headers.insert("Access-Control-Allow-Credentials", "true");
			res.headers.insert("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
			res.headers.insert("Access-Control-Allow-Headers", "DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type");

			res.writeVoidBody();
		}
	});
	// listen to file requests on port 80
	//router = new URLRouter;

	/*
	HTTPServerSettings settings = new HTTPServerSettings;
	settings.bindAddresses = ["127.0.0.1", "localhost", "72.46.153.34"];
	fsettings = new HTTPFileServerSettings;
	fsettings.defaultHeaders["Access-Control-Allow-Origin"] = "*";
	router.get("*", serveStaticFiles("./public/", fsettings));
	settings.bindAddresses = ["127.0.0.1", "localhost"];
	listenHTTP(settings, router);
*/
	runTask({ setTimer(10.seconds, { GC.collect(); }, true); });
	runEventLoop();
}
