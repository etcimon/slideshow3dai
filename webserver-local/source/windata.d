module windata;
version(Windows):
import std.conv : to;
import helpers;
import winmultiling;
/// This script will pin the application to the taskbar
string pinScript(string folder, string file) {
	return `var shell = new ActiveXObject("Shell.Application");	
	var folder = shell.NameSpace("` ~ escape(folder) ~ `");
	var folderItem = folder.ParseName("` ~ file ~ `");
	var itemVerbs = folderItem.Verbs();
	for (var i = 0; i < itemVerbs.Count; i++)
	{
		if (itemVerbs.Item(i) != null && itemVerbs.Item(i).Name)
		{
			if(itemVerbs.Item(i).Name.replace(/&/,"").match(/` ~ MultilingualDict.pin ~ `/gi)) {
				itemVerbs.Item(i).DoIt();
				break;
			}
		}
	}`;
}

/// This script will unpin the application from the taskbar
string unpinScript(string folder, string file) {
	return `var shell = new ActiveXObject("Shell.Application");	
	var folder = shell.NameSpace("` ~ escape(folder) ~ `");
	var folderItem = folder.ParseName("` ~ file ~ `");
	var itemVerbs = folderItem.Verbs();
	for (var i = 0; i < itemVerbs.Count; i++)
	{
		if (itemVerbs.Item(i) != null && itemVerbs.Item(i).Name)
		{
			if(itemVerbs.Item(i).Name.replace(/&/,"").match(/` ~ MultilingualDict.unpin ~ `/gi)) {
				itemVerbs.Item(i).DoIt();
				break;
			}
		}
	}`;
}

// Alternative to returning a failure code with autorestart
// Can also be used from a foreign process
string restartService() {
	return `On Error Resume Next
			AppToRun = "cmd.exe /C net stop cimonsclient & taskkill /f /im cimons.exe & net start cimonsclient"
			dim WshShell
			set WshShell = WScript.CreateObject("WScript.Shell")
			WshShell.Run AppToRun, 1
			if (Err.Number <> 0) then
				WScript.Quit 1
			end if
`;

}

/// This was the only way to stop the service correctly
string stopService() {
	return `On Error Resume Next
			AppToRun = "cmd.exe /C net stop cimonsclient & taskkill /f /im cimons.exe"
			dim WshShell
			set WshShell = WScript.CreateObject("WScript.Shell")
			WshShell.Run AppToRun, 1
			if (Err.Number <> 0) then
				WScript.Quit 1
			end if
`;
	
}

/// Opens chrome with given dimensions
string openChrome(string url, int width, int height, int x, int y) {
	return `On Error Resume Next
			AppToRun = "chrome --app=` ~ url ~ ` --app-shell-host-window-size=` ~ width.to!string ~ `,` ~ height.to!string ~ ` --window-position=` ~ x.to!string ~ `,` ~ y.to!string ~ `"
			dim WshShell
			set WshShell = WScript.CreateObject("WScript.Shell")
			WshShell.Run AppToRun, 1
			if (Err.Number <> 0) then
				WScript.Quit 1
			end if
`;
}

string openFF(string url) {
	return `On Error Resume Next
			AppToRun = "firefox -chrome ` ~ url ~ `"
			dim WshShell
			set WshShell = WScript.CreateObject("WScript.Shell")
			WshShell.Run AppToRun, 1
			if (Err.Number <> 0) then
				WScript.Quit 1
			end if
`;
}


string openIE(string url, int width, int height, int x, int y)
{
	return `On Error Resume Next

			AppURL = "` ~ url ~ `"
			AppToRun = "iexplore about:blank"
			AboutBlankTitle = "Blank Page"
			LoadingMessage = "Loading Cimons..."
			ErrorMessage = "An error occurred while loading cimons.  Please close the Internet Explorer with Blank Page and try again."
			EmptyTitle = ""

			dim objShell
			set objShell = CreateObject("Shell.Application")
			dim objShellWindows

			dim ieStarted
			ieStarted = false

			dim ieOpened
			ieOpened = false

			dim ieError
			ieError = false

			dim seconds
			seconds = 0

			WScript.sleep 1000
			while (not ieStarted) and (not ieError) and (seconds < 7)

				set objShellWindows = objShell.Windows
			    if (not objShellWindows is nothing) then
			    	dim objIE
			    	dim IE

			    	'For each IE object
			    	for each objIE in objShellWindows

			    		if (not objIE is nothing) then

			    			if isObject(objIE.Document) then
			    				set IE = objIE.Document

			    				'For each IE object that isn't an activex control
			    				if VarType(IE) = 8 then

									if Err.Number = 0 then
										IE.Write LoadingMessage
										objIE.Top = ` ~ y.to!string ~ `
										objIE.Left = ` ~ x.to!string ~ `
										objIE.Width = ` ~ width.to!string ~ `
										objIE.Height = ` ~ height.to!string ~ `
										objIE.ToolBar = 0
										objIE.StatusBar = 0
										objIE.Navigate2 AppURL
										
										ieStarted = true
									end if
									
									Exit For
								end if
			    			end if
			    		end if

			    		set IE = nothing
			    		set objIE = nothing
			    	Next
			    end if

				if (ieStarted = false) then 
					if (ieOpened = false) then
						ieOpened = true
						'Launch Internet Explorer in a separate process as a minimized window so we don't see the toolbars disappearing
						dim WshShell
						set WshShell = WScript.CreateObject("WScript.Shell")
						WshShell.Run AppToRun
					end if
					WScript.sleep 1000
					seconds = seconds + 1
				end if
			wend
			if (not ieStarted) then 
				WScript.Quit 1
			end if
			set objShellWindows = nothing
			set objShell = nothing
`;
}

private:

string escape(char ch)
{
	switch(ch){
		default: return ""~ch;
		case '\\': return "\\\\";
	}
}

string escape(in ref string str)
{
	import std.array : Appender;
	Appender!string ret;
	foreach( ch; str ) ret ~= escape(ch);
	return ret.data;
}
