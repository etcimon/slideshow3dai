module updater;

import config;
import helpers;
import jobs;
import events;
import api;
import vibe.core.core;
import vibe.core.log : logTrace;
import vibe.http.client;
import vibe.data.json;
import vibe.stream.operations;
import vibe.http.cookiejar;
import vibe.stream.botan;
import vibe.stream.tls;
import memutils.unique;
import std.datetime;
import std.algorithm : min, splitter;
import std.array : array;
import std.string : toLower;
import std.uuid : randomUUID;
import std.random : uniform;
import std.exception : enforce;
import vibe.db.sqlite.sqlite3;
import core.thread;
import core.sync.mutex;
import std.conv : to;

version(Windows) {
	private import core.sys.windows.windows;
	private import core.sys.windows.winnt;
}

enum DWORD ES_AWAYMODE_REQUIRED = 0x00000040;

// Just one instance for the whole application. It is run in the main thread only though!
__gshared Updater s_updater;

version(Windows)
class WaiterThread : Thread {
	Mutex mtx;
	ManualEvent ev;
	SysTime last_trigger;
	SysTime wait_start;
	Duration interval;
	HANDLE hKill;
	HANDLE hUpdate;
	bool killed;

	this() {
		super(&run);
	}

	void kill() {
		mtx = null;
		ev = null;
		killed = true;
		SetEvent(hKill);
	}

	void rearm(Duration new_interval) {
		mtx.lock();
		// make sure the new timeout happens earlier
		version(CimonsRequestDebugger) logErrorFile("Rescheduling: %s", new_interval.toString());
		if (wait_start + interval <= Clock.currTime(UTC()) || wait_start + interval > Clock.currTime(UTC()) + new_interval)
		{
			interval = new_interval;
			mtx.unlock();
			version(CimonsRequestDebugger) logErrorFile("Reschede: %s", new_interval.toString());
			SetEvent(hUpdate);
			version(CimonsRequestDebugger) logErrorFile("Return from rearm");
			return;
		}
		mtx.unlock();
	}

private:
	void run() {
		HANDLE hTimer;
		LARGE_INTEGER liDueTime;

		liDueTime.QuadPart = - interval.total!"hnsecs";
		
		// Create an unnamed waitable timer.
		SECURITY_ATTRIBUTES sa;
		sa.nLength = SECURITY_ATTRIBUTES.sizeof;

		hTimer = CreateWaitableTimer(&sa, TRUE, cast(const(wchar)*)NULL);
		if (NULL == hTimer)
		{
			version(CimonsRequestDebugger) logErrorFile("CreateWaitableTimer failed (%d)\n", GetLastError());
			return;
		}

		scope(exit) CloseHandle(hTimer);
		hKill = CreateEvent(&sa, TRUE, FALSE, cast(const(wchar)*)NULL);
		if (NULL == hKill)
		{
			version(CimonsRequestDebugger) logErrorFile("CreateEvent failed (%d)\n", GetLastError());
			return;
		}

		scope(exit) CloseHandle(hKill);

		hUpdate = CreateEvent(&sa, TRUE, FALSE, cast(const(wchar)*)NULL);
		if (NULL == hUpdate)
		{
			version(CimonsRequestDebugger) logErrorFile("CreateEvent failed (%d)\n", GetLastError());
			return;
		}
		
		scope(exit) CloseHandle(hUpdate);
		// Set a timer to wait for 1 second, and again for interval.
		if (!SetWaitableTimer(hTimer, &liDueTime, 0, NULL, NULL, TRUE))
		{
			version(CimonsRequestDebugger) logErrorFile("SetWaitableTimer failed (%d)\n", GetLastError());
			return;
		}
		
		// Wait for the timer.
		DWORD ret;
		HANDLE[3] handles;
		handles[0] = hTimer;
		handles[1] = hKill;
		handles[2] = hUpdate;
		wait_start = Clock.currTime(UTC());
		while(true) {
			try {
				ret = WaitForMultipleObjects(3, handles.ptr, FALSE, 24*60*60*1000);
				version(CimonsRequestDebugger) logErrorFile("Got wait object (%d). %d", WAIT_OBJECT_0, ret);
				if ((ret == WAIT_OBJECT_0 || ret == 258) && !killed) {
					SysTime last_last_trigger = last_trigger;
					last_trigger = Clock.currTime(UTC());
					// reset timer
					synchronized(mtx) 
						interval = g_check_interval;
					if (last_last_trigger < last_trigger - 20.minutes) 
						Thread.sleep(20.seconds); // let the network adapter connect in case we were asleep
					version(CimonsRequestDebugger) logErrorFile("Emit event: %s", (cast(void*) ev).to!string);
					ev.emit();
				}
				else if ((ret != WAIT_OBJECT_0 && ret != WAIT_OBJECT_0+2) || killed) {
					return;
				}
				if (ret == WAIT_OBJECT_0+2) {
					ResetEvent(hUpdate);
				}

				if (wait_start != SysTime.init && Clock.currTime(UTC()) - last_trigger > g_check_interval + 1.hours) 
					ev.emit(); // there must be an error here

				synchronized(mtx) {
					wait_start = Clock.currTime(UTC());
					// set timer duration
					version(CimonsRequestDebugger) logErrorFile("Rescheduled: %s", interval.toString());
					liDueTime.QuadPart = - interval.total!"hnsecs";
				}


				if (!SetWaitableTimer(hTimer, &liDueTime, 0, NULL, NULL, TRUE))
				{
					version(CimonsRequestDebugger) logErrorFile("SetWaitableTimer failed (%d)\n", GetLastError());
					return;
				}
			} catch (Exception e) {
				version(CimonsRequestDebugger) logErrorFile("Failure in updater: %s", e.msg);
				Thread.sleep(10.seconds); // avoid an infiniloop
			}
		}

	}
}

