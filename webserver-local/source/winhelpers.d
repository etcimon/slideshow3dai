module winhelpers;

version(Windows):
private import core.sys.windows.windows;
private import core.sys.windows.windef;
private import core.sys.windows.shellapi;
private import core.sys.windows.winuser;
private import core.sys.windows.uuid;
private import core.sys.windows.unknwn;
private import core.sys.windows.objbase;
private import core.sys.windows.objbase : CoInitialize, CoUninitialize;
private import core.sys.windows.objidl : IPersistFile;
private import core.sys.windows.shlobj;
private import core.sys.windows.wtypes : CLSCTX;

private import core.sys.windows.psapi;
private import core.sys.windows.winnt;
private import core.sys.windows.winbase;
private import core.sys.windows.winver;
import std.conv : to;
import std.string;
/****************************** Module Header ******************************\
Module Name:  CppUACSelfElevation.cpp
Project:      CppUACSelfElevation
Copyright (c) Microsoft Corporation.

User Account Control (UAC) is a new security component in Windows Vista and 
newer operating systems. With UAC fully enabled, interactive administrators 
normally run with least user privileges. This example demonstrates how to 
check the privilege level of the current process, and how to self-elevate 
the process by giving explicit consent with the Consent UI. 

This source is subject to the Microsoft Public License.
See http://www.microsoft.com/en-us/openness/resources/licenses.aspx#MPL.
All other rights reserved.

THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
\**************************************************************************/

alias ElevateStatus = int;
enum : ElevateStatus {
	USER_CANCELLED = -3,
	ELEVATE_ERROR = -2,
	OTHER_ERROR = -1,
	ELEVATE_SUCCESS = 0,
	ALREADY_ELEVATED = 1
}

struct Elevation {
	ElevateStatus status;
	string text;
}

bool canElevate() {
	return IsUserInAdminGroup() > 0;
}

bool isElevated() {
	return IsRunAsAdmin() > 0;
}

Elevation elevateProcess(string path, char[] args) {
	BOOL fIsRunAsAdmin;
	try
	{
		fIsRunAsAdmin = IsRunAsAdmin();
	}
	catch (Exception e)
	{
		return Elevation(OTHER_ERROR, e.msg);
	}
	
	// Elevate the process if it is not run as administrator.
	if (!fIsRunAsAdmin)
	{
		wchar[MAX_PATH] szPath;
		wchar* pszPath;
		if (!path) {
			GetModuleFileName(NULL, szPath.ptr, szPath.sizeof);
			pszPath = szPath.ptr;
		}
		else {
			import std.utf : toUTF16z;
			pszPath = cast(wchar*)path.toUTF16z;
		}
		if (pszPath !is null)
		{
			// Launch itself as administrator.
			SHELLEXECUTEINFO sei;
			sei.lpVerb = "runas\0"w.ptr;
			sei.lpFile = pszPath;
			sei.hwnd = FindMyTopMostWindow();
			sei.nShow = SW_HIDE;
			import std.utf : toUTF16z;
			sei.lpParameters = args.toUTF16z;
			if (!ShellExecuteEx(&sei))
			{
				DWORD dwError = GetLastError();
				if (dwError == ERROR_CANCELLED)
				{
					return Elevation(USER_CANCELLED, "Refused Elevation");
				}
				return Elevation(ELEVATE_ERROR, ReportError("ShellExecuteEx", dwError));
			}
			return Elevation(ELEVATE_SUCCESS, null);
		}
		return Elevation(OTHER_ERROR, "Could not get current file path");
	}
	else
	{
		return Elevation(ALREADY_ELEVATED, null);
	}
	
}

ulong currentMemoryUsage() {
	PROCESS_MEMORY_COUNTERS cnt;
	BOOL ret = GetProcessMemoryInfo(GetCurrentProcess(), &cnt, cnt.sizeof);
	if (ret == 0)
		throw new Exception(ReportError("Could not get process memory info"));
	return cast(ulong)cnt.WorkingSetSize;
}

