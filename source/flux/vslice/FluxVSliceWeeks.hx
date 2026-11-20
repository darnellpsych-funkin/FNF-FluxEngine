package flux.vslice;

#if FLUX_VSLICE
import backend.WeekData;
import flux.vslice.FluxVSlice.VSliceSongRef;
import haxe.Json;

using StringTools;

/**
 * Compatibilidad con mods de V-Slice: las semanas (data/levels/*.json)
 * aparecen en Story Mode y Freeplay como semanas de Psych.
 *
 * - Las variaciones con dificultades nuevas (erect, nightmare) se suman a la
 *   canción normal.
 * - Las variaciones que repiten dificultades (Pico Mix, BF Mix...) van en una
 *   semana aparte que solo se ve en Freeplay.
 */
class FluxVSliceWeeks
{
	static final DIFFICULTY_ORDER:Array<String> = ['easy', 'normal', 'hard', 'erect', 'nightmare'];
	static final DEFAULT_COLOR:Array<Int> = [146, 113, 253];

	/** nombre de semana -> imagen del título en el Story Mode (titleAsset de V-Slice) */
	public static var titleAssets:Map<String, String> = new Map();

	public static function titleAssetFor(weekName:String):String
		return titleAssets.get(weekName);

	/**
	 * Llamado al final de WeekData.reloadWeekFiles().
	 * directories: las mismas carpetas que revisa Psych (mods/, assets/shared/, mods/<mod>/...)
	 */
	public static function addLevels(directories:Array<String>, originalLength:Int, isStoryMode:Null<Bool>)
	{
		for (i in 0...directories.length)
		{
			var directory:String = directories[i];
			if (i > 0 && i < originalLength) continue; // assets/shared no tiene mods de V-Slice
			var levelsDir:String = directory + 'data/levels/';
			if (!FileSystem.exists(levelsDir) || !FileSystem.isDirectory(levelsDir)) continue;

			var modFolder:String = '';
			#if MODS_ALLOWED
			if (i >= originalLength) modFolder = directory.substring(Paths.mods().length, directory.length - 1);
			#end

			var files:Array<String> = FileSystem.readDirectory(levelsDir);
			files.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
			for (file in files)
			{
				if (!file.endsWith('.json')) continue;
				try
				{
					addLevel(directory, modFolder, file.substr(0, file.length - 5), Json.parse(File.getContent(levelsDir + file)), isStoryMode);
				}
				catch (e:Dynamic)
				{
					trace('[Flux V-Slice] Error en el level $levelsDir$file: $e');
				}
			}
		}
	}

