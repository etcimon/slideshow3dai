module winmultiling;

version(Windows):
private import core.sys.windows.winnls : GetUserDefaultLangID;
private import core.sys.windows.winnt;
struct MultilingualDict {
	import std.utf : toUTF16z;
	@property static:

	private string locale() {

		static string locale_val;
		
		if (locale_val.length == 0) 
			locale_val = localeImpl();
		return locale_val;

	}

	private string localeImpl() {

		LANGID id = GetUserDefaultLangID();
		LANGID primary = (id & 0xFF);
		switch (primary) {
			default: return "en";
			case LANG_ENGLISH:
				return "en";
			case LANG_AFRIKAANS:
				return "af";
			case LANG_ALBANIAN:
				return "sq";
			case LANG_ALSATIAN:
				return "gsw";
			case LANG_AMHARIC:
				return "am";
			case LANG_ARABIC:
				return "ar";
			case LANG_ARMENIAN:
				return "hy";
			case LANG_ASSAMESE:
				return "as";
			case LANG_AZERI:
				return "az";	
			//case LANG_BANGLA:
			//	return "bn";	
			case LANG_BASHKIR:
				return "ba";
			case LANG_BASQUE:
				return "eu";
			case LANG_BELARUSIAN:
				return "be";
			case LANG_BOSNIAN_NEUTRAL:
				return "bs";
			case LANG_BOSNIAN:
				return "bs";
			case LANG_BRETON:
				return "br";
			case LANG_BULGARIAN:
				return "bg";
			//case LANG_CENTRAL_KURDISH:
			//	return "ku";
			//case LANG_CHEROKEE:
			//	return "chr";
			case LANG_CATALAN:
				return "ca";
			case LANG_CHINESE:
				return "zh";	
			//case LANG_CHINESE_SIMPLIFIED:
			//	return "zh";
			//case LANG_CHINESE_TRADITIONAL:
			//	return "zh";
			case LANG_CORSICAN:
				return "co";
			//case LANG_CROATIAN:
			//	return "hr";
			//case LANG_CROATIAN:
			//	return "hr";	
			case LANG_CZECH:
				return "cs";
			case LANG_DANISH:
				return "da";
			case LANG_DARI:
				return "prs";
			case LANG_DIVEHI:
				return "dv";
			case LANG_DUTCH:
				return "nl";	
			//case LANG_ENGLISH:
			//	return "en";	
			case LANG_ESTONIAN:
				return "et";
			case LANG_FAEROESE:
				return "fo";
			case LANG_FILIPINO:
				return "fil";
			case LANG_FINNISH:
				return "fi";
			case LANG_FRENCH:
				return "fr";	
			case LANG_FRISIAN:
				return "fy";
			case LANG_GALICIAN:
				return "gl";
			case LANG_GEORGIAN:
				return "ka";
			case LANG_GERMAN:
				return "de";	
			case LANG_GREEK:
				return "el";
			case LANG_GREENLANDIC:
				return "kl";
			case LANG_GUJARATI:
				return "gu";
			case LANG_HAUSA:
				return "ha";
			//case LANG_HAWAIIAN:
			//	return "haw";
			case LANG_HEBREW:
				return "he";
			case LANG_HINDI:
				return "hi";
			case LANG_HUNGARIAN:
				return "hu";
			case LANG_ICELANDIC:
				return "is";
			case LANG_IGBO:
				return "ig";
			case LANG_INDONESIAN:
				return "id";
			case LANG_INUKTITUT:
				return "iu";	
			case LANG_IRISH:
				return "ga";
			case LANG_XHOSA:
				return "xh";
			case LANG_ZULU:
				return "zu";
			case LANG_ITALIAN:
				return "it";	
			case LANG_JAPANESE:
				return "ja";
			case LANG_KANNADA:
				return "kn";	
			case LANG_KAZAK:
				return "kk";
			case LANG_KHMER:
				return "kh";
			case LANG_KINYARWANDA:
				return "rw";
			case LANG_KONKANI:
				return "kok";
			case LANG_KOREAN:
				return "ko";
			case LANG_KYRGYZ:
				return "ky";
			case LANG_LAO:
				return "lo";
			case LANG_LATVIAN:
				return "lv";
			case LANG_LITHUANIAN:
				return "lt";
			case LANG_LOWER_SORBIAN:
				return "dsb";
			case LANG_LUXEMBOURGISH:
				return "lb";
			case LANG_MACEDONIAN:
				return "mk";
			case LANG_MALAY:
				return "ms";	
			case LANG_MALAYALAM:
				return "ml";
			case LANG_MALTESE:
				return "mt";
			case LANG_MAORI:
				return "mi";
			case LANG_MAPUDUNGUN:
				return "arn";
			case LANG_MARATHI:
				return "mr";
			case LANG_MOHAWK:
				return "moh";
			case LANG_MONGOLIAN:
				return "mn";	
			case LANG_NEPALI:
				return "ne";	
			case LANG_NORWEGIAN:
				return "no";	
			case LANG_OCCITAN:
				return "oc";
			case LANG_ORIYA:
				return "or";
			case LANG_PASHTO:
				return "ps";
			case LANG_PERSIAN:
				return "fa";
			case LANG_POLISH:
				return "pl";
			case LANG_PORTUGUESE:
				return "pt";
			//case LANG_PULAR:
			//	return "ff";
			case LANG_PUNJABI:
				return "pa";
			case LANG_QUECHUA:
				return "quz";	
			case LANG_ROMANIAN:
				return "ro";
			//case LANG_ROMANSH:
			//	return "rm";
			case LANG_RUSSIAN:
				return "ru";
			//case LANG_SAKHA:
			//	return "sah";
			case LANG_SAMI:
				return "smn";
			case LANG_SANSKRIT:
				return "sa";
			//case LANG_SERBIAN:
			//case LANG_SERBIAN_NEUTRAL:
			//	return "sr";
			case LANG_SOTHO:
				return "nso";
			case LANG_TSWANA:
				return "tn";
			case LANG_SINHALESE:
				return "si";	
			case LANG_SLOVAK:
				return "sk";
			case LANG_SLOVENIAN:
				return "sl";
			case LANG_SPANISH:
				return "es";
			case LANG_SWAHILI:
				return "sw";
			case LANG_SWEDISH:
				return "sv";
			case LANG_SYRIAC:
				return "syr";
			//case LANG_TAJIK:
			//	return "tg";
			case LANG_TAMAZIGHT:
				return "tzm";
			case LANG_TAMIL:
				return "ta";	
			case LANG_TATAR:
				return "tt";
			case LANG_TELUGU:
				return "te";
			case LANG_THAI:
				return "th";
			case LANG_TIBETAN:
				return "bo";
			//case LANG_TIGRINYA:
			//	return "ti";
			case LANG_TURKISH:
				return "tr";
			//case LANG_TURKMEN:
			//	return "tk";
			case LANG_UKRAINIAN:
				return "uk";
			//case LANG_UPPER_SORBIAN:
			//	return "hsb";
			case LANG_URDU:
				return "ur";	
			case LANG_UIGHUR:
				return "ug";
			case LANG_UZBEK:
				return "uz";	
			//case LANG_VALENCIAN:
			//	return "ca";
			case LANG_VIETNAMESE:
				return "vi";
			case LANG_WELSH:
				return "cy";
			case LANG_WOLOF:
				return "wo";
			case LANG_YI:
				return "ii";
			case LANG_YORUBA:
				return "yo";
				
		}
	}