void createShortcut(string exe_file_path, string dest_shortcut_file, string _description) {
	
	import std.utf : toUTF16z;
	LPCWSTR pathToObj = exe_file_path.toUTF16z;
	LPCWSTR pathToLink = dest_shortcut_file.toUTF16z;
	LPCWSTR description = _description.toUTF16z;
	HRESULT hRes;
	IShellLink psl;
	CoInitialize(NULL);
	hRes = CoCreateInstance(cast(GUID*)&CLSID_ShellLink, cast(IUnknown)NULL, CLSCTX.CLSCTX_INPROC_SERVER, cast(GUID*)&IID_IShellLinkW, cast(LPVOID*)&psl);
	if (SUCCEEDED(hRes))
	{
		IPersistFile ppf;
		psl.SetPath(pathToObj);
		psl.SetDescription(description);
		hRes = psl.QueryInterface(cast(IID*)&IID_IPersistFile, cast(LPVOID*) &ppf);
		if (SUCCEEDED(hRes))
		{
			ppf.Save(pathToLink, true);
			ppf.Release();
		}
		else {
			throw new Exception("Error creating shortcut " ~ hRes.to!string);
		}
		psl.Release();
	}
	else {
		throw new Exception("Error creating shortcut " ~ hRes.to!string);
	}
	CoUninitialize();
}

ulong availableRAM() {
	MEMORYSTATUSEX mem;
	GlobalMemoryStatusEx(&mem);
	return mem.ullAvailPhys/1000;
}

string OSVersion() {
	string ret;/*
	if (IsWindowsXPOrGreater())
		ret = "5.1";	
	else return ret;

	if (IsWindowsXPSP1OrGreater())
		ret = "5.1 sp1";	
	else return ret;

	if (IsWindowsXPSP2OrGreater())
		ret = "5.1 sp2";
	else return ret;

	if (IsWindowsXPSP3OrGreater())
		ret = "5.1 sp3";
	else return ret;

	if (IsWindowsVistaOrGreater())
		ret = "6.0";
	else return ret;

	if (IsWindowsVistaSP1OrGreater())
		ret = "6.0 sp1";
	else return ret;

	if (IsWindowsVistaSP2OrGreater())
		ret = "6.0 sp2";
	else return ret;

	if (IsWindows7OrGreater())
		ret = "6.1";
	else return ret;

	if (IsWindows7SP1OrGreater())
		ret = "6.1 sp1";
	else return ret;

	if (IsWindows8OrGreater())
		ret = "6.2";
	else return ret;

	if (IsWindows8Point1OrGreater())
		ret = "6.2 sp1";
	else return ret;

	if (IsWindows10OrGreater())*/
		ret = "10.0";
	//else return ret;

	return ret;
}


private:
HWND FindMyTopMostWindow()
{
	DWORD dwProcID = GetCurrentProcessId();
	HWND hWnd = GetTopWindow(GetDesktopWindow());
	while(hWnd)
	{
		DWORD dwWndProcID = 0;
		GetWindowThreadProcessId(hWnd, &dwWndProcID);
		if(dwWndProcID == dwProcID)
			return hWnd;            
		hWnd = GetNextWindow(hWnd, GW_HWNDNEXT);
	}
	return NULL;
}