	static function addLevel(directory:String, modFolder:String, levelId:String, level:Dynamic, isStoryMode:Null<Bool>)
	{
		var songIds:Array<String> = level.songs;
		if (songIds == null || songIds.length == 0) return;

		var color:Array<Int> = colorFrom(level.background);
		var mainSongs:Array<Dynamic> = [];
		var mainDiffs:Array<String> = [];
		var extraSongs:Array<Dynamic> = []; // variaciones tipo Pico Mix
		var extraDiffs:Array<String> = [];

		for (songId in songIds)
		{
			var meta:Dynamic = readJson(directory + 'data/songs/$songId/$songId-metadata.json');
			if (meta == null) continue;

			var baseDiffs:Array<String> = meta.playData.difficulties != null ? meta.playData.difficulties : [];
			var variationsByDiff:Map<String, String> = new Map();
			for (diff in baseDiffs) variationsByDiff.set(diff, '');

			var variations:Array<String> = meta.playData.songVariations != null ? meta.playData.songVariations : [];
			for (variation in variations)
			{
				var vmeta:Dynamic = readJson(directory + 'data/songs/$songId/$songId-metadata-$variation.json');
				if (vmeta == null) continue;
				var vdiffs:Array<String> = vmeta.playData.difficulties != null ? vmeta.playData.difficulties : [];

				var collides:Bool = false;
				for (diff in vdiffs) if (variationsByDiff.exists(diff)) collides = true;

				if (!collides)
				{
					// erect / nightmare: misma canción, más dificultades
					for (diff in vdiffs) variationsByDiff.set(diff, variation);
				}
				else
				{
					// Pico Mix, BF Mix...: canción aparte en Freeplay
					var vname:String = vmeta.songName != null ? vmeta.songName : '${meta.songName} ($variation)';
					var vmap:Map<String, String> = new Map();
					for (diff in vdiffs) vmap.set(diff, variation);
					FluxVSlice.registerSong(vname, {id: songId, variations: vmap});
					extraSongs.push(songEntry(vname, iconFor(directory, vmeta), color));
					addDiffs(extraDiffs, vdiffs);
				}
			}

			var name:String = meta.songName != null ? meta.songName : songId;
			FluxVSlice.registerSong(name, {id: songId, variations: variationsByDiff});
			mainSongs.push(songEntry(name, iconFor(directory, meta), color));
			addDiffs(mainDiffs, [for (diff in variationsByDiff.keys()) diff]);
		}

		var levelName:String = level.name != null ? Std.string(level.name) : levelId;
		var hidden:Bool = level.visible == false;
		var prefix:String = 'vslice_' + (modFolder.length > 0 ? modFolder + '_' : '') + levelId;

		if (mainSongs.length > 0)
		{
			var weekFile:WeekFile = makeWeek(mainSongs, levelName, mainDiffs, hidden, false);
			if (pushWeek(prefix, weekFile, modFolder, isStoryMode) && level.titleAsset != null)
				titleAssets.set(prefix, Std.string(level.titleAsset));
		}
		if (extraSongs.length > 0)
			pushWeek(prefix + '_mixes', makeWeek(extraSongs, levelName + ' (Mixes)', extraDiffs, true, false), modFolder, isStoryMode);
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

	static function makeWeek(songs:Array<Dynamic>, name:String, diffs:Array<String>, hideStory:Bool, hideFreeplay:Bool):WeekFile
	{
		diffs.sort((a, b) -> orderOf(a) - orderOf(b));
		return {
			songs: songs,
			weekCharacters: ['', 'bf', 'gf'],
			weekBackground: '',
			weekBefore: '',
			storyName: name,
			weekName: name,
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: hideStory,
			hideFreeplay: hideFreeplay,
			difficulties: [for (diff in diffs) diff.charAt(0).toUpperCase() + diff.substr(1)].join(', ')
		};
	}

	static function pushWeek(weekName:String, weekFile:WeekFile, modFolder:String, isStoryMode:Null<Bool>):Bool
	{
		if (WeekData.weeksLoaded.exists(weekName)) return false;
		var week:WeekData = new WeekData(weekFile, weekName);
		week.folder = modFolder;
		if (isStoryMode == null || (isStoryMode && !week.hideStoryMode) || (!isStoryMode && !week.hideFreeplay))
		{
			WeekData.weeksLoaded.set(weekName, week);
			WeekData.weeksList.push(weekName);
			return true;
		}
		return false;
	}

	/** Ícono para Freeplay: el healthIcon del oponente en data/characters, o su id */
	static function iconFor(directory:String, meta:Dynamic):String
	{
		var chars:Dynamic = meta.playData != null ? meta.playData.characters : null;
		var opponent:String = chars != null && chars.opponent != null ? Std.string(chars.opponent) : 'face';
		var charData:Dynamic = readJson(directory + 'data/characters/$opponent.json');
		if (charData != null && charData.healthIcon != null && charData.healthIcon.id != null)
			return Std.string(charData.healthIcon.id);
		return opponent;
	}

	static function colorFrom(background:Dynamic):Array<Int>
	{
		if (background != null)
		{
			var text:String = Std.string(background).trim();
			if (text.startsWith('#') && text.length >= 7)
			{
				var value:Null<Int> = Std.parseInt('0x' + text.substr(1, 6));
				if (value != null) return [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
			}
		}
		return DEFAULT_COLOR.copy();
	}

	static function addDiffs(list:Array<String>, diffs:Array<String>)
	{
		for (diff in diffs)
			if (!list.contains(diff)) list.push(diff);
	}

	static function orderOf(diff:String):Int
	{
		var index:Int = DIFFICULTY_ORDER.indexOf(diff);
		return index >= 0 ? index : DIFFICULTY_ORDER.length;
	}

	static function readJson(path:String):Dynamic
	{
		if (!FileSystem.exists(path)) return null;
		try
		{
			return Json.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			trace('[Flux V-Slice] JSON inválido: $path');
			return null;
		}
	}
}
#end
