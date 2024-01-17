module config;
import helpers;
import vibe.db.sqlite.sqlite3;
import std.conv : to;
import std.datetime;
import std.algorithm : endsWith;

shared(bool) need_big_mem;
bool g_restart;
bool is_update;
version(Windows) enum DS = "\\";
else enum DS = "/";
version(Windows) {
const TORR_EXE_FOLDER_PATH = "C:\\Program Files\\Cimons";
const TORR_EXE_PATH = "C:\\Program Files\\Cimons\\Cimons.exe";
} else version (OSX) {
	extern(C) int _NSGetExecutablePath(char* buf, uint* bufsize);

	@property string TORR_EXE_FOLDER_PATH() {
		static string fol_path;
		if (!fol_path)
		{
			char[256] buf;
			uint len = buf.length;
			_NSGetExecutablePath(buf.ptr, &len);
			import std.string : fromStringz;
			fol_path = cast(string) buf.ptr.fromStringz();
			fol_path = fol_path[0 .. $-"Cimons".length].idup;

		}
		return fol_path;	
	}
	@property string TORR_EXE_PATH() {
		static string exe_path;
		if (!exe_path)
			exe_path = TORR_EXE_FOLDER_PATH ~ "Cimons";
		return exe_path;
	}
}
const TORR_HOST = "cimons.com";
const TORR_PORT = 443;
const CIMONS_COM_URL = "https://"~TORR_HOST~":"~TORR_PORT.to!string~"/";
const CIMONS_COM_URL_SECONDARY = "https://cimons.com:"~TORR_PORT.to!string~"/";
const LOCAL_HOST = "localhost";
const LOCAL_PORT = 3343;
const LOCAL_URL = "http://" ~ LOCAL_HOST ~ ":" ~ LOCAL_PORT.to!string ~ "/";
const TORR_VERSION = "0.0.1";
version(X86_64)
	const TORR_ARCH_BITS = "64";
else version(X86)
	const TORR_ARCH_BITS = "32";
else
	const TORR_ARCH_BITS = "32";

const APP_WIDTH = 1010;
const APP_HEIGHT = 689;

version(Windows) {
	const OS_NAME = "Windows NT";
	@property string OS_ARCH() { import core.stdc.stdlib : getenv; return getenv("PROCESSOR_ARCHITECTURE").to!string.dup; }
}
version(OSX) {
	const OS_NAME = "Mac OS X";
	@property string OS_ARCH() { return "AMD64"; }
}
version(Linux)
	const OS_NAME = "Linux";

enum : bool {
	WRITE = false,
	READ
}

/// Opens the SQLite database from the data folder. The user must call .close() when finished!
Database openDB(bool read = true) {
	// DB is always created in static ctor
	return Database(DATA_FOLDER_PATH() ~ "Cimons.db", read ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE));
}

/// Mutable configuration settings
struct Globals {
@property static:

	private T get(T)(string name, lazy T default_value = T.init) {
		Database sqlite = openDB(READ);
		T ret;
		try {
			auto results_count = sqlite.prepare("SELECT count(*) FROM config WHERE name=? collate nocase").bind(1, name).execute();
			auto val_ = results_count.oneValue!int;
			if (val_ > 0) {
				auto results = sqlite.prepare("SELECT value FROM config WHERE name=? collate nocase").bind(1, name).execute();
				auto val = results.oneValue!string;
				static if (!is(T == string))
					ret = val.to!T;
				else ret = val;
			}
			else ret = default_value;
		}
		catch (Exception e) {
			ret = default_value;
		}
		return ret;
	}

	private void set(T)(string name, T value) {
		Database sqlite = openDB(WRITE);
		bool exists;
		try {
			auto results_count = sqlite.prepare("SELECT count(*) FROM config WHERE name=? collate nocase").bind(1, name).execute();
			auto val_ = results_count.oneValue!int;
			if (val_ > 0) {
				// Update the existing value.
				exists = true;
				auto res = sqlite.prepare("UPDATE config SET value=? WHERE name=? collate nocase").bind(1, value.to!string).bind(2, name).execute();
			}
		}
		catch { exists = false; }
		
		if (!exists) {
			auto res = sqlite.prepare("INSERT INTO config (name, value) VALUES (?, ?)").bind(1, name).bind(2, value.to!string).execute();
		}
	}