//
//   FUNCTION: IsUserInAdminGroup()
//
//   PURPOSE: The function checks whether the primary access token of the 
//   process belongs to user account that is a member of the local 
//   Administrators group, even if it currently is not elevated.
//
//   RETURN VALUE: Returns TRUE if the primary access token of the process 
//   belongs to user account that is a member of the local Administrators 
//   group. Returns FALSE if the token does not.
//
//   EXCEPTION: If this function fails, it throws a C++ DWORD exception which 
//   contains the Win32 error code of the failure.
//
//   EXAMPLE CALL:
//     try 
//     {
//         if (IsUserInAdminGroup())
//             wprintf ("User is a member of the Administrators group\n");
//         else
//             wprintf ("User is not a member of the Administrators group\n");
//     }
//     catch (DWORD dwError)
//     {
//         wprintf("IsUserInAdminGroup failed w/err %lu\n", dwError);
//     }
//
BOOL IsUserInAdminGroup()
{
	BOOL fInAdminGroup = FALSE;
	DWORD dwError = ERROR_SUCCESS;
	HANDLE hToken = NULL;
	HANDLE hTokenToCheck = NULL;
	DWORD cbSize = 0;
	OSVERSIONINFO osver;
	// Create the SID corresponding to the Administrators group.
	BYTE[SECURITY_MAX_SID_SIZE] adminSID;
	// Open the primary access token of the process for query and duplicate.
	if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY | TOKEN_DUPLICATE, &hToken))
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
	// Determine whether system is running Windows Vista or later operating 
	// systems (major version >= 6) because they support linked tokens, but 
	// previous versions (major version < 6) do not.
	if (!GetVersionEx(&osver))
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
	if (osver.dwMajorVersion >= 6)
	{
		// Running Windows Vista or later (major version >= 6). 
		// Determine token type: limited, elevated, or default. 
		TOKEN_ELEVATION_TYPE elevType;
		if (!GetTokenInformation(hToken, TOKEN_INFORMATION_CLASS.TokenElevationType, cast(void*)&elevType, cast(uint)elevType.sizeof, cast(uint*)&cbSize))
		{
			dwError = GetLastError();
			goto Cleanup;
		}
		
		// If limited, get the linked elevated token for further check.
		if (TOKEN_ELEVATION_TYPE.TokenElevationTypeLimited == elevType)
		{
			if (!GetTokenInformation(hToken, TOKEN_INFORMATION_CLASS.TokenLinkedToken, &hTokenToCheck, hTokenToCheck.sizeof, &cbSize))
			{
				dwError = GetLastError();
				goto Cleanup;
			}
		}
	}
	
	// CheckTokenMembership requires an impersonation token. If we just got a 
	// linked token, it already is an impersonation token.  If we did not get 
	// a linked token, duplicate the original into an impersonation token for 
	// CheckTokenMembership.
	if (!hTokenToCheck)
	{
		if (!DuplicateToken(hToken, SECURITY_IMPERSONATION_LEVEL.SecurityIdentification, &hTokenToCheck))
		{
			dwError = GetLastError();
			goto Cleanup;
		}
	}

	cbSize = adminSID.sizeof;
	if (!CreateWellKnownSid(WELL_KNOWN_SID_TYPE.WinBuiltinAdministratorsSid, NULL, &adminSID, &cbSize))
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
	// Check if the token to be checked contains admin SID.
	// http://msdn.microsoft.com/en-us/library/aa379596(VS.85).aspx:
	// To determine whether a SID is enabled in a token, that is, whether it 
	// has the SE_GROUP_ENABLED attribute, call CheckTokenMembership.
	if (!CheckTokenMembership(hTokenToCheck, &adminSID, &fInAdminGroup)) 
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
Cleanup:
	// Centralized cleanup for all allocated resources.
	if (hToken)
	{
		CloseHandle(hToken);
		hToken = NULL;
	}
	if (hTokenToCheck)
	{
		CloseHandle(hTokenToCheck);
		hTokenToCheck = NULL;
	}
	
	// Throw the error if something failed in the function.
	if (ERROR_SUCCESS != dwError)
	{
		throw new Exception(ReportError("IsUserInAdminGroup", dwError));
	}
	
	return fInAdminGroup;
}


