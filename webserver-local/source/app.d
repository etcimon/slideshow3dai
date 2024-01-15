import core.runtime;
import std.string;

import vibe.core.core;
import vibe.core.log : setLogLevel, setLogFile, CimonsLogLevel = LogLevel;
import vibe.http.client;
import vibe.http.server;
import vibe.http.proxy;
import vibe.http.router;
import vibe.web.web : registerWebInterface;
import vibe.stream.botan;
import core.stdc.stdlib : exit;
import std.stdio : stdin, stdout, stderr;
import std.datetime;
import std.exception;

import config;
import api;
import service;
import winscripts;
import std.process;

bool must_restart;
string installed_version;
import vibe.core.log;
/// Try to connect on port 3343
bool isCimonsRunning(Duration timeout = 1.seconds) {
	bool running;
	logTrace("Checking if cimons is running");
	Duration dur = Duration.zero;
	SysTime start = Clock.currTime(UTC());
	bool is_first = true;
	while(!running && Clock.currTime(UTC()) - start < timeout)
	{
		if (is_first) is_first = false;
		else sleep(333.msecs);
		
		import vibe.stream.operations;
		import vibe.data.json;
		try {
			requestHTTP("http://localhost:3343/api/configuration", (scope req) {
					req.headers["Connection"] = "close";
				}, (scope res) {
					auto data = cast(string)res.bodyReader.readAll();
					auto config = data.parseJsonString();

					if (config.type == Json.Type.object)
						installed_version = config["cimons_version"].get!string;
					else installed_version = "0.0.0";

					running = true;
				});
		}
		catch (TimeoutException e) {
			must_restart = true;
			running = false;
		}
		catch (ConnectionClosedException e) {
			running = false;
		}
		catch (Exception e) {
			running = false;
		}
		
	}
	return running;
}

