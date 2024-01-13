module geoip;

import maxmind.db;
import maxmind.data;
import std.typecons;

Database g_maxdb;

void resolveIP(string ip_address, out string country_code, out double longitude, out double latitude)
{
	if (!g_maxdb)
		g_maxdb = new Database("GeoLite2-City.mmdb");
	auto db = g_maxdb;
	auto res = db.lookup(ip_address);
	if (res !is null) {
		if (auto country = res.country)
			country_code = res.country.iso_code.get!string;
		else country_code = "US";
		if (auto location = res.location) {
			longitude = res.location.longitude.get!double;
			latitude = res.location.latitude.get!double;
		} else {
			longitude = 40.0;
			latitude = -70.0;
		}
	}
}