// 
//   FUNCTION: IsRunAsAdmin()
//
//   PURPOSE: The function checks whether the current process is run as 
//   administrator. In other words, it dictates whether the primary access 
//   token of the process belongs to user account that is a member of the 
//   local Administrators group and it is elevated.
//
//   RETURN VALUE: Returns TRUE if the primary access token of the process 
//   belongs to user account that is a member of the local Administrators 
//   group and it is elevated. Returns FALSE if the token does not.
//
//   EXCEPTION: If this function fails, it throws a C++ DWORD exception which 
//   contains the Win32 error code of the failure.
//
//   EXAMPLE CALL:
//     try 
//     {
//         if (IsRunAsAdmin())
//             wprintf ("Process is run as administrator\n");
//         else
//             wprintf ("Process is not run as administrator\n");
//     }
//     catch (DWORD dwError)
//     {
//         wprintf("IsRunAsAdmin failed w/err %lu\n", dwError);
//     }
//
BOOL IsRunAsAdmin()
{
	BOOL fIsRunAsAdmin = FALSE;
	DWORD dwError = ERROR_SUCCESS;
	PSID pAdministratorsGroup = NULL;
	
	// Allocate and initialize a SID of the administrators group.
	SID_IDENTIFIER_AUTHORITY NtAuthority = SECURITY_NT_AUTHORITY;
	if (!AllocateAndInitializeSid(
			&NtAuthority, 
			2, 
			SECURITY_BUILTIN_DOMAIN_RID, 
			DOMAIN_ALIAS_RID_ADMINS, 
			0, 0, 0, 0, 0, 0, 
			&pAdministratorsGroup))
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
	// Determine whether the SID of administrators group is enabled in 
	// the primary access token of the process.
	if (!CheckTokenMembership(NULL, pAdministratorsGroup, &fIsRunAsAdmin))
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
Cleanup:
	// Centralized cleanup for all allocated resources.
	if (pAdministratorsGroup)
	{
		FreeSid(pAdministratorsGroup);
		pAdministratorsGroup = NULL;
	}
	
	// Throw the error if something failed in the function.
	if (ERROR_SUCCESS != dwError)
	{
		throw new Exception(ReportError("IsRunAsAdmin", dwError));
	}
	
	return fIsRunAsAdmin;
}


//
//   FUNCTION: IsProcessElevated()
//
//   PURPOSE: The function gets the elevation information of the current 
//   process. It dictates whether the process is elevated or not. Token 
//   elevation is only available on Windows Vista and newer operating 
//   systems, thus IsProcessElevated throws a C++ exception if it is called 
//   on systems prior to Windows Vista. It is not appropriate to use this 
//   function to determine whether a process is run as administartor.
//
//   RETURN VALUE: Returns TRUE if the process is elevated. Returns FALSE if 
//   it is not.
//
//   EXCEPTION: If this function fails, it throws a C++ DWORD exception 
//   which contains the Win32 error code of the failure. For example, if 
//   IsProcessElevated is called on systems prior to Windows Vista, the error 
//   code will be ERROR_INVALID_PARAMETER.
//
//   NOTE: TOKEN_INFORMATION_CLASS provides TokenElevationType to check the 
//   elevation type (TokenElevationTypeDefault / TokenElevationTypeLimited /
//   TokenElevationTypeFull) of the process. It is different from 
//   TokenElevation in that, when UAC is turned off, elevation type always 
//   returns TokenElevationTypeDefault even though the process is elevated 
//   (Integrity Level == High). In other words, it is not safe to say if the 
//   process is elevated based on elevation type. Instead, we should use 
//   TokenElevation.
//
//   EXAMPLE CALL:
//     try 
//     {
//         if (IsProcessElevated())
//             wprintf ("Process is elevated\n");
//         else
//             wprintf ("Process is not elevated\n");
//     }
//     catch (DWORD dwError)
//     {
//         wprintf("IsProcessElevated failed w/err %lu\n", dwError);
//     }
//
BOOL IsProcessElevated()
{
	BOOL fIsElevated = FALSE;
	DWORD dwError = ERROR_SUCCESS;
	HANDLE hToken = NULL;

	// Retrieve token elevation information.
	TOKEN_ELEVATION elevation;
	DWORD dwSize;

	// Open the primary access token of the process with TOKEN_QUERY.
	if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken))
	{
		dwError = GetLastError();
		goto Cleanup;
	}

	if (!GetTokenInformation(hToken, TOKEN_INFORMATION_CLASS.TokenElevation, &elevation, elevation.sizeof, &dwSize))
	{
		// When the process is run on operating systems prior to Windows 
		// Vista, GetTokenInformation returns FALSE with the 
		// ERROR_INVALID_PARAMETER error code because TokenElevation is 
		// not supported on those operating systems.
		dwError = GetLastError();
		goto Cleanup;
	}
	
	fIsElevated = elevation.TokenIsElevated;
	