	struct Updates {
	@property static:
		bool stayConnected() {
			return get!bool("stay_connected", false);
		}

		void stayConnected(bool val) {
			set("stay_connected", val);
		}
		
		Duration checkInterval() {
			return get!ulong("check_interval", 60*60*8).dur!"seconds";
		}
		
		void checkInterval(Duration val) {
			set("check_interval", val.total!"seconds");
		}
		
		Duration microTimer() {
			return get!ulong("dev_check_interval", 60*60).dur!"seconds";
		}
		
		void microTimer(Duration val) {
			set("dev_check_interval", val.total!"seconds");
		}
		
		Duration keepAliveDuration() {
			return get!ulong("keepalive_duration", 10).dur!"seconds";
		}
		
		void keepAliveDuration(Duration val) {
			set("keepalive_duration", val.total!"seconds");
		}
		
		bool disableHTTP2() {
			return get!bool("disable_http2", false);
		}
		
		void disableHTTP2(bool val) {
			set("disable_http2", val);
		}
		
	}
	@property static:


	SysTime nextWakeEvent()
	{
		return SysTime(get!long("next_wake", 0), UTC());
	}
	
	void nextWakeEvent(SysTime next) {
		if (next != SysTime.init)
			set("next_wake", next.stdTime);
	}

	string GUID() 
	{
		return get!string("installation_guid", null);
	}
	
	void GUID(string guid)
	{
		if (guid && guid != "")
			set("installation_guid", guid);
	}

	string locale() 
	{
		return get!string("locale", "en-US");
	}
	
	void locale(string locale)
	{
		if (locale && locale != "")
			set("locale", locale);
	}

	ulong connectionSpeed() {
		ulong connection_speed = get!ulong("connection_speed", 0);
		return connection_speed;
	}

	// todo: Move average maths in the SQL statement?
	void connectionSpeed(ulong val) {
		set("connection_speed", val);
	}
	
	int logLevel() {
		return get!int("log_level", 1);
	}
	
	void logLevel(int log_level) {
		set("log_level", log_level);
	}


}

string getStartMenuFolder() {
	import standardpaths;
	static string program_files;
	if (!program_files) {
		string[] paths = standardPaths(StandardPath.applications);
		string path;
		foreach (path_; paths) {
			if (path_)
				path = path_;
		}
		program_files = path ~ DS;
	}
	return program_files;
}

/// Retrieve data folder with trailing slash
@property string DATA_FOLDER_PATH() {
	import standardpaths;
	import std.file : exists, mkdirRecurse;
	static string data_folder;
	bool first_check;
	if (!data_folder) {
		first_check = true;
		version(OSX) {
			data_folder = TORR_EXE_FOLDER_PATH ~ "Data/";
		}
		else version(Windows) {
			string[] paths = standardPaths(StandardPath.data);
			string path;
			foreach (path_; paths) {
				if (path_)
					path = path_;
			}
			data_folder = path ~ DS ~ "Cimons" ~ DS;
		}
	}
	if (!exists(data_folder)) {
		bool read_only;
		try mkdirRecurse(cast(char[])data_folder);
		catch(Throwable) { read_only=true; }
		version(OSX) {
			if (read_only) {
				data_folder = "/tmp/cimons/";
				mkdirRecurse(cast(char[])data_folder);
			}
			import std.process;
			try executeShell("chmod +w " ~ data_folder, string[string].init, Config.suppressConsole); catch {}
		}
	} else if (first_check) {
		version(OSX) {
			import std.process;
			try executeShell("chmod +w " ~ data_folder, string[string].init, Config.suppressConsole); catch {}
		}
	}
	return data_folder;
}

shared static this() {
	import core.thread;
	// initialize DB
	try {
		Database sqlite = openDB(WRITE);
		sqlite.execute(`
			CREATE TABLE IF NOT EXISTS config (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				name TEXT NOT NULL,
				value TEXT NOT NULL
			);
	`);
		sqlite.execute(`CREATE INDEX IF NOT EXISTS config_name_idx ON config (name collate nocase); `);
		sqlite.execute(`VACUUM;`);
	}
	catch (Exception e) {
		version(CimonsNoDebug){} else {
			import vibe.core.file;
			auto f = openFile("C:\\ProgramData\\Cimons\\crash.log", FileMode.createTrunc);
			f.write(cast(ubyte[])e.toString());
		}
	}
}