	string serviceName() {
		switch (locale) {
			case "el":
				return "Παράθυρα Συνδεσιμότητα για Cimons.";
			case "sv":
				return "Windows Anslutningar för Cimons.";
			case "nl":
				return "Windows Connectiviteit voor Cimons.";
			case "ko":
				return "Cimons 용 Windows 연결.";
			case "ja":
				return "CimonsのWindowsの接続。";
			case "sh":
				return "Windows互连接口的Cimons。";
			case "it":
				return "Finestre connettività per Cimons.";
			case "ar":
				return "الربط النوافذ لCimons.";
			case "de":
				return "Windows-Connectivity für Cimons.";
			case "id":
				return "Jendela Konektivitas untuk Cimons.";
			case "tr":
				return "Cimons için, Windows Bağlantı.";
			case "ru":
				return "Windows подключения для Cimons.";
			case "pt":
				return "Conectividade do Windows para Cimons.";
			case "es":
				return "Windows Conectividad Cimons.";
			case "fr":
				return "Connectivité Windows pour Cimons.";
			case "en":
			default:
				return "Windows Connectivity Manager for Cimons";
		}
	}

	string serviceDescription() {
		switch (locale) {
			case "el":
				return "Παρέχει εκδήλωση με βάση τις δυνατότητες δικτύωσης με τον πυρήνα του κινητήρα και δίνει στις εφαρμογές client τα μέσα για να επικοινωνούν με Cimons.";
			case "sv":
				return "Ger händelsebaserade nätverksfunktioner till kärnmotorn och ger till klientprogram möjlighet att kommunicera med Cimons.";
			case "nl":
				return "Biedt event-based netwerkmogelijkheden tot de kern motor en geeft aan client applicaties van de middelen om te communiceren met Cimons.";
			case "ko":
				return "핵심 엔진에 이벤트 기반 네트워킹 기능을 제공하고 Cimons와 통신 할 수있는 수단은 클라이언트 응용 프로그램에 제공합니다.";
			case "ja":
				return "コアエンジンにイベントベースのネットワーキング機能を提供し、Cimonsと通信するための手段は、クライアントアプリケーションに提供します。";
			case "zh":
				return "提供基于事件的联网能力的核心发动机，并给出到客户端应用程序与Cimons进行通信的装置。";
			case "it":
				return "Fornisce funzionalità di rete basate su eventi a motore centrale e dà alle applicazioni client i mezzi per comunicare con Cimons.";
			case "ar":
				return "يوفر قدرات الربط الشبكي القائم على الحدث إلى المحرك الأساسي ويعطي لتطبيقات العميل وسائل التواصل مع Cimons.";
			case "de":
				return "Bietet ereignisbasierte Netzwerkfunktionen, um das Kerntriebwerk und gibt Client-Anwendungen die Mittel, um mit Cimons kommunizieren.";
			case "id":
				return "Menyediakan berdasarkan event-kemampuan jaringan untuk mesin inti dan memberikan aplikasi client sarana untuk berkomunikasi dengan Cimons.";
			case "tr":
				return "Çekirdek motora olay tabanlı ağ yetenekleri sağlar ve Cimons ile iletişim kurmak için araçlar istemci uygulamaları verir.";
			case "ru":
				return "Обеспечивает на основе событий сетевые возможности в основной двигатель и дает клиентских приложений средства общения с Cimons.";
			case "pt":
				return "Fornece recursos de rede com base em eventos para o mecanismo de núcleo e dá para aplicativos do cliente os meios para se comunicar com Cimons.";
			case "es":
				return "Proporciona capacidades de red basadas en eventos en el motor central y da a las aplicaciones cliente los medios para comunicarse con Cimons.";
			case "fr":
				return "Fournit des capacités réseau en fonction de l'événement pour le moteur de base et donne aux applications clientes les moyens de communiquer avec Cimons.";
			case "en":
			default:
				return "Provides event-based networking capabilities to the core engine and gives client applications to ability to communicate with Cimons";
		}
	}