Cleanup:
	// Centralized cleanup for all allocated resources.
	if (hToken)
	{
		CloseHandle(hToken);
		hToken = NULL;
	}
	
	// Throw the error if something failed in the function.
	if (ERROR_SUCCESS != dwError)
	{
		throw new Exception(ReportError("IsProcessElevated", dwError));
	}
	
	return fIsElevated;
}


//
//   FUNCTION: GetProcessIntegrityLevel()
//
//   PURPOSE: The function gets the integrity level of the current process. 
//   Integrity level is only available on Windows Vista and newer operating 
//   systems, thus GetProcessIntegrityLevel throws a C++ exception if it is 
//   called on systems prior to Windows Vista.
//
//   RETURN VALUE: Returns the integrity level of the current process. It is 
//   usually one of these values:
//
//     SECURITY_MANDATORY_UNTRUSTED_RID (SID: S-1-16-0x0)
//     Means untrusted level. It is used by processes started by the 
//     Anonymous group. Blocks most write access. 
//
//     SECURITY_MANDATORY_LOW_RID (SID: S-1-16-0x1000)
//     Means low integrity level. It is used by Protected Mode Internet 
//     Explorer. Blocks write acess to most objects (such as files and 
//     registry keys) on the system. 
//
//     SECURITY_MANDATORY_MEDIUM_RID (SID: S-1-16-0x2000)
//     Means medium integrity level. It is used by normal applications 
//     being launched while UAC is enabled. 
//
//     SECURITY_MANDATORY_HIGH_RID (SID: S-1-16-0x3000)
//     Means high integrity level. It is used by administrative applications 
//     launched through elevation when UAC is enabled, or normal 
//     applications if UAC is disabled and the user is an administrator. 
//
//     SECURITY_MANDATORY_SYSTEM_RID (SID: S-1-16-0x4000)
//     Means system integrity level. It is used by services and other 
//     system-level applications (such as Wininit, Winlogon, Smss, etc.)  
//
//   EXCEPTION: If this function fails, it throws a C++ DWORD exception 
//   which contains the Win32 error code of the failure. For example, if 
//   GetProcessIntegrityLevel is called on systems prior to Windows Vista, 
//   the error code will be ERROR_INVALID_PARAMETER.
//
//   EXAMPLE CALL:
//     try 
//     {
//         DWORD dwIntegrityLevel = GetProcessIntegrityLevel();
//     }
//     catch (DWORD dwError)
//     {
//         wprintf("GetProcessIntegrityLevel failed w/err %lu\n", dwError);
//     }
//
DWORD GetProcessIntegrityLevel()
{
	DWORD dwIntegrityLevel = 0;
	DWORD dwError = ERROR_SUCCESS;
	HANDLE hToken = NULL;
	DWORD cbTokenIL = 0;
	PTOKEN_MANDATORY_LABEL pTokenIL;
	
	// Open the primary access token of the process with TOKEN_QUERY.
	if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken))
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
	// Query the size of the token integrity level information. Note that 
	// we expect a FALSE result and the last error ERROR_INSUFFICIENT_BUFFER
	// from GetTokenInformation because we have given it a NULL buffer. On 
	// exit cbTokenIL will tell the size of the integrity level information.
	if (!GetTokenInformation(hToken, TOKEN_INFORMATION_CLASS.TokenIntegrityLevel, NULL, 0, &cbTokenIL))
	{
		if (ERROR_INSUFFICIENT_BUFFER != GetLastError())
		{
			// When the process is run on operating systems prior to Windows 
			// Vista, GetTokenInformation returns FALSE with the 
			// ERROR_INVALID_PARAMETER error code because TokenElevation 
			// is not supported on those operating systems.
			dwError = GetLastError();
			goto Cleanup;
		}
	}

	// Now we allocate a buffer for the integrity level information.
	pTokenIL = cast(PTOKEN_MANDATORY_LABEL) LocalAlloc(LPTR, cbTokenIL);
	if (pTokenIL == NULL)
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
	// Retrieve token integrity level information.
	if (!GetTokenInformation(hToken, TOKEN_INFORMATION_CLASS.TokenIntegrityLevel, pTokenIL, cbTokenIL, &cbTokenIL))
	{
		dwError = GetLastError();
		goto Cleanup;
	}
	
	// Integrity Level SIDs are in the form of S-1-16-0xXXXX. (e.g. 
	// S-1-16-0x1000 stands for low integrity level SID). There is one and 
	// only one subauthority.
	dwIntegrityLevel = *GetSidSubAuthority(pTokenIL.Label.Sid, 0);
	
