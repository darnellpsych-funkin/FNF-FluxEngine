package flux.dave;

#if FLUX_DAVE
import backend.Song;
import backend.Song.SwagSong;
import backend.WeekData;
import haxe.Json;

using StringTools;

/**
 * Flux Engine: compatibilidad con mods de Dave Engine (VS Dave and Bambi Volume 1).
 *
 * Fase 1: canciones (data/songs/<id>/<id>-metadata.json y -chart.json, audio en songs/<id>/)
 * y una semana en Freeplay por mod con sus canciones. Cada variación de una canción
 * (<id>-chart-<variación>.json) es una dificultad más.
 */
class FluxDave
{
	static final DEFAULT_COLOR:Array<Int> = [15, 95, 255];

	/** Lo llama Song.getChart si no hay chart de Psych ni de V-Slice. Null si no es de Dave Engine. */
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;
		var id:String = Paths.formatToSongPath(folder);
		var input:String = Paths.formatToSongPath(jsonInput);
		if (!input.startsWith(id)) return null; // ej. "events"

		var postfix:String = input.substr(id.length);
		var diff:String = postfix.length == 0 ? '' : (postfix.charAt(0) == '-' ? postfix.substr(1) : null);
		if (diff == null) return null;

		var metaPath:String = findDataFile(id, 'metadata', '');
		if (metaPath == null) return null;
		try
		{
			var meta:Dynamic = Json.parse(File.getContent(metaPath));
			if (!DaveData.isSongMeta(meta)) return null;

			// la dificultad normal es la variación por defecto; las otras son variaciones
			var variation:String = (diff.length == 0 || diff == 'normal' || diff == Paths.formatToSongPath(Difficulty.getDefault())) ? '' : diff;
			var chartPath:String = findDataFile(id, 'chart', variation);
			if (chartPath == null && variation.length > 0)
			{
				variation = '';
				chartPath = findDataFile(id, 'chart', '');
			}
			if (chartPath == null) return null;
			if (variation.length > 0)
			{
				var variationMeta:String = findDataFile(id, 'metadata', variation);
				if (variationMeta != null) meta = Json.parse(File.getContent(variationMeta));
			}

			var chart:Dynamic = Json.parse(File.getContent(chartPath));
			if (!DaveData.isChart(chart)) return null;
			var json:Dynamic = DaveData.toPsychSong(meta, chart, id, Paths.formatToSongPath);
			var song:SwagSong = Song.parseJSON(Json.stringify(json), jsonInput);
			trace('[Flux Dave Engine] $chartPath');
			return song;
		}
		catch (e:Dynamic)
		{
			trace('[Flux Dave Engine] Error al cargar $id ($diff): $e');
			return null;
		}
	}

	/** Si la canción que se cargó es de Dave Engine (tiene su data/songs/<id>/<id>-metadata.json de Dave). */
	public static function isDaveSong(song:SwagSong):Bool
	{
		var name:String = Song.loadedSongName != null ? Song.loadedSongName : (song != null ? song.song : null);
		if (name == null || name.length == 0)
			return false;
		var path:String = findDataFile(Paths.formatToSongPath(name), 'metadata', '');
		if (path == null)
			return false;
		try
		{
			return DaveData.isSongMeta(Json.parse(File.getContent(path)));
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	/** data/songs/<id>/<id>-<kind>[-variación].json en el mod actual, los globales o mods/ */
	public static function findDataFile(id:String, kind:String, variation:String):String
	{
		var file:String = 'data/songs/$id/$id-$kind' + (variation != null && variation.length > 0 ? '-$variation' : '') + '.json';
		var path:String = Paths.modFolders(file);
		return (path != null && FileSystem.exists(path)) ? path : null;
	}

	/** Una semana de Freeplay por mod con sus canciones de Dave Engine (la llama WeekData.reloadWeekFiles). */
	public static function addWeeks(directories:Array<String>, originalLength:Int, isStoryMode:Null<Bool>)
	{
		if (isStoryMode == true) return; // por ahora solo en Freeplay
		for (i in 0...directories.length)
		{
			if (i < originalLength) continue; // solo carpetas de mods
			var directory:String = directories[i];
			var songsDir:String = directory + 'data/songs/';
			if (!FileSystem.exists(songsDir) || !FileSystem.isDirectory(songsDir)) continue;
			var modFolder:String = directory.substring(Paths.mods().length, directory.length - 1);

			var songs:Array<Dynamic> = [];
			var diffs:Array<String> = ['Normal'];
			var ids:Array<String> = FileSystem.readDirectory(songsDir);
			ids.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
			for (id in ids)
			{
				var meta:Dynamic = readJson('$songsDir$id/$id-metadata.json');
				if (!DaveData.isSongMeta(meta)) continue;

				var opponent:String = meta.opponent != null ? Std.string(meta.opponent) : 'face';
				var charData:Dynamic = readJson(directory + 'data/characters/$opponent.json');
				var icon:String = (charData != null && charData.icon != null) ? Std.string(charData.icon) : opponent;
				var color:Array<Int> = charData != null ? DaveData.rgb(charData.color) : null;
				songs.push(songEntry(id, icon, color != null ? color : DEFAULT_COLOR));

				// variaciones = dificultades extra
				for (file in FileSystem.readDirectory('$songsDir$id'))
				{
					var prefix:String = '$id-chart-';
					if (!file.startsWith(prefix) || !file.endsWith('.json')) continue;
					var variation:String = file.substring(prefix.length, file.length - 5);
					var name:String = variation.charAt(0).toUpperCase() + variation.substr(1);
					if (!diffs.contains(name)) diffs.push(name);
				}
			}
			if (songs.length == 0) continue;

			var weekName:String = 'dave_$modFolder';
			if (WeekData.weeksLoaded.exists(weekName)) continue;
			var weekFile:WeekFile = {
				songs: songs,
				weekCharacters: ['', 'bf', 'gf'],
				weekBackground: '',
				weekBefore: '',
				storyName: modFolder,
				weekName: '$modFolder (Dave Engine)',
				startUnlocked: true,
				hiddenUntilUnlocked: false,
				hideStoryMode: true,
				hideFreeplay: false,
				difficulties: diffs.join(', ')
			};
			var data:WeekData = new WeekData(weekFile, weekName);
			data.folder = modFolder;
			WeekData.weeksLoaded.set(weekName, data);
			WeekData.weeksList.push(weekName);
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
