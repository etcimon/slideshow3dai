module helpers;

public import vibe.db.pgsql.pgsql;
public import std.conv;
public import vibe.data.json;
public import vibe.http.server;
public import vibe.core.core;
public import vibe.core.log : logDebug, logError;
public import std.typecons : scoped;
public import memutils.unique;
public import vibe.stream.botan;
public import vibe.stream.tls;
public import vibe.stream.operations;
public import vibe.web.web;
public import vibe.db.redis.redis;
public import vibe.core.concurrency;
public import vibe.mail.smtp;
public import botan.passhash.bcrypt;
public import botan.rng.auto_rng;
public import std.datetime;

public import std.string : indexOf;
public import jobs;
public import events;
public import geoip;

private PostgresDB g_pgdb;
private RedisClient g_redisClient;

SMTPClientSettings mailer;

auto connectDB() {
	if (!g_pgdb) {
		import std.random : uniform;
		version(Windows) {
			auto params = [
				"host" : "127.0.0.1",
				"database" : "cimons",
				"user": "root",
				"statement_timeout": "90000"
			];

		}
		else {
			auto params = [
				"host" : "/tmp/.s.PGSQL.5432",
				"database" : "cimons",
				"user": "root",
				"statement_timeout": "90000"
			];
		}
		g_pgdb = new PostgresDB(params);
		g_pgdb.maxConcurrency = 10;
		//auto pgconn = g_pgdb.lockConnection();
		//auto upd = scoped!PGCommand(pgconn, "SET statement_timeout = 90000");
		//upd.executeNonQuery();
	}
	
	return g_pgdb.lockConnection();
}

RedisDatabase connectCache() {
	if (!g_redisClient)
	{
		version(Windows) {
			g_redisClient = connectRedis("127.0.0.1:6379");
		} else {
			g_redisClient = connectRedis("/tmp/redis.sock");
		}
	}	
	return g_redisClient.getDatabase(0);
}

/// Removes the port number from an IP string, if applicable
string toIPAddress(string peer)
{
	import std.string : lastIndexOf;
	if (peer.length == 0) return "";
	size_t idx = peer.lastIndexOf(':');
	if (idx == -1) idx = peer.length;
	return peer[0 .. idx];
}

string afterColon(string msg)
{
	import std.string : lastIndexOf;
	auto idx = msg.lastIndexOf(':');
	if (idx == -1) return msg;
	if (idx >= msg.length - 2) return "";
	return msg[idx+1 .. $];
}

enum Transaction = `try {
				auto begin = scoped!PGCommand(pgconn, "BEGIN");
				begin.executeNonQuery();
			} catch (Exception e) {
				{
					auto rb = scoped!PGCommand(pgconn, "ROLLBACK");
					rb.executeNonQuery();
				}
				{
					auto begin = scoped!PGCommand(pgconn, "BEGIN");
					begin.executeNonQuery();
				}
			}
			scope(failure) {
				auto rollback = scoped!PGCommand(pgconn, "ROLLBACK");
				rollback.executeNonQuery();
			}
			scope(success) {
				auto commit = scoped!PGCommand(pgconn, "COMMIT");
				commit.executeNonQuery();
			}
`;