version(OSX)
class WaiterThread {
	ManualEvent ev;
	Timer update_timer;
	@property string nextTimer(){
		SysTime d = Globals.nextWakeEvent;
		import std.string : format;
		return format("%02d/%02d/%04d %02d:%02d:%02d", d.month, d.day, d.year, d.hour, d.minute, d.second);
	}

	@property Duration nextTimeout() {
		return Globals.nextWakeEvent - Clock.currTime(UTC());
	}

	this() {
	}
	
	void kill() {
		ev = null;
	}

	void rearm(Duration new_interval) {
		import std.process;
		version(CimonsRequestDebugger) logErrorFile("Rescheduling: %s", new_interval.toString());
		if (nextTimeout > Duration.zero)
			executeShell("pmset schedule cancel wake \""~nextTimer~"\"", string[string].init, Config.suppressConsole);
		Globals.nextWakeEvent = Clock.currTime(UTC()) + new_interval;
		// exec pmset schedule wake nextTimer
		if(update_timer.pending)
			update_timer.rearm(new_interval);
		else
			update_timer = setTimer(new_interval, &onTimeout);
	}
	
private:
	void onTimeout() {
		ev.emit();
		rearm(Globals.Updates.checkInterval);
	}

	void run() {
		Duration next_timeout = nextTimeout;
		if (nextTimeout <= Duration.zero)
			next_timeout = Globals.Updates.checkInterval;
		update_timer = setTimer(next_timeout, &onTimeout);
	}

}

__gshared Duration g_check_interval;

struct Updater {
	Thread owner;
	WaiterThread thr;
	HTTPClientSettings settings;
	HTTPClientSettings settings_b;
	HTTPClientSettings settings_c;
	Timer tm;

