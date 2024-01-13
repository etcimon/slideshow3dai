module winscripts;
version(Windows) {
	private import windata;
	private import core.sys.windows.windows : GetSystemMetrics, SM_CXSCREEN, SM_CYSCREEN;
}
import vibe.core.file;
import std.process;
import std.exception;
import std.datetime : seconds;
import vibe.core.core : sleep;
import config;

version(OSX) {
	void openInBrowser() {
		auto pipe = pipeShell("open " ~ LOCAL_URL, cast(Redirect)0, ["path": "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"], Config.suppressConsole);
		enforce(pipe.pid, "Could not open Cimons in a suitable Web Browser. Please open one and navigate to " ~ LOCAL_URL);
	}

	void startService() {
		executeShell(`launchctl load /Library/LaunchDaemons/cimons.plist`);
		executeShell(`launchctl start /Library/LaunchDaemons/cimons.plist`);
		import core.thread : Thread;
		Thread.sleep(4.seconds);
	}

	void restart() {
		import vibe.core.core : setTimer, exitEventLoop;
		g_restart = true;
		setTimer(1.seconds, { exitEventLoop(true); });
	}

	string getVersion() {
		string installed_version;

		if (!existsFile(DATA_FOLDER_PATH() ~ "version.txt"))
			return "0.0.0";
		return cast(string) readFile(DATA_FOLDER_PATH() ~ "version.txt");
	}

}
// open a chrome window
version(Windows):
void openInBrowser() {
	bool ok = openInChrome();
	if (!ok)
		ok = openInIE();
	if (!ok)
		ok = openInFirefox();
	if (!ok) {
		auto pipe = pipeShell("start " ~ LOCAL_URL, cast(Redirect)0, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
		enforce(pipe.pid, "Could not open Cimons in a suitable Web Browser. Please open one and navigate to " ~ LOCAL_URL);
	}
}
bool pin()
{
	FileStream pinner = openFile(DATA_FOLDER_PATH() ~ "pin.js", FileMode.createTrunc);
	pinner.write(pinScript(TORR_EXE_FOLDER_PATH, "cimons.exe"));
	pinner.close();
	auto ret = executeShell(`wscript "` ~ DATA_FOLDER_PATH() ~ "pin.js" ~ `"`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	removeFile(DATA_FOLDER_PATH() ~ "pin.js");
	return ret.status == 0;
}

bool unpin()
{
	FileStream unpinner = openFile(DATA_FOLDER_PATH() ~ "unpin.js", FileMode.createTrunc);
	unpinner.write(unpinScript(TORR_EXE_FOLDER_PATH, "cimons.exe"));
	unpinner.close();

	auto ret = executeShell(`wscript "` ~ DATA_FOLDER_PATH() ~ "unpin.js" ~ `"`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	removeFile(DATA_FOLDER_PATH() ~ "unpin.js");
	return ret.status == 0;
}

void restart() {
	FileStream restarter = openFile(DATA_FOLDER_PATH() ~ "restart.vbs", FileMode.createTrunc);
	restarter.write(restartService());
	restarter.close();

	auto ret = executeShell(`wscript "` ~ DATA_FOLDER_PATH() ~ "restart.vbs" ~ `"`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	//removeFile(DATA_FOLDER_PATH() ~ "restart.vbs");
}

void stop() {

	FileStream stopper = openFile(DATA_FOLDER_PATH() ~ "stop.vbs", FileMode.createTrunc);
	stopper.write(stopService());
	stopper.close();

	auto ret = executeShell(`wscript "` ~ DATA_FOLDER_PATH() ~ "stop.vbs" ~ `"`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	//removeFile(DATA_FOLDER_PATH() ~ "stop.vbs");
}

private:

int screenWidth() {
	return GetSystemMetrics(SM_CXSCREEN);
}

int screenHeight() {
	return GetSystemMetrics(SM_CYSCREEN);
}

bool openInChrome()
{
	try {
		FileStream chrome = openFile(DATA_FOLDER_PATH() ~ "chrome.vbs", FileMode.createTrunc);
		scope(exit)
			chrome.close();
		chrome.write(openChrome(LOCAL_URL, APP_WIDTH, APP_HEIGHT, ((screenWidth()-APP_WIDTH)/2), ((screenHeight()-APP_HEIGHT)/2)));
	} catch(Throwable) {} 
	auto ret = executeShell(`wscript "` ~ DATA_FOLDER_PATH() ~ "chrome.vbs" ~ `"`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	return ret.status == 0;
}

// must find another solution than pipeShell, the UI freezes if the browser stayed open
bool openInFirefox()
{
	try {
		FileStream firefox = openFile(DATA_FOLDER_PATH() ~ "firefox.vbs", FileMode.createTrunc);
		scope(exit)
			firefox.close();
		firefox.write(openFF(LOCAL_URL));
	} catch(Throwable) {} 
	auto ret = executeShell(`wscript "` ~ DATA_FOLDER_PATH() ~ "firefox.vbs" ~ `"`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	return ret.status == 0;
}

bool openInIE()
{
	try {
		FileStream iexplore = openFile(DATA_FOLDER_PATH() ~ "iexplore.vbs", FileMode.createTrunc);
		scope(exit)
			iexplore.close();
		iexplore.write(openIE(LOCAL_URL, APP_WIDTH, APP_HEIGHT, ((screenWidth()-APP_WIDTH)/2), ((screenHeight()-APP_HEIGHT)/2)));
	} catch(Throwable) {}
	auto ret = executeShell(`wscript "` ~ DATA_FOLDER_PATH() ~ "iexplore.vbs" ~ `"`, ["path": "C:\\Windows\\System32"], Config.suppressConsole);
	return ret.status == 0;
	
}
