module helpers;
import config;
import vibe.inet.path : Path;
import vibe.inet.urltransfer : download;
import vibe.http.client;
import vibe.stream.bufcomp : sha256Of;
import vibe.stream.operations;
version(Windows) import vibe.daemonize.windows;
import botan.algo_base.buf_comp;
import memutils.unique;
import memutils.vector;
import vibe.core.file;
import vibe.data.json;
import std.datetime;
import events;
import botan.tls.session_manager_sqlite;
import vibe.stream.botan;
import std.conv : to;
import std.exception : enforce;

RemoteLogger remoteLogger; // cimons server
CustomTLSCredentials g_tls_credentials; // required to connect with cimons server
TLSSessionManagerSQLite g_tls_sess_man; // keep sessions open with cimons server

// todo: Save some disk space by gzip'ing the logs or deleting them based on a global policy...
void rotateLogs() {
	// todo
}

void removeDirectory(string dir_path) {
	import std.process : executeShell, Config;
	version(Windows) 
		executeShell("C:\\WINDOWS\\system32\\cmd.exe /C RMDIR /Q /S " ~ dir_path, null, Config.suppressConsole);
	version(OSX) 
		executeShell("rm -fR " ~ dir_path, null, Config.suppressConsole);
}

string otherSHA256(string filename, HTTPClientSettings settings = null)
{
	string sha256;
	int tries;
	while (!sha256 && tries < 3) {
		bool success;
		try {
			requestHTTP(TORR_COM_URL ~ "sha256/" ~ filename, (scope req) { },
			(scope res) { 
				if (res.statusCode == HTTPStatus.ok) {
					success = true;
					sha256 = cast(string)res.bodyReader.readAll();
				}
				else {
					res.dropBody(); 
					return; 
				}
			});
		}
		catch (Exception e) { 
			remoteLogger.logError("Failure in otherSHA256(): %s", e.msg);
			success = false; 
		}
		if (!sha256 || !success) { import vibe.core.core : sleep; sleep(2.seconds); tries ++; }
	}
	return sha256;
}

/// Places the given file from Cimons.com/download/:installation_guid/:filename/ into the data folder
bool fetch(string filename, string url = null, string sha256 = null, HTTPClientSettings settings = null)
{	
	bool success;
	try {
		if (!url)
			url = TORR_COM_URL ~ "download/" ~ Globals.GUID ~ "/" ~ filename;

		Path local_temp = Path(DATA_FOLDER_PATH() ~ filename ~ ".1");
		if (existsFile(local_temp))
			removeFile(local_temp);
		string local_path_str = DATA_FOLDER_PATH() ~ filename;
		Path local_path = Path(local_path_str);
		ulong connection_speed;
		ulong readings;

		// receives speed readings for every 64kb downloaded
		void update_connection_speed(ulong kbps) {
			connection_speed += kbps;
			readings++;
		}

		// todo: use requestHTTP here too
		download(URL.parse(url), local_temp, &update_connection_speed);

		if (!sha256) {
			requestHTTP(url ~ ".sha256", (scope HTTPClientRequest req) { req.headers.remove("Accept-Encoding"); }, (scope HTTPClientResponse res) { 
					if (res.statusCode == HTTPStatus.OK)
						sha256 = cast(string) res.bodyReader.readAll(); 
					else res.dropBody();
				}, settings);
		}
		// Validate the two files
		enforce(sha256.length == 0 || sha256 == sha256Of(local_temp.toNativeString()), "SHA256 didn't match the downloaded file");

		try if (existsFile(local_path)) removeFile(local_path); catch(Throwable) {}
		// move file
		moveFile(local_temp, local_path);

		// extract
		import std.algorithm : endsWith;
		if (filename.endsWith(".gz_")) {
			string unzipped_path = local_path_str[0 .. $-4];
			try if (existsFile(unzipped_path)) removeFile(unzipped_path); catch(Throwable) {}
			gunzip(local_path, Path(unzipped_path));

			removeFile(local_path);

			version(OSX) {
				import std.process;
				executeShell("chmod +x " ~ unzipped_path, string[string].init, Config.suppressConsole);
			}

			local_path = Path(unzipped_path);
		}
		// Adjust connection speed records
		if (auto g_conn_speed = Globals.connectionSpeed) 
			Globals.connectionSpeed = (g_conn_speed+(connection_speed/readings))/2;
		else Globals.connectionSpeed = (connection_speed/readings);


		updateUserAgent(); // new connection speed

		success = true;
		remoteLogger.logInfo("Successfully Downloaded %s", filename);
	}
	catch (Throwable e) {
		success = false;
		logErrorFile("Error: %s", e.toString());
		remoteLogger.logError("Failure in fetch(): %s", e.msg);
	}
	return success;
	
}
version(CimonsRequestDebugger) {
	import vibe.core.log;
	alias logErrorFile = cimons.core.log.logError;
} else {
	void logErrorFile(ARGS...)(string format, lazy ARGS args) {}
}

