package flux.codename;

#if FLUX_CODENAME
import backend.WeekData;
import haxe.Json;

using StringTools;

/**
 * Semanas de mods de Codename Engine (data/weeks/weeks/*.xml, en el orden de
 * data/weeks/weeks.txt): aparecen en Story Mode y Freeplay como semanas de Psych.
 * El ícono y el color de cada canción salen de songs/<canción>/meta.json.
 */
class CodenameWeeks
{
	static final DEFAULT_COLOR:Array<Int> = [146, 113, 253];

	/** nombre de semana -> imagen del título en el Story Mode (menus/storymenu/weeks/<sprite>) */
	public static var titleAssets:Map<String, String> = new Map();

	public static function titleAssetFor(weekName:String):String
		return titleAssets.get(weekName);

	/** Llamado al final de WeekData.reloadWeekFiles() con las mismas carpetas que revisa Psych. */
	public static function addWeeks(directories:Array<String>, originalLength:Int, isStoryMode:Null<Bool>)
	{
		for (i in 0...directories.length)
		{
			if (i > 0 && i < originalLength) continue; // assets/shared no tiene mods de Codename
			var directory:String = directories[i];
			var weeksDir:String = directory + 'data/weeks/weeks/';
			if (!FileSystem.exists(weeksDir) || !FileSystem.isDirectory(weeksDir)) continue;

			var modFolder:String = '';
			#if MODS_ALLOWED
			if (i >= originalLength) modFolder = directory.substring(Paths.mods().length, directory.length - 1);
			#end

			for (id in weekOrder(directory, weeksDir))
			{
				try
				{
					var week:Dynamic = CodenameData.week(CodenameData.parse(File.getContent('$weeksDir$id.xml')), id);
					if (week != null) addWeek(directory, modFolder, id, week, isStoryMode);
				}
				catch (e:Dynamic)
				{
					trace('[Flux Codename] Error en la semana $weeksDir$id.xml: $e');
				}
			}
		}
	}

	/** Primero las de weeks.txt (las líneas con # son comentarios) y después el resto, por nombre. */
	static function weekOrder(directory:String, weeksDir:String):Array<String>
	{
		var order:Array<String> = [];
		var listPath:String = directory + 'data/weeks/weeks.txt';
		if (FileSystem.exists(listPath))
			for (line in File.getContent(listPath).split('\n'))
			{
				var id:String = line.trim();
				if (id.length == 0 || id.startsWith('#') || order.contains(id)) continue;
				if (FileSystem.exists('$weeksDir$id.xml')) order.push(id);
			}
		var files:Array<String> = FileSystem.readDirectory(weeksDir);
		files.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		for (file in files)
		{
			if (!file.toLowerCase().endsWith('.xml')) continue;
			var id:String = file.substr(0, file.length - 4);
			if (!order.contains(id)) order.push(id);
		}
		return order;
	}

	static function addWeek(directory:String, modFolder:String, id:String, week:Dynamic, isStoryMode:Null<Bool>)
	{
		var songs:Array<Dynamic> = [];
		for (song in (week.songs : Array<Dynamic>))
		{
			if (song.hide == true) continue;
			var name:String = song.name;
			var meta:Dynamic = readJson(directory + 'songs/${name.toLowerCase()}/meta.json');
			if (meta == null) meta = readJson(directory + 'songs/${Paths.formatToSongPath(name)}/meta.json');
			var icon:String = (meta != null && meta.icon != null) ? Std.string(meta.icon) : 'face';
			var color:Array<Int> = meta != null ? CodenameData.rgb(meta.color != null ? Std.string(meta.color) : null) : null;
			songs.push(songEntry(name, icon, color != null ? color : DEFAULT_COLOR));
		}
		if (songs.length == 0) return;

		var chars:Array<String> = week.chars;
		var menuChars:Array<String> = [];
		for (n in 0...3)
		{
			var c:String = n < chars.length ? chars[n] : '';
			// los personajes del menú de Codename son XML; si no hay uno de Psych con ese nombre, el de siempre
			if (c.length > 0 && !Paths.fileExists('images/menucharacters/$c.json', TEXT))
				c = switch (n) { case 1: 'bf'; case 2: 'gf'; default: ''; }
			menuChars.push(c);
		}

		var diffs:Array<String> = week.difficulties;
		// sin la imagen del título no se puede mostrar en el Story Mode: solo en Freeplay
		var title:String = 'menus/storymenu/weeks/${week.sprite}';
		var hasTitle:Bool = FileSystem.exists(directory + 'images/$title.png');
		var weekFile:WeekFile = {
			songs: songs,
			weekCharacters: menuChars,
			weekBackground: '',
			weekBefore: '',
			storyName: week.name,
			weekName: week.name,
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: !hasTitle,
			hideFreeplay: false,
			difficulties: [for (d in diffs) d.charAt(0).toUpperCase() + d.substr(1)].join(', ')
		};

		var weekName:String = 'codename_' + (modFolder.length > 0 ? modFolder + '_' : '') + id;
		if (WeekData.weeksLoaded.exists(weekName)) return;
		var data:WeekData = new WeekData(weekFile, weekName);
		data.folder = modFolder;
		if (isStoryMode == null || (isStoryMode && !data.hideStoryMode) || (!isStoryMode && !data.hideFreeplay))
		{
			WeekData.weeksLoaded.set(weekName, data);
			WeekData.weeksList.push(weekName);
			if (hasTitle) titleAssets.set(weekName, title);
		}
	}

	/** [nombre, ícono, [r, g, b]] armado con push() (en C++ un literal mezclado puede perder el color) */
	static function songEntry(name:String, icon:String, color:Array<Int>):Array<Dynamic>
	{
		var rgb:Array<Dynamic> = [];
		for (c in color) rgb.push(c);
		var entry:Array<Dynamic> = [];
		entry.push(name);
		entry.push(icon);
		entry.push(rgb);
		return entry;
	}

	static function readJson(path:String):Dynamic
	{
		if (path == null || !FileSystem.exists(path)) return null;
		try
		{
			return Json.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
}
#end