version(OSX) {
	void installService(string cimons_path) {
		string data_folder_path = DATA_FOLDER_PATH();
		string updater_path;
		if (is_update) {
			updater_path = TORR_EXE_PATH;
			cimons_path = "/Applications/Cimons.app/Contents/Resources/Cimons";
			enforce(existsFile(cimons_path), "Cannot find Cimons in your Applications. Update failed: Please install.");
			data_folder_path = "/Applications/Cimons.app/Contents/Resources/Data/";
		}

		string plist_str = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cimons.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>` ~ cimons_path ~ `</string>
        <string>--listen</string>
    </array>
	
    <key>KeepAlive</key>
    <dict>
         <key>SuccessfulExit</key>
         <false/>
    </dict>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>`;
		if (existsFile(data_folder_path ~ "version.txt"))
			try removeFile(data_folder_path ~ "version.txt"); catch (Exception e) {}
		try writeFile(data_folder_path ~ "version.txt", cast(ubyte[])TORR_VERSION);catch (Exception e) {}
		if (existsFile("/Library/LaunchDaemons/cimons.plist")) {
			try executeShell("launchctl stop /Library/LaunchDaemons/cimons.plist"); catch (Exception e) {}
			try executeShell("launchctl unload /Library/LaunchDaemons/cimons.plist"); catch (Exception e) {}
			if (!is_update) 
				try removeFile("/Library/LaunchDaemons/cimons.plist"); catch (Exception e) {}
			else {
				try removeFile(cimons_path); catch (Exception e) {}
				try copyFile(updater_path, cimons_path); catch (Exception e) {}
				import std.process;
				executeShell("chmod +x " ~ cimons_path, string[string].init, Config.suppressConsole);
			}
		}
		if (!is_update)
			try writeFile("/Library/LaunchDaemons/cimons.plist", cast(ubyte[])plist_str); catch (Exception e) {}
		startService();
	}
	
	void elevate(char[] args) {
		logTrace("Elevating");
		string filepath = TORR_EXE_PATH;
		string folpath = TORR_EXE_FOLDER_PATH;
		string flags = "--elevated";
		if (is_update) {			
			folpath = "/Applications/Cimons.app/Contents/Resources/";
			flags = "--update_elevated";
			enforce(existsFile(folpath ~ "cocoasudo"),"Cannot find Cimons.app in your Applications. Update failed: Please install.");
		}
		executeShell(folpath ~ `cocoasudo --prompt="Cimons.app requires that you type your password" ` ~  filepath ~ ` ` ~ flags);

	}

	bool is_elevated;
	bool isElevated() {
		return is_elevated;
	}

	int main(string[] args) {

		if (args[1] == "--listen") {
			version(OSX) {
				import core.sys.posix.unistd : setuid;
				setuid(0);
			}
			setLogLevel(LogLevel.none);
			runCimons(false);
		} 
		else 
		{
			if (args[1] == "--update")
				is_update = true;
			if (args[1] == "--update_elevated")
			{
				is_update=true;
				is_elevated = true;
			}
			if (args[1] == "--elevated")
				is_elevated = true;
			dmain(cast(char[])args[1]);
		}
		return g_restart?1:0;
	}

	void updateVersion() {
		string folpath = DATA_FOLDER_PATH();
		if (is_update)		
			folpath = "/Applications/Cimons.app/Contents/Resources/Data/";
		if (existsFile(folpath ~ "version.txt"))
			removeFile(folpath ~ "version.txt");
		writeFile(folpath ~ "version.txt", cast(ubyte[])TORR_VERSION);
	}
}

version(Windows) {
	import vibe.daemonize.windows;
	import winhelpers;
	import winscripts;
	import winregistry;
	
	// show a page from cimons.com with information on accepting the administrator priviledges
	void errorInBrowser() {
		
	}
	
	void startService() {
		buildDaemon!daemon.run();
	}
	
	void copyFile(string user_roaming) {
		enforce(isElevated, "You need to run as administrator to install");
		// Program files directory
		import std.file : thisExePath, exists, copy, mkdirRecurse;
		if (!exists(TORR_EXE_PATH)) {
			try mkdirRecurse(cast(char[]) TORR_EXE_FOLDER_PATH ); catch(Throwable) {}
			try copy(cast(char[])thisExePath(), TORR_EXE_PATH); catch(Throwable) {}
		}
		
		// registry entries for uninstallation
		try createUninstaller(); catch(Throwable) {}
		
		// Start menu entry
		createShortcut(TORR_EXE_PATH, getStartMenuFolder() ~ "Cimons.lnk", "Track Your Online Presence!");
		
		// taskbar icon
		//pin();
	}
	
	void stopService() {
		HTTPClientSettings settings = new HTTPClientSettings;
		settings.http2.disable = true;
		requestHTTP(LOCAL_URL ~ "stop", (scope HTTPClientRequest req) { }, (scope HTTPClientResponse res) { }, settings);
	}
	
	void removeService() {
		try buildDaemon!daemon.uninstall(); catch(Throwable) {}
		// delete all files in the data folder
		import std.file : thisExePath, rmdirRecurse;
		import std.algorithm : countUntil;
		auto data_dir = DATA_FOLDER_PATH();
		enforce(data_dir.countUntil("Cimons") != -1, "Wrong data directory: " ~ data_dir);
		
		// remove the service
		try removeUninstaller(); catch(Throwable) {}
		// Start menu entry
		try removeFile(getStartMenuFolder() ~ "Cimons.lnk"); catch(Throwable) {}
		
		// self delete
		import std.process : spawnShell, executeShell, Config;
		import std.stdio;
		spawnShell("C:\\WINDOWS\\system32\\cmd.exe /C choice /C Y /N /D Y /T 2 & net stop cimonsclient & taskkill /f /im Cimons.exe & timeout 1 & RMDIR /Q /S \"" ~ TORR_EXE_FOLDER_PATH ~ "\" & RMDIR /Q /S \"" ~ DATA_FOLDER_PATH ~ "\" & mshta vbscript:Execute(\"MsgBox(\"\"Uninstallation complete.\"\", 64, \"\"Complete\"\")(window.close)\")", null, Config.suppressConsole);
		
	}
	
	void installService(string cimons_exe_path) {
		buildDaemon!daemon.install(cimons_exe_path);
		startService();
	}
	
	void elevate(char[] args) {
		Elevation ret = elevateProcess(null, args);
		// very unlikely...
		if (ret.status == ALREADY_ELEVATED) {
			startService();
		}
		else enforce(ret.status == ELEVATE_SUCCESS);
	}
}

void dmain(char[] args) {
	
	import std.stdio : File, writeln;
	import std.file : exists;
	import vibe.core.log;
	//setLogLevel(CimonsLogLevel.trace);
	bool success;

	version(CimonsNoDebug){}
	else {
		import vibe.core.log;
		//setLogFile(DATA_FOLDER_PATH() ~ "runtime.log", CimonsLogLevel.error);
	}
	// no stdout/stderr output
	version(Windows){} else setLogLevel(CimonsLogLevel.none);

	bool is_uninstall = (args !is null && args == "--uninstall");
	bool running;
	try running = isCimonsRunning(1.seconds); catch(Throwable) { }
	// We can't ask the user to elevate, so we run the server in this Window
	//enforce(isElevated || canElevate || running, "Windows Rights Elevation Failure. Cimons requires a Windows Administrator Account to be installed. Please contact your system administrator or send us a message to request development for a Local User version.");
	HTTPClientSettings csettings = new HTTPClientSettings;
	csettings.userAgent = "Cimons";
	csettings.http2.disable = true;
	/// We install or start cimons and open the browser
	if (!isElevated()) {
		bool failed;
		
		if (running && !is_uninstall) {
			import semver : compareVersions;
			if (compareVersions(TORR_VERSION, installed_version) <= 0) {
				openInBrowser();
				return;
			}
			running = false;
		}
		// Install if it's not installed or older, and open the app in the browser once it succeeds
		try if (!running || is_uninstall) {
			if (!is_uninstall) {
				version(Windows) {
					import standardpaths : roamingPath;
					if (!must_restart) args = cast(char[])roamingPath();
					else args = cast(char[])"-restart";
				}
			}
			
			elevate(args);
		}
		catch (Exception e) {
			failed = true;
		}
		// open browser
		if (!failed && !is_uninstall) {
			int sleep;
			while(!running) {
				import core.thread : Thread;
				sleep += 500;
				if (sleep >= 8000) return; //, "Could not complete installation process. Please report this error to the Cimons Team at Cimons.com");
				running = isCimonsRunning();
			}
		}
	}
	else {
		version(OSX) {
			import core.sys.posix.unistd : setuid;
			setuid(0);
		}
		if (cast(string)args == "-restart")
			restart();
		version(OSX) {
			bool isInstalled() {
				return existsFile(DATA_FOLDER_PATH ~ "version.txt");
			}
		}
		bool is_installed = isInstalled();
		
		if (is_installed && is_uninstall) {
			version(Windows) removeService();
		}
		else if (!is_installed) 
		{
			version(Windows) copyFile(cast(string)args);
			installService(TORR_EXE_PATH);
			int sleep;
			while(!running) {
				import core.thread : Thread;
				sleep += 200;
				enforce(sleep <= 3000, "Could not complete installation process. Please report this error to the Cimons Team at Cimons.com");
				running = isCimonsRunning();
			}
			openInBrowser();
		} else {
			import std.file : thisExePath,  copy, remove, rename;
			
			import semver : compareVersions;
			
			version(Windows) 
				if (!existsFile(TORR_EXE_PATH))
					copy(cast(char[])thisExePath(), TORR_EXE_PATH);
			
			if (!running) {
				version(Windows) try if (thisExePath() != TORR_EXE_PATH && compareVersions(getVersion(), TORR_VERSION) < 0) {
					try {
						if (!existsFile(DATA_FOLDER_PATH() ~ "backup"))
							createDirectory(DATA_FOLDER_PATH() ~ "backup");
					}
					catch(Throwable) {}
					import std.file : rename;
					try rename(TORR_EXE_PATH, DATA_FOLDER_PATH ~ DS ~ "backup" ~ DS ~ "cimons_" ~ getVersion() ~ ".exe");
					catch(Throwable) {}
					copy(cast(char[])thisExePath(), TORR_EXE_PATH);
				} catch(Throwable) { throw new Exception("Could not update, try disabling your antivirus."); }
				import core.thread;
				version(OSX) installService(TORR_EXE_PATH);
				version(Windows) startService();
				try updateVersion();
				catch(Throwable) { }
				if (args.length == 0) return;
			}
			import semver : compareVersions;
			if (installed_version.length > 0 && compareVersions(TORR_VERSION, installed_version) > 0) {
				version(Windows){
					if (!existsFile(DATA_FOLDER_PATH() ~ "backup"))
						createDirectory(DATA_FOLDER_PATH() ~ "backup");
					import std.file : rename;
					try rename(TORR_EXE_PATH, DATA_FOLDER_PATH() ~ "backup" ~ DS ~ "cimons.exe." ~ installed_version);
					catch(Throwable) {}
					copy(cast(char[])thisExePath(), TORR_EXE_PATH);
					try updateVersion(); catch(Throwable) {}
				}
				version(OSX) installService(TORR_EXE_PATH);
				version(Windows) {
					restart();
					import core.thread : Thread;
					Thread.sleep(3.seconds);
				}
				running = false;
			}
			int sleep;
			while(!running) {
				sleep += 500;
				enforce(sleep <= 8000, "Failed to start. An application may be preventing Cimons from starting, such as an antivirus or firewall.");
				running = isCimonsRunning();
			}
			import core.thread : Thread;
			if (!existsFile(DATA_FOLDER_PATH ~ "session.db"))
				Thread.sleep(2.seconds);
			openInBrowser();
		}
	}
}
version(Windows):
private import core.sys.windows.windows;
/// Windows entry point
extern (Windows) int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	static import std.stdio;
	int result;
	try
	{
		Runtime.initialize();
		try std.stdio.stdin.close(); catch(Throwable) {}
		try std.stdio.stdout.close(); catch(Throwable) {}
		try std.stdio.stderr.close(); catch(Throwable) {}
		result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);
		Runtime.terminate();
	}
	catch (Throwable e) 
	{
		MessageBoxA(null, e.msg.toStringz(), "Error", MB_OK | MB_ICONERROR);
		result = 0;     // failed
		Runtime.terminate();
	}
	
	return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
	LPSTR lpCmdLine, int nCmdShow)
{
	import std.string : fromStringz;
	dmain(lpCmdLine.fromStringz() );
	return 0;
}
