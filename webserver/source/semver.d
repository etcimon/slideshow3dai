﻿/**
	Implementes version validation and comparison according to the semantic versioning specification.

	Copyright: © 2013 rejectedsoftware e.K.
	License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
	Authors: Sönke Ludwig
*/
module semver;

import std.range;
import std.string;
import std.algorithm : max;
import std.conv;

/*
	General format of SemVer: a.b.c[-x.y...][+x.y...]
	a/b/c must be integer numbers with no leading zeros
	x/y/... must be either numbers or identifiers containing only ASCII alphabetic characters or hyphens
*/

/**
	Validates a version string according to the SemVer specification.
*/
bool isValidVersion(string ver)
{
	// NOTE: this is not by spec, but to ensure sane input
	if (ver.length > 256)
		return false;

	// a
	auto sepi = ver.indexOf('.');
	if (sepi < 0)
		return false;
	if (!isValidNumber(ver[0 .. sepi]))
		return false;
	ver = ver[sepi + 1 .. $];

	// c
	sepi = ver.indexOf('.');
	if (sepi < 0)
		return false;
	if (!isValidNumber(ver[0 .. sepi]))
		return false;
	ver = ver[sepi + 1 .. $];

	// c
	sepi = ver.indexOfAny("-+");
	if (sepi < 0)
		sepi = ver.length;
	if (!isValidNumber(ver[0 .. sepi]))
		return false;
	ver = ver[sepi .. $];

	// prerelease tail
	if (ver.length > 0 && ver[0] == '-')
	{
		ver = ver[1 .. $];
		sepi = ver.indexOf('+');
		if (sepi < 0)
			sepi = ver.length;
		if (!isValidIdentifierChain(ver[0 .. sepi]))
			return false;
		ver = ver[sepi .. $];
	}

	// build tail
	if (ver.length > 0 && ver[0] == '+')
	{
		ver = ver[1 .. $];
		if (!isValidIdentifierChain(ver, true))
			return false;
		ver = null;
	}

	assert(ver.length == 0);
	return true;
}

unittest
{
	assert(isValidVersion("1.9.0"));
	assert(isValidVersion("0.10.0"));
	assert(!isValidVersion("01.9.0"));
	assert(!isValidVersion("1.09.0"));
	assert(!isValidVersion("1.9.00"));
	assert(isValidVersion("1.0.0-alpha"));
	assert(isValidVersion("1.0.0-alpha.1"));
	assert(isValidVersion("1.0.0-0.3.7"));
	assert(isValidVersion("1.0.0-x.7.z.92"));
	assert(isValidVersion("1.0.0-x.7-z.92"));
	assert(!isValidVersion("1.0.0-00.3.7"));
	assert(!isValidVersion("1.0.0-0.03.7"));
	assert(isValidVersion("1.0.0-alpha+001"));
	assert(isValidVersion("1.0.0+20130313144700"));
	assert(isValidVersion("1.0.0-beta+exp.sha.5114f85"));
	assert(!isValidVersion(" 1.0.0"));
	assert(!isValidVersion("1. 0.0"));
	assert(!isValidVersion("1.0 .0"));
	assert(!isValidVersion("1.0.0 "));
	assert(!isValidVersion("1.0.0-a_b"));
	assert(!isValidVersion("1.0.0+"));
	assert(!isValidVersion("1.0.0-"));
	assert(!isValidVersion("1.0.0-+a"));
	assert(!isValidVersion("1.0.0-a+"));
	assert(!isValidVersion("1.0"));
	assert(!isValidVersion("1.0-1.0"));
}

bool isPreReleaseVersion(string ver)
in
{
	assert(isValidVersion(ver));
}
body
{
	foreach (i; 0 .. 2)
	{
		auto di = ver.indexOf('.');
		assert(di > 0);
		ver = ver[di + 1 .. $];
	}
	auto di = ver.indexOf('-');
	if (di < 0)
		return false;
	return isValidNumber(ver[0 .. di]);
}