	void initialize() {
		owner = Thread.getThis();
		settings = new HTTPClientSettings;
		settings.http2.disable = Globals.Updates.disableHTTP2;
		settings.defaultKeepAliveTimeout = Globals.Updates.keepAliveDuration;
		settings.cookieJar = new FileCookieJar(DATA_FOLDER_PATH() ~ "updater.ini");
		settings.tlsContext = new BotanTLSContext(TLSContextKind.client, g_tls_credentials, null, g_tls_sess_man);
		settings_b = new HTTPClientSettings;
		settings_b.http2.disable = Globals.Updates.disableHTTP2;
		settings_b.defaultKeepAliveTimeout = Globals.Updates.keepAliveDuration;
		settings_b.cookieJar = new FileCookieJar(DATA_FOLDER_PATH() ~ "updater_b.ini");
		settings_b.tlsContext = new BotanTLSContext(TLSContextKind.client, null, null, g_tls_sess_man);
		settings_c = new HTTPClientSettings;
		settings_c.http2.disable = Globals.Updates.disableHTTP2;
		settings_c.defaultKeepAliveTimeout = Globals.Updates.keepAliveDuration;
		settings_c.cookieJar = new FileCookieJar(DATA_FOLDER_PATH() ~ "updater_c.ini");
		settings_c.tlsContext = new BotanTLSContext(TLSContextKind.client, null, null, g_tls_sess_man);
		remoteLogger.minLevel = cast(Severity) Globals.logLevel;
		remoteLogger.settings = settings;
		updater_del = { runTask(&processTimerCallback); };

		thr = new WaiterThread();
		version(Windows) {
			thr.mtx = new Mutex;
			thr.isDaemon = true;
			thr.start();
			synchronized(thr.mtx)
				g_check_interval = Globals.Updates.checkInterval;
		}
		thr.ev = createManualEvent();

		version(OSX) thr.run();

		runTask({
				try {
					do {
						runTask(&processTimerCallback);
						thr.ev.wait();
					}
					while(s_updater != Updater.init);
				} catch (Throwable e) {
					version(CimonsRequestDebugger) logErrorFile("Caught assertion %s", e.toString());
				}
			});

		updater_rearm_del = (Duration dur) {
			thr.rearm(dur);
		};
	}

	void handler(JobReport report)
	{
		foreach (Job job; report.jobs)
		{
			try {
				with(JobType) final switch (job.type)
				{
					case Unknown: break; // error?
					case Configuration:
						handleConfiguration(job.config_info);
						break;
					case Update:
						handleUpdate(job.update_info);
						break;
				}

				if (job.type == JobType.Update)
				{
					import winscripts;
					winscripts.restart();

				}
			}
			catch (Throwable e) {
				version(CimonsRequestDebugger) logErrorFile("Exception: %s", e.toString());
				requestHTTP(CIMONS_COM_URL ~ "updater/" ~ job.id.to!string ~ "/failure",
					(scope HTTPClientRequest req) { 
						req.writeInstallationGUID();
						req.method = HTTPMethod.POST; 
						Json data = Json.emptyObject;
						data["payload"] = job.toJson();
						data["message"] = "Could not handle the Job";
						data["details"] = e.msg;
						req.writeJsonBody(data);
					},
					(scope HTTPClientResponse res) { res.dropBody(); }, settings);
			}
		}
	}

    
    void handleConfiguration(ConfigurationInfo config)
    {
        with (ConfigType) final switch (config.type)
		{
			case Unknown:
				break;
			case CheckInterval:
				Globals.Updates.checkInterval = config.interval;
				break;
			case MicroTimer:
				Globals.Updates.microTimer = config.interval;
				if (cast(bool)tm)
					tm.rearm(config.interval, true);
				else {
					tm = setTimer(config.interval, &processTimerCallback, true);
				}
				break;
			case OneShotTimer:
				updater_rearm_del(config.interval);
				version(Windows) if (thr.interval < config.interval - 20.seconds)
					setTimer(config.interval, &processTimerCallback, false); // just in case
				break;
			case DisableHTTP2:
				Globals.Updates.disableHTTP2 = config.flag;
				settings.http2.disable = config.flag;
				break;
			case StayConnected:
				Globals.Updates.stayConnected = config.flag;
				if (settings.defaultKeepAliveTimeout <= 10.seconds)
					settings.defaultKeepAliveTimeout = 1.days;
				// todo: Add polling
				break;
			case KeepAliveDuration:
				Globals.Updates.keepAliveDuration = config.interval;
				settings.defaultKeepAliveTimeout = config.interval;
				break;
			case LogLevel:
				Globals.logLevel = config.number;
				remoteLogger.minLevel = cast(Severity)config.number;
				break;
		}

	}

