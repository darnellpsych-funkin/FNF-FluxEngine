package flux.dave.api;

#if FLUX_DAVE_SCRIPTS
import backend.ClientPrefs;
import backend.Paths;
import flux.vslice.modules.FluxVSliceModules;

using StringTools;

/**
 * LanguageManager de Dave Engine: los textos de `locale/<idioma>/textList.txt` (y
 * dialogue.txt, subtitles.txt, credits.txt), con líneas `clave==texto`.
 *
 * Como Polymod, junta los de todos los mods activos y les suma los `_append/locale/...`
 * de cada mod (así un mod de fans agrega sus créditos a los de VsDnB). El idioma es el de
 * Psych (es-ES usa es-US si el mod no tiene es-ES), y lo que falta sale del inglés (en-US).
 */
@:keep
class DaveLanguageManager
{
	public static var currentLocaleList(get, never):Map<String, String>;
	public static var currentDialogueList(get, never):Map<String, String>;
	public static var currentSubtitlesList(get, never):Map<String, String>;
	public static var currentCreditsList(get, never):Map<String, String>;

	/** El idioma de Dave que se está usando ('en-US', 'es-US', 'pt-br'...). */
	public static var language(get, never):String;

	static var lists:Map<String, Map<String, String>> = new Map<String, Map<String, String>>();
	static var loadedKey:String = null;
	static var loadedLanguage:String = 'en-US';

	static function get_currentLocaleList():Map<String, String>
		return list('textList');

	static function get_currentDialogueList():Map<String, String>
		return list('dialogue');

	static function get_currentSubtitlesList():Map<String, String>
		return list('subtitles');

	static function get_currentCreditsList():Map<String, String>
		return list('credits');

	static function get_language():String
	{
		check();
		return loadedLanguage;
	}

	/** El texto de una clave (o la clave misma si no está), con :linebreak: y :addquote:. */
	public static function getTextString(id:String, ?list:Map<String, String>):String
	{
		var use:Map<String, String> = list != null ? list : get_currentLocaleList();
		if (id == null || use == null || !use.exists(id))
			return id;
		return use.get(id).replace(':linebreak:', '\n').replace(':addquote:', '"');
	}

	/** Vuelve a leer los archivos la próxima vez (cambiaron los mods o el idioma). */
	public static function reload():Void
	{
		loadedKey = null;
		lists = new Map<String, Map<String, String>>();
	}

	static function list(file:String):Map<String, String>
	{
		check();
		var found:Map<String, String> = lists.get(file);
		if (found == null)
		{
			found = new Map<String, String>();
			// primero el inglés: lo que el idioma elegido no tenga queda en inglés
			if (loadedLanguage != 'en-US')
				readInto(found, 'en-US', file);
			readInto(found, loadedLanguage, file);
			lists.set(file, found);
		}
		return found;
	}

	static function check():Void
	{
		var mods:Array<String> = FluxVSliceModules.enabledMods;
		var key:String = psychLanguage() + '|' + mods.join('|');
		if (key == loadedKey)
			return;
		loadedKey = key;
		lists = new Map<String, Map<String, String>>();
		loadedLanguage = localeFor(psychLanguage(), locales());
	}

	static function psychLanguage():String
	{
		#if TRANSLATIONS_ALLOWED
		var lang:String = ClientPrefs.data.language;
		return (lang != null && lang.length > 0) ? lang : 'en-US';
		#else
		return 'en-US';
		#end
	}

	/** El idioma de Dave para uno de Psych: el mismo, o el mismo idioma de otro país, o en-US. */
	public static function localeFor(wanted:String, available:Array<String>):String
	{
		if (wanted == null || available == null || available.length == 0)
			return 'en-US';
		var lower:String = wanted.toLowerCase().replace('_', '-');
		for (locale in available)
			if (locale.toLowerCase() == lower)
				return locale;
		var prefix:String = lower.split('-')[0];
		for (locale in available)
			if (locale.toLowerCase().split('-')[0] == prefix)
				return locale;
		return 'en-US';
	}

	/** Las carpetas de idioma que tienen los mods activos (locale/ y _append/locale/). */
	public static function locales():Array<String>
	{
		var found:Array<String> = [];
		#if (MODS_ALLOWED && sys)
		for (mod in FluxVSliceModules.enabledMods)
			for (folder in ['locale', '_append/locale'])
			{
				var dir:String = Paths.mods('$mod/$folder');
				if (!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir))
					continue;
				for (entry in sys.FileSystem.readDirectory(dir))
					if (sys.FileSystem.isDirectory('$dir/$entry') && !found.contains(entry))
						found.push(entry);
			}
		#end
		return found;
	}

	/** locale/<idioma>/<archivo>.txt de cada mod activo y después sus _append. */
	static function readInto(target:Map<String, String>, locale:String, file:String):Void
	{
		#if (MODS_ALLOWED && sys)
		var mods:Array<String> = FluxVSliceModules.enabledMods;
		for (folder in ['locale', '_append/locale'])
			for (mod in mods)
			{
				var path:String = Paths.mods('$mod/$folder/$locale/$file.txt');
				if (sys.FileSystem.exists(path))
					parse(sys.io.File.getContent(path), target);
			}
		#end
	}

	/** Las líneas `clave==texto` (las que no tienen `==`, como los comentarios, no cuentan). */
	public static function parse(text:String, target:Map<String, String>):Void
	{
		if (text == null)
			return;
		for (raw in text.replace('\r', '').split('\n'))
		{
			var line:String = raw.trim();
			var cut:Int = line.indexOf('==');
			if (cut <= 0)
				continue;
			target.set(line.substr(0, cut).trim(), line.substr(cut + 2));
		}
	}
}
#end
