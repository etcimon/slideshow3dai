﻿module mail;
import vibe.mail.smtp;
import std.datetime;

version (Posix) alias getTimeZone = PosixTimeZone.getTimeZone;
else version (Windows) alias getTimeZone = WindowsTimeZone.getTimeZone;

void sendEmail(SMTPClientSettings settings, string email, string message, string title = "Cimons Secret Token", bool has_html = false){
	import vibe.inet.message;
	import std.typecons : scoped;
	import vibe.stream.operations : readAll;
	auto mailer = scoped!Mail;
	mailer.headers["To"] = email;
	mailer.headers["Date"] = Clock.currTime(getTimeZone("America/New_York")).toRFC822DateTimeString();
	mailer.headers["From"] = "Cimons <info@cimons.com>";
	mailer.headers["Sender"] = "Cimons <info@cimons.com>";
	mailer.headers["Subject"] = title;
	mailer.headers["Content-Type"] = has_html?"text/html":"text/plain";

	mailer.bodyText = message;
	
	sendMail(settings, mailer);
}