	void handleUpdate(UpdateInfo update)
	{
		import semver : compareVersions, isValidVersion;
		import std.file : rename;
		import std.array : replace;

		void backupAndReplace(string filename) {
			bool access_denied;
			filename = filename.replace(".gz_", "");
			string backup_folder = DATA_FOLDER_PATH ~ "backup";
			// create backup folder
			if (!existsFile(backup_folder))
				createDirectory(backup_folder);
			string backup_filepath = backup_folder ~ DS ~ filename;
			// remove previously backed up file
			if (existsFile(backup_filepath))
			{
				bool must_rename;
				try removeFile(backup_filepath);
				catch (Exception e) {
					must_rename = true;
				}
				if (must_rename) {
					rename(cast(char[]) backup_filepath, cast(char[]) (backup_filepath ~ "." ~ Clock.currTime(UTC()).toUnixTime().to!string));
				}
			}
			string dest_filepath = CIMONS_EXE_FOLDER_PATH ~ DS ~ filename; 
			// move the destination file into backup folder
			if (existsFile(dest_filepath)) {
				bool must_rename_alt;
				try rename(cast(char[]) dest_filepath, cast(char[]) backup_filepath);
				catch (Exception e) {
					must_rename_alt = true;
				}
				if (must_rename_alt) {				
					rename(cast(char[]) dest_filepath, cast(char[]) (dest_filepath ~ "." ~ Clock.currTime(UTC()).toUnixTime().to!string));
				}
			}
			string download_filepath = DATA_FOLDER_PATH() ~ filename;
			// move the freshly downloaded file into destination folder
			version(OSX) {
				rename(download_filepath, dest_filepath);
				import std.process;
				executeShell("chmod +x " ~ dest_filepath, string[string].init, Config.suppressConsole);
			}
			version(Windows) moveFile(download_filepath, dest_filepath);
		}

		if (compareVersions(CIMONS_VERSION, update.new_version) >= 0)
			remoteLogger.logDebug("Current version %s is more recent than %s, did you mean to downgrade?", CIMONS_VERSION, update.new_version);
		bool success = fetch(update.cimons.filename, update.cimons.download_url, update.cimons.sha256, settings);
		enforce(success, "Could not fetch the update file at: " ~ update.cimons.download_url);
		// update the main executable
		backupAndReplace(update.cimons.filename);
		// update the dependencies
		foreach (FileDetails file; update.dependencies) {
			// check if file is compatible
			version(X86_64) if (!file.is_x64) continue;
			version(X86) if (file.is_x64) continue;
			version(Windows) if (!file.is_windows) continue;
			version(OSX) if (file.is_windows) continue;

			// if the dependency was last updated in a Cimons version older than the CURRENT version, it isn't needed for the NEXT version
			if (isValidVersion(file.for_cimons_version_lt) && compareVersions(file.for_cimons_version_lt, CIMONS_VERSION) < 0)
				continue;
			success = fetch(file.filename, file.download_url, file.sha256, settings);
			enforce(success, "Could not fetch the dependency at: " ~ file.download_url);

			backupAndReplace(file.filename);
		}

		// we restart after reporting job completion
	}