	string pin() {
		switch (locale) {
			case "el":
				return "Καρφίτσωμα στη γραμμή εργασιών";
			case "sv":
				return "Fäst i Aktivitetsfältet";
			case "nl":
				return "Aan de taakbalk vastmaken";
			case "ko":
				return "작업 표시줄에 고정";
			case "ja":
				return "タスク バーに表示する";
			case "zh":
				return "釘選到工作列";
			case "it":
				return "Aggiungi alla barra delle applicazioni";
			case "ar":
				return "التثبيت على شريط";
			case "de":
				return "An Taskleiste anheften";
			//case "id":
			//	return "Menyediakan berdasarkan event-kemampuan jaringan untuk mesin inti dan memberikan aplikasi client sarana untuk berkomunikasi dengan Cimons.";
			case "tr":
				return "Görev çubuğuna sabitle";
			case "ru":
				return "Закрепить на панели задач";
			case "pt":
				return "Fixar na Barra de Tarefas";
			case "es":
				return "Anclar a la barra de tareas";
			case "fr":
				return "Épingler à la barre des tâches";
			case "en":
			default:
				return "Pin to Taskbar";
		}
	}

	string unpin() {
		switch (locale) {
			case "el":
				return "Ξεκαρφίτσωμα";
			case "sv":
				return "Ta bort";
			case "nl":
				return "losmaken";
			case "ko":
				return "제거를";
			case "ja":
				return "を表示しない";
			case "zh":
				return "取消";
			case "it":
				return "Rimuovi";
			case "ar":
				return "إزالة";
			case "de":
				return "lösen";
			//case "id":
			//	return "";
			case "tr":
				return "ayır";
			case "ru":
				return "Изъять";
			case "pt":
				return "Desafixar";
			case "es":
				return "Desanclar";
			case "fr":
				return "Détacher";
			case "en":
			default:
				return "Unpin";
		}
	}
}