/**
	Compares the precedence of two SemVer version strings.

	The version strings must be validated using isValidVersion() before being
	passed to this function.
*/
int compareVersions(string a, string b)
{
	// compare a.b.c numerically
	if (auto ret = compareNumber(a, b))
		return ret;
	assert(a[0] == '.' && b[0] == '.');
	a.popFront();
	b.popFront();
	if (auto ret = compareNumber(a, b))
		return ret;
	assert(a[0] == '.' && b[0] == '.');
	a.popFront();
	b.popFront();
	if (auto ret = compareNumber(a, b))
		return ret;

	// give precedence to non-prerelease versions
	bool apre = a.length > 0 && a[0] == '-';
	bool bpre = b.length > 0 && b[0] == '-';
	if (apre != bpre)
		return bpre - apre;
	if (!apre)
		return 0;

	// compare the prerelease tail lexicographically
	do
	{
		a.popFront();
		b.popFront();
		if (auto ret = compareIdentifier(a, b))
			return ret;
	}
	while (a.length > 0 && b.length > 0 && a[0] != '+' && b[0] != '+');

	// give longer prerelease tails precedence
	bool aempty = a.length == 0 || a[0] == '+';
	bool bempty = b.length == 0 || b[0] == '+';
	if (aempty == bempty)
	{
		assert(aempty);
		return 0;
	}
	return bempty - aempty;
}

unittest
{
	void assertLess(string a, string b)
	{
		assert(compareVersions(a, b) < 0, "Failed for " ~ a ~ " < " ~ b);
		assert(compareVersions(b, a) > 0);
		assert(compareVersions(a, a) == 0);
		assert(compareVersions(b, b) == 0);
	}

	assertLess("1.0.0", "2.0.0");
	assertLess("2.0.0", "2.1.0");
	assertLess("2.1.0", "2.1.1");
	assertLess("1.0.0-alpha", "1.0.0");
	assertLess("1.0.0-alpha", "1.0.0-alpha.1");
	assertLess("1.0.0-alpha.1", "1.0.0-alpha.beta");
	assertLess("1.0.0-alpha.beta", "1.0.0-beta");
	assertLess("1.0.0-beta", "1.0.0-beta.2");
	assertLess("1.0.0-beta.2", "1.0.0-beta.11");
	assertLess("1.0.0-beta.11", "1.0.0-rc.1");
	assertLess("1.0.0-rc.1", "1.0.0");
	assert(compareVersions("1.0.0", "1.0.0+1.2.3") == 0);
	assert(compareVersions("1.0.0", "1.0.0+1.2.3-2") == 0);
	assert(compareVersions("1.0.0+asdasd", "1.0.0+1.2.3") == 0);
	assertLess("2.0.0", "10.0.0");
	assertLess("1.0.0-2", "1.0.0-10");
	assertLess("1.0.0-99", "1.0.0-1a");
	assertLess("1.0.0-99", "1.0.0-a");
	assertLess("1.0.0-alpha", "1.0.0-alphb");
	assertLess("1.0.0-alphz", "1.0.0-alphz0");
	assertLess("1.0.0-alphZ", "1.0.0-alpha");
}

/**
	Given version string, increments the next to last version number.
	Prerelease and build metadata information is ignored.
	@param ver Does not need to be a valid semver version.
	@return Valid semver version

	The semantics of this are the same as for the "approximate" version
	specifier from rubygems.
	(https://github.com/rubygems/rubygems/tree/81d806d818baeb5dcb6398ca631d772a003d078e/lib/rubygems/version.rb)

	Examples:
	  1.5 -> 2.0
	  1.5.67 -> 1.6.0
	  1.5.67-a -> 1.6.0
*/
string bumpVersion(string ver)
{
	// Cut off metadata and prerelease information.
	auto mi = ver.indexOfAny("+-");
	if (mi > 0)
		ver = ver[0 .. mi];
	// Increment next to last version from a[.b[.c]].
	auto splitted = split(ver, ".");
	assert(splitted.length > 0 && splitted.length <= 3, "Version corrupt: " ~ ver);
	auto to_inc = splitted.length == 3 ? 1 : 0;
	splitted = splitted[0 .. to_inc + 1];
	splitted[to_inc] = to!string(to!int(splitted[to_inc]) + 1);
	// Fill up to three compontents to make valid SemVer version.
	while (splitted.length < 3)
		splitted ~= "0";
	return splitted.join(".");
}

unittest
{
	assert("1.0.0" == bumpVersion("0"));
	assert("1.0.0" == bumpVersion("0.0"));
	assert("0.1.0" == bumpVersion("0.0.0"));
	assert("1.3.0" == bumpVersion("1.2.3"));
	assert("1.3.0" == bumpVersion("1.2.3+metadata"));
	assert("1.3.0" == bumpVersion("1.2.3-pre.release"));
	assert("1.3.0" == bumpVersion("1.2.3-pre.release+metadata"));
}