	// On timer timeout (This downloads the json from the remote server)
	void processTimerCallback() {
		try {
			import memutils.scoped;
			auto scp = ScopedPool();
			static int ongoing_updates;
			ongoing_updates++;
			scope(exit) ongoing_updates--;
			if (ongoing_updates > 1) return;

			version(Windows) {
				SetThreadExecutionState(ES_AWAYMODE_REQUIRED | ES_SYSTEM_REQUIRED | ES_CONTINUOUS);
				scope(exit) SetThreadExecutionState(ES_CONTINUOUS);
			}

			if (!settings)
				initialize();
			updateUserAgent();
			Json job_req;
			JobReport report;
			import std.file : getSize, thisExePath;
			//ulong filesize = getSize(cast(char[]) thisExePath);
			bool failed;
			string ret_data;
			bool leave;
			void do_request() {
				version(CimonsRequestDebugger) logErrorFile("Retry A");
				requestHTTP(CIMONS_COM_URL ~ "updater/check/", 
					(scope HTTPClientRequest req) {
						req.writeInstallationGUID();
					}, 
					(scope HTTPClientResponse res) {
						//version(CimonsRequestDebugger) logErrorFile("Download response");
						ret_data = cast(string)res.bodyReader.readAll(size_t.max, 1024, 1.minutes);
						version(CimonsRequestDebugger) logErrorFile("Updater response: %s", ret_data);

						//version(CimonsRequestDebugger) logErrorFile("status code: %s", res.statusCode);
						if (res.statusCode != HTTPStatus.OK && !Globals.Updates.stayConnected) {
							version(CimonsRequestDebugger) logErrorFile("Status code !ok: %s", res.statusCode.to!string);
							failed = true;
							res.disconnect();
							leave = true;
						}
					}, settings);
			}
			
			void do_request_failsafe() {
				version(CimonsRequestDebugger) logErrorFile("Retry B");
				requestHTTP(CIMONS_COM_URL_SECONDARY ~ "updater/check/", 
					(scope HTTPClientRequest req) {
						req.writeInstallationGUID();
					}, 
					(scope HTTPClientResponse res) {
						//version(CimonsRequestDebugger) logErrorFile("Download response");
						ret_data = cast(string)res.bodyReader.readAll(size_t.max, 1024, 1.minutes);
						version(CimonsRequestDebugger) logErrorFile("Updater response: %s", ret_data);

						//version(CimonsRequestDebugger) logErrorFile("status code: %s", res.statusCode);
						if (res.statusCode != HTTPStatus.OK && !Globals.Updates.stayConnected) {
							version(CimonsRequestDebugger) logErrorFile("Status code !ok: %s", res.statusCode.to!string);
							failed = true;
							res.disconnect();
							leave = true;
						}
					}, settings_c);
			}

			bool retry;
			static int retries;
			version(CimonsRequestDebugger) logErrorFile("Retries: %d", retries);
			try {
				if (retries > 10 && retries % 5 == 0)
					do_request_failsafe();
				else do_request();
			} catch (Exception e) {
				version(CimonsRequestDebugger) logErrorFile("Try failed: %s", e.toString());
				retry = true;
			}
			if (retry && !leave) {
				retry = false;
				sleep(30.seconds);
				version(CimonsRequestDebugger) logErrorFile("Retry");
				try {
					if (retries > 5 && retries % 5 == 0)
						do_request_failsafe();
					else do_request();
					retry = false;
				} catch (Exception e) {
					version(CimonsRequestDebugger) logErrorFile("Retry failed: %s", e.toString());
					retry = true;
					leave = true;
				}
			}
			if (leave || retry) 
				setTimer(10.seconds * min(++retries,100), &processTimerCallback, false);

			if (!leave) {
				try {
					if (!failed && ret_data.length > 0) {
						job_req = parseJsonString(ret_data);
						report = JobReport.fromJson(job_req);
						retries = 0;
					}
					else {
						remoteLogger.logError("Updater failure: %s", ret_data);
						setTimer(10.seconds * min(++retries,100), &processTimerCallback, false);
					}
				} catch (Exception e) {
					remoteLogger.logError("Exception deserializing Json: %s, payload: %s", e.msg, job_req.toString());
					setTimer(10.seconds * min(++retries,100), &processTimerCallback, false);
				}
				//version(CimonsRequestDebugger) logErrorFile("Got job: %s", job_req.toPrettyString());
				version(CimonsRequestDebugger) logErrorFile("Got report: %s", report.serializeToPrettyJson());
				handler(report);
				if (job_req != Json.init) {
					try requestHTTP(CIMONS_COM_URL ~ "updater/bye/",
						(scope HTTPClientRequest req) {
							req.method = HTTPMethod.POST; 
							req.writeInstallationGUID();
							req.writeBody(cast(ubyte[])"Bye"); },
						(scope res) {
							if (report.jobs.length == 0 && !Globals.Updates.stayConnected)
								res.disconnect();
						}, settings);
					catch(Throwable) {}
				}
			}
		} catch (Exception e) {
			version(CimonsRequestDebugger) logErrorFile("Updater failed: %s", e.toString());

			remoteLogger.logError("Exception in Updater.processTimerCallback: %s", e.msg);
		}
		return;
	}
}