Cleanup:
	// Centralized cleanup for all allocated resources.
	if (hToken)
	{
		CloseHandle(hToken);
		hToken = NULL;
	}
	if (pTokenIL)
	{
		LocalFree(pTokenIL);
		pTokenIL = null;
		cbTokenIL = 0;
	}
	
	// Throw the error if something failed in the function.
	if (ERROR_SUCCESS != dwError)
	{
		throw new Exception(ReportError("GetProcessIntegrityLevel", dwError));
	}
	
	return dwIntegrityLevel;
}



//
//   FUNCTION: ReportError(LPWSTR, DWORD)
//
//   PURPOSE: Display an error dialog for the failure of a certain function.
//
//   PARAMETERS:
//   * pszFunction - the name of the function that failed.
//   * dwError - the Win32 error code. Its default value is the calling 
//   thread's last-error code value.
//
//   NOTE: The failing function must be immediately followed by the call of 
//   ReportError if you do not explicitly specify the dwError parameter of 
//   ReportError. This is to ensure that the calling thread's last-error code 
//   value is not overwritten by any calls of API between the failing 
//   function and ReportError.
//
string ReportError(string fct, DWORD dwError = GetLastError())
{
	import std.conv : to;
	return fct ~ " failed with error: " ~ dwError.to!string;
}

/*
	// Whether the primary access token of the process 
	// belongs to user account that is a member of the local Administrators 
	// group even if it currently is not elevated (IsUserInAdminGroup).
	const BOOL fInAdminGroup = IsUserInAdminGroup();

	// Whether the process is run as administrator or not (IsRunAsAdmin).
	const BOOL fIsRunAsAdmin = IsRunAsAdmin();

	// The process elevation information (IsProcessElevated) 
	// and integrity level (GetProcessIntegrityLevel). The information is not 
	// available on operating systems prior to Windows Vista.
	OSVERSIONINFO osver = { osver.sizeof };
	if (GetVersionEx(&osver) && osver.dwMajorVersion >= 6)
	{
		// The process elevation information.
		const BOOL fIsElevated = IsProcessElevated();

		// Get and display the process integrity level.
		const DWORD dwIntegrityLevel = GetProcessIntegrityLevel();
		string integrity;
		switch (dwIntegrityLevel)
		{
			case SECURITY_MANDATORY_UNTRUSTED_RID: integrity = "Untrusted"; break;
			case SECURITY_MANDATORY_LOW_RID: integrity = "Low"; break;
			case SECURITY_MANDATORY_MEDIUM_RID: integrity = "Medium"; break;
			case SECURITY_MANDATORY_HIGH_RID: integrity = "High"; break;
			case SECURITY_MANDATORY_SYSTEM_RID: integrity = "System"; break;
			default: integrity = "Unknown"; break;
		}
	}
*/

inout(wchar)[] fromWStringz(inout(wchar)* cString) @nogc @system nothrow {
	import core.stdc.wctype : wcslen;
	return cString ? cString[0 .. wcslen(cString)] : null;
}
