module winregistry;

version(Windows):
import std.windows.registry;
import standardpaths;
import winhelpers;
import vibe.daemonize.windows;
import std.file : exists;
import config;

bool isInstalled() {
	return Registry.localMachine.getKey("Software").getKey("Microsoft").getKey("Windows").getKey("CurrentVersion").getKey("Uninstall").keyExists("Cimons");
}

string getComputerName() {
	return Registry.localMachine.getKey("System").getKey("CurrentControlSet").getKey("Control").getKey("ComputerName").getKey("ComputerName").getValue("ComputerName").value_SZ.idup;
}
void createUninstaller() {

	Key HKLM = Registry.localMachine;
	Key uninstall_info = HKLM.getKeyRW("Software").getKeyRW("Microsoft").getKeyRW("Windows").getKeyRW("CurrentVersion").getKeyRW("Uninstall").maybeCreateKey("Cimons");
	uninstall_info.setValue("DisplayIcon", TORR_EXE_PATH);
	uninstall_info.setValue("DisplayName", "Cimons");
	uninstall_info.setValue("DisplayVersion", TORR_VERSION);
	uninstall_info.setValue("InstallLocation", TORR_EXE_FOLDER_PATH);
	uninstall_info.setValue("Language", cast(uint)0);
	uninstall_info.setValue("NoModify", cast(uint)1);
	uninstall_info.setValue("NoRepair", cast(uint)1);
	uninstall_info.setValue("Publisher", "Cimons Team");
	uninstall_info.setValue("UninstallString", `"` ~ TORR_EXE_PATH ~ `" --uninstall`);
	uninstall_info.setValue("VersionMajor", cast(uint)2);
	uninstall_info.setValue("VersionMinor", cast(uint)0);
	uninstall_info.setValue("EstimatedSize", 6800);
	uninstall_info.setValue("UrlInfoAbout", "http://cimons.com");
}

void removeUninstaller() {
	
	import std.windows.registry;
	Key HKLM = Registry.localMachine;
	HKLM.getKeyRW("Software").getKeyRW("Microsoft").getKeyRW("Windows").getKeyRW("CurrentVersion").getKeyRW("Uninstall").deleteKey("Cimons", REGSAM.KEY_ALL_ACCESS);
}

string getVersion() {
	import std.windows.registry;
	Key HKLM = Registry.localMachine;
	return HKLM.getKey("Software").getKey("Microsoft").getKey("Windows").getKey("CurrentVersion").getKey("Uninstall").getKey("Cimons").getValue("DisplayVersion").value_SZ.idup;
}

void updateVersion() {
	string new_version = TORR_VERSION;
	import std.windows.registry;
	Key HKLM = Registry.localMachine;
	return HKLM.getKeyRW("Software").getKeyRW("Microsoft").getKeyRW("Windows").getKeyRW("CurrentVersion").getKeyRW("Uninstall").getKeyRW("Cimons").setValue("DisplayVersion", new_version);
}

private:
Key getKeyRW(Key parent, string name) {
	return parent.getKey(name, REGSAM.KEY_ALL_ACCESS);
}

// @admin
Key maybeCreateKey(Key parent, string name) {
	if (!keyExists(parent, name)) {
		return parent.createKey(name);
	}
	return parent.getKeyRW(name);	
}

// @user
bool keyExists(Key parent, string name) {
	foreach (ref string value; parent.keyNames()) 
		if (name == value)
			return true;
	return false;
}

// @user
bool valueExists(Key parent, string name) {
	foreach (ref string value; parent.valueNames()) 
		if (name == value)
			return true;
	return false;
}