/**
	Takes a abbreviated version and expands it to a valid SemVer version.
	E.g. "1.0" -> "1.0.0"
*/
string expandVersion(string ver)
{
	auto mi = ver.indexOfAny("+-");
	auto sub = "";
	if (mi > 0)
	{
		sub = ver[mi .. $];
		ver = ver[0 .. mi];
	}
	auto splitted = split(ver, ".");
	assert(splitted.length > 0 && splitted.length <= 3, "Version corrupt: " ~ ver);
	while (splitted.length < 3)
		splitted ~= "0";
	return splitted.join(".") ~ sub;
}

unittest
{
	assert("1.0.0" == expandVersion("1"));
	assert("1.0.0" == expandVersion("1.0"));
	assert("1.0.0" == expandVersion("1.0.0"));
	// These are rather excotic variants...
	assert("1.0.0-pre.release" == expandVersion("1-pre.release"));
	assert("1.0.0+meta" == expandVersion("1+meta"));
	assert("1.0.0-pre.release+meta" == expandVersion("1-pre.release+meta"));
}

private int compareIdentifier(ref string a, ref string b)
{
	bool anumber = true;
	bool bnumber = true;
	bool aempty = true, bempty = true;
	int res = 0;
	while (true)
	{
		if (a.front != b.front && res == 0)
			res = a.front - b.front;
		if (anumber && (a.front < '0' || a.front > '9'))
			anumber = false;
		if (bnumber && (b.front < '0' || b.front > '9'))
			bnumber = false;
		a.popFront();
		b.popFront();
		aempty = a.empty || a.front == '.' || a.front == '+';
		bempty = b.empty || b.front == '.' || b.front == '+';
		if (aempty || bempty)
			break;
	}

	if (anumber && bnumber)
	{
		// the !empty value might be an indentifier instead of a number, but identifiers always have precedence
		if (aempty != bempty)
			return bempty - aempty;
		return res;
	}
	else
	{
		if (anumber && aempty)
			return -1;
		if (bnumber && bempty)
			return 1;
		// this assumption is necessary to correctly classify 111A > 11111 (ident always > number)!
		static assert('0' < 'a' && '0' < 'A');
		if (res != 0)
			return res;
		return bempty - aempty;
	}
}

private int compareNumber(ref string a, ref string b)
{
	int res = 0;
	while (true)
	{
		if (a.front != b.front && res == 0)
			res = a.front - b.front;
		a.popFront();
		b.popFront();
		auto aempty = a.empty || (a.front < '0' || a.front > '9');
		auto bempty = b.empty || (b.front < '0' || b.front > '9');
		if (aempty != bempty)
			return bempty - aempty;
		if (aempty)
			return res;
	}
}

private bool isValidIdentifierChain(string str, bool allow_leading_zeros = false)
{
	if (str.length == 0)
		return false;
	while (str.length)
	{
		auto end = str.indexOf('.');
		if (end < 0)
			end = str.length;
		if (!isValidIdentifier(str[0 .. end], allow_leading_zeros))
			return false;
		if (end < str.length)
			str = str[end + 1 .. $];
		else
			break;
	}
	return true;
}

private bool isValidIdentifier(string str, bool allow_leading_zeros = false)
{
	if (str.length < 1)
		return false;

	bool numeric = true;
	foreach (ch; str)
	{
		switch (ch)
		{
		default:
			return false;
		case 'a': .. case 'z':
		case 'A': .. case 'Z':
		case '-':
			numeric = false;
			break;
		case '0': .. case '9':
			break;
		}
	}

	if (!allow_leading_zeros && numeric && str[0] == '0' && str.length > 1)
		return false;

	return true;
}

private bool isValidNumber(string str)
{
	if (str.length < 1)
		return false;
	foreach (ch; str)
		if (ch < '0' || ch > '9')
			return false;

	// don't allow leading zeros
	if (str[0] == '0' && str.length > 1)
		return false;

	return true;
}

private sizediff_t indexOfAny(string str, in char[] chars)
{
	sizediff_t ret = -1;
	foreach (ch; chars)
	{
		auto idx = str.indexOf(ch);
		if (idx >= 0 && (ret < 0 || idx < ret))
			ret = idx;
	}
	return ret;
}