version(OSX) {
	extern(C) int sysctlbyname(const char*, void*, size_t*, void*, size_t);
	string OSVersion() {
		import std.string : fromStringz, toStringz;
		char[256] str;
		size_t size = str.sizeof;
		int ret = sysctlbyname(cast(const char *)"kern.osrelease".toStringz, str.ptr, &size, null, 0);
		return cast(string) str.ptr.fromStringz.idup;
	}

	ulong availableRAM() {
		import std.string : fromStringz, toStringz;
		ulong mem_size;
		size_t mem_size_size = ulong.sizeof;
		int ret = sysctlbyname(cast(const char *)"hw.memsize".toStringz, &mem_size, &mem_size_size, null, 0);
		logErrorFile("Got available RAM: %d", mem_size);
		return mem_size;
	}
}

void updateUserAgent() {
	import core.stdc.stdlib : getenv;

	version(Windows) import winhelpers : OSVersion, availableRAM;
	try HTTPClient.setUserAgentString("Cimons" ~ TORR_ARCH_BITS ~ "/" ~ TORR_VERSION ~ " (" ~ OS_NAME ~ " " ~ OSVersion() ~ " " ~ OS_ARCH() ~ "; " ~ (availableRAM()/1000).to!string ~ " MB; " ~ Globals.connectionSpeed.to!string ~ "kbps)");
	catch (Exception e) {
		HTTPClient.setUserAgentString("Cimons" ~ TORR_ARCH_BITS ~ "/" ~ TORR_VERSION ~ " (" ~ OS_NAME ~ " " ~ OSVersion() ~ " " ~ OS_ARCH() ~ "; 0 MB; 0kbps)");
		logErrorFile("Could not update user-agent: %s", e.toString());
	}

}

void writeInstallationGUID(scope HTTPClientRequest req) {
	auto guid = Globals.GUID();
	if (guid)
		req.headers["Installation-GUID"] = guid;
}

struct RemoteLogger {
	Severity minLevel;
	HTTPClientSettings settings;
	enum SeverityName : string {
		trace = "trace",
		info = "info",
		debug_ = "debug",
		error = "error"
	}
	/// Will post data and discards failure events
	private void POST(string severity, Json json_data) {
		try requestHTTP(TORR_COM_URL ~ "events/add/" ~ severity, (scope HTTPClientRequest req) { 
				req.method = HTTPMethod.POST;
				req.writeInstallationGUID();
				req.writeJsonBody(json_data);
			},
			(scope res) { res.dropBody(); }, settings);
		catch (Exception e) {
			logErrorFile("Failure in RemoteLogger.POST: %s", e.toString());
		}
	}

	private void sendLog(ARGS...)(string severity, string func, string file, int line, string fmt, ARGS args)
	{
		import std.string : format;
		struct Error {
			SysTime when;
			string func;
			string file;
			int line;
			string message;
			Json args;
		}
		Error err_data;
		err_data.when = Clock.currTime(UTC());
		err_data.func = func;
		err_data.file = file;
		err_data.line = line;
		err_data.message = fmt;
		err_data.args = Json.emptyArray;
		foreach (arg; args)
			err_data.args ~= arg;

		POST(severity, err_data.serializeToJson());
	}

	void logTrace(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__, S, ARGS...)(S fmt, lazy ARGS args) {
		if (minLevel > Severity.trace) return;
		sendLog(SeverityName.trace, func, file, line, fmt, args);
	}
	void logInfo(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__, S, ARGS...)(S fmt, lazy ARGS args) {
		if (minLevel > Severity.info) return;
		sendLog(SeverityName.info, func, file, line, fmt, args);
	}
	void logDebug(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__, S, ARGS...)(S fmt, lazy ARGS args) {
		if (minLevel > Severity.debug_) return;
		sendLog(SeverityName.debug_, func, file, line, fmt, args);
	}
	void logError(string func = __FUNCTION__, string file = __FILE__, int line = __LINE__, S, ARGS...)(S fmt, lazy ARGS args) {
		if (minLevel > Severity.error) return;
		sendLog(SeverityName.error, func, file, line, fmt, args);
	}
}

private:

void gunzip(Path from_file, Path to_file)
{
	import vibe.stream.zlib;
	import vibe.core.file;
	FileStream fstream = openFile(from_file);
	scope(failure) fstream.close();
	GzipInputStream gz_istream = new GzipInputStream(fstream);
	if (existsFile(to_file))
		removeFile(to_file);
	FileStream fout = openFile(to_file, FileMode.createTrunc);
	scope(failure) fout.close();
	fout.write(gz_istream);
	fout.finalize();
	fout.close();
	fstream.close();
}
