package flux.moonchart;

#if MOONCHART_ALLOWED
import backend.Song;
import backend.WeekData;
import haxe.Json;
import haxe.io.Path;
import moonchart.formats.BasicFormat.DynamicFormat;
import moonchart.formats.OsuMania;
import moonchart.formats.Quaver;
import moonchart.formats.StepMania;
import moonchart.formats.StepManiaShark;
import moonchart.formats.fnf.FNFCodename;
import moonchart.formats.fnf.legacy.FNFPsych;
import moonchart.parsers.StepManiaParser;
import moonchart.parsers.StepManiaSharkParser;
import openfl.media.Sound;

using StringTools;

/** Un chart que Moonchart puede leer, con sus dificultades */
typedef MoonchartFile =
{
	var kind:String;                  // osu, quaver, stepmania, codename
	var path:String;                  // el archivo del chart
	var diffs:Array<String>;          // las dificultades que trae
	@:optional var meta:String;       // meta.json (Codename)
	@:optional var audio:String;      // el audio que pide el chart
	@:optional var error:String;      // por qué no se puede jugar (por ejemplo, 7 teclas)
	@:optional var format:DynamicFormat; // ya leído (StepMania)
}

/** Dónde está el audio de una canción cargada con Moonchart */
typedef MoonchartAudio =
{
	var folder:String;            // carpeta con Inst.ogg y Voices.ogg
	@:optional var inst:String;   // el audio que pide el chart (osu!mania, Quaver, StepMania)
}

/**
 * Charts de otros juegos y engines con Moonchart 0.5.1 (MaybeMaru, licencia MIT,
 * incluido en source/flux/vendor/moonchart).
 *
 * Si una canción no tiene chart de Psych (ni de V-Slice), Song.getChart() llama
 * a FluxMoonchart.getChart(), que busca en data/<canción>/ y songs/<canción>/:
 *   - osu!mania (.osu, solo 4 teclas), una dificultad por archivo (Version)
 *   - Quaver (.qua, solo 4 teclas), una dificultad por archivo (DifficultyName)
 *   - StepMania (.sm) y StepMania 5 (.ssc), solo los charts dance-single
 *   - Codename Engine: charts/<dificultad>.json + meta.json, audio en song/
 * Lo convierte al formato de Psych y lo carga como cualquier chart.
 *
 * El audio que pide el chart se registra aquí y Paths.inst() / Paths.voices()
 * lo usan. En PC Lime no reproduce MP3: hay que convertirlo a OGG.
 */
class FluxMoonchart
{
	/** "mod:canción" -> audio de la canción cargada con Moonchart */
	static var audio:Map<String, MoonchartAudio> = new Map();
	static var warnedMp3:Array<String> = [];

	/**
	 * Dónde guarda el editor de charts (Ctrl+S) el último chart cargado con Moonchart:
	 * al lado del original, con el nombre de Psych (<canción>-<dificultad>.json).
	 * Si está en data/<canción>/, la próxima vez se carga ese chart de Psych.
	 */
	public static var lastChartPath:String = null;

	// ------------------------------------------------------------------ charts

	/**
	 * jsonInput: "mi-cancion-hard" (canción + dificultad), folder: "mi-cancion".
	 * Devuelve null si la canción no tiene charts de Moonchart.
	 */
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;
		var key:String = Paths.formatToSongPath(folder);
		var input:String = Paths.formatToSongPath(jsonInput);
		if (key.length == 0 || !input.startsWith(key)) return null; // ej. "events"

		var postfix:String = input.substr(key.length);
		var diff:String = null;
		if (postfix.length == 0) diff = Paths.formatToSongPath(Difficulty.getDefault());
		else if (postfix.charAt(0) == '-') diff = postfix.substr(1);
		if (diff == null || diff.length == 0) return null;

		audio.remove(audioKey(key));

		var files:Array<MoonchartFile> = findCharts(key);
		if (files.length == 0) return null;

		// la dificultad que se pidió (o la única que hay)
		var chosen:MoonchartFile = null;
		var chosenDiff:String = null;
		var names:Array<String> = [];
		for (file in files)
		{
			for (name in file.diffs)
			{
				if (!names.contains(name)) names.push(name);
				if (chosen == null && matchesDifficulty(name, diff))
				{
					chosen = file;
					chosenDiff = name;
				}
			}
		}
		if (chosen == null && names.length == 1)
		{
			for (file in files)
				if (file.diffs.length > 0)
				{
					chosen = file;
					chosenDiff = file.diffs[0];
					break;
				}
		}
		if (chosen == null)
			throw 'Moonchart: no hay chart para la dificultad "$diff" de "$folder".\n'
				+ 'Dificultades que traen los charts: ${names.join(', ')}.\n'
				+ 'Pon esos nombres en "difficulties" de la semana (weeks/*.json).';
		if (chosen.error != null)
			throw 'Moonchart: ${Path.withoutDirectory(chosen.path)} ${chosen.error}.';

		var json:Dynamic = Json.parse(convert(chosen, chosenDiff));
		cleanNotes(json.song != null ? json.song : json);
		var song:SwagSong = Song.parseJSON(Json.stringify(json), jsonInput);
		fixSong(song, chosen, folder);

		var audioFolder:String = Path.directory(chosen.path);
		if (chosen.kind == 'codename')
			audioFolder = Path.join([Path.directory(Path.directory(chosen.path)), 'song']);
		audio.set(audioKey(key), {
			folder: audioFolder,
			inst: (chosen.audio != null && chosen.audio.length > 0) ? Path.join([Path.directory(chosen.path), chosen.audio]) : null
		});
		lastChartPath = Path.join([Path.directory(chosen.path), input + '.json']);

		trace('[Flux Moonchart] ${chosen.kind}: ${chosen.path} ($chosenDiff)');
		return song;
	}

	/** Convierte el chart a un JSON de Psych (formato viejo, Song.parseJSON lo pasa a psych_v1) */
	static function convert(file:MoonchartFile, diff:String):String
	{
		var psych:FNFPsych = new FNFPsych();
		var format:DynamicFormat = switch (file.kind)
		{
			case 'osu':
				var osu:OsuMania = new OsuMania().fromFile(file.path);
				if (osu == null) throw 'Moonchart: ${file.path} no es un chart de osu!mania.';
				// Moonchart resta AudioLeadIn a las notas, pero en osu! las notas ya cuentan desde el inicio del audio
				osu.data.General.AudioLeadIn = 0;
				osu;
			case 'quaver':
				new Quaver().fromFile(file.path);
			case 'stepmania':
				file.format;
			case 'codename':
				// valores que Codename pone por defecto y Moonchart necesita
				var chart:Dynamic = Json.parse(File.getContent(file.path));
				if (chart.strumLines == null) chart.strumLines = [];
				if (chart.events == null) chart.events = [];
				if (chart.noteTypes == null) chart.noteTypes = [];
				if (chart.scrollSpeed == null) chart.scrollSpeed = 1;
				if (chart.stage == null) chart.stage = 'stage';
				var lines:Array<Dynamic> = chart.strumLines;
				for (line in lines)
				{
					if (line.notes == null) line.notes = [];
					if (line.characters == null) line.characters = [];
				}
				// los tipos de nota de Codename ("Hurt Note", los de scripts...) pasan con el mismo nombre
				var types:Array<Dynamic> = chart.noteTypes;
				for (type in types)
				{
					var name:String = Std.string(type);
					if (type != null && name.length > 0) psych.noteTypeResolver.register(name, name);
				}
				new FNFCodename().fromJson(Json.stringify(chart), codenameMeta(file), diff);
			default:
				throw 'Moonchart: formato desconocido ${file.kind}';
		}
		return psych.fromFormat(format, diff).stringify().data;
	}

	/**
	 * Todas las notas con tipo (Psych lo espera en [3]) y sin los tipos internos
	 * de Moonchart, que en Psych son notas normales (__OSU-1-0-0, ROLL).
	 */
	static function cleanNotes(songData:Dynamic):Void
	{
		var sections:Array<Dynamic> = songData.notes;
		if (sections == null) return;
		for (section in sections)
		{
			var notes:Array<Dynamic> = section.sectionNotes;
			if (notes == null) continue;
			for (note in notes)
			{
				var data:Array<Dynamic> = note;
				while (data.length < 3) data.push(0);
				if (data.length < 4) data.push('');
				else if (!Std.isOfType(data[3], String)) continue; // tipo por número: Psych lo convierte
				else
				{
					var type:String = data[3];
					if (type.startsWith('__OSU') || type == 'ROLL') data[3] = '';
				}
			}
		}
	}

	/** Arreglos después de convertir: nombre, voces y GF */
	static function fixSong(song:SwagSong, file:MoonchartFile, folder:String):Void
	{
		// el nombre tiene que dar la carpeta de la canción (scripts, events.json y audio)
		song.song = displayName(folder, song.song);

		if (file.kind == 'codename')
		{
			var meta:Dynamic = Json.parse(codenameMeta(file));
			song.needsVoices = (meta.needsVoices != false);

			// sin strumline de GF, Moonchart pone "bf"
			var chart:Dynamic = Json.parse(File.getContent(file.path));
			var hasGf:Bool = false;
			var lines:Array<Dynamic> = chart.strumLines;
			if (lines != null)
				for (line in lines)
					if (line.position == 'girlfriend') hasGf = true;
			if (!hasGf) song.gfVersion = 'gf';
		}
		else song.needsVoices = false; // osu!mania, Quaver y StepMania traen un solo audio
	}

	/** El meta.json de Codename, con los valores por defecto de Codename */
	static function codenameMeta(file:MoonchartFile):String
	{
		var meta:Dynamic = {};
		if (file.meta != null && FileSystem.exists(file.meta))
			meta = Json.parse(File.getContent(file.meta));
		if (meta.name == null) meta.name = Path.withoutDirectory(Path.directory(Path.directory(file.path)));
		if (meta.displayName == null) meta.displayName = meta.name;
		if (meta.bpm == null) meta.bpm = 100;
		if (meta.beatsPerMeasure == null) meta.beatsPerMeasure = 4;
		if (meta.stepsPerBeat == null) meta.stepsPerBeat = 4;
		if (meta.needsVoices == null) meta.needsVoices = true;
		if (meta.difficulties == null) meta.difficulties = [];
		return Json.stringify(meta);
	}

	// ---------------------------------------------------------------- búsqueda

	/** Todos los charts de Moonchart de la canción, del mod actual primero */
	public static function findCharts(key:String):Array<MoonchartFile>
	{
		var files:Array<MoonchartFile> = [];
		for (dir in songFolders(key))
		{
			var names:Array<String> = FileSystem.readDirectory(dir);
			names.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
			for (name in names)
			{
				var path:String = '$dir/$name';
				if (FileSystem.isDirectory(path)) continue;
				try
				{
					switch (Path.extension(name).toLowerCase())
					{
						case 'osu':
							files.push(readOsu(path));
						case 'qua':
							files.push(readQuaver(path));
						case 'ssc':
							files.push(readStepMania(path, true));
						case 'sm':
							// si está el mismo archivo en .ssc (StepMania 5), se usa ese
							if (!names.contains(Path.withoutExtension(name) + '.ssc'))
								files.push(readStepMania(path, false));
					}
				}
				catch (e:Dynamic)
				{
					trace('[Flux Moonchart] No se pudo leer $path: $e');
				}
			}

			// Codename Engine: charts/<dificultad>.json y meta.json
			var chartsDir:String = '$dir/charts';
			if (FileSystem.exists(chartsDir) && FileSystem.isDirectory(chartsDir))
			{
				var diffs:Array<String> = [];
				var chartNames:Array<String> = FileSystem.readDirectory(chartsDir);
				chartNames.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
				for (name in chartNames)
					if (Path.extension(name).toLowerCase() == 'json')
						files.push({
							kind: 'codename',
							path: '$chartsDir/$name',
							meta: '$dir/meta.json',
							diffs: [Path.withoutExtension(name)]
						});
			}
		}
		return files;
	}

	/** data/<canción>/ y songs/<canción>/ en el mod actual, los globales, mods/ y assets/ */
	static function songFolders(key:String):Array<String>
	{
		var dirs:Array<String> = [];
		for (sub in ['data/$key/', 'songs/$key/'])
		{
			var found:Array<String> = Mods.directoriesWithFile(sub.startsWith('data') ? Paths.getSharedPath() : 'assets/', sub);
			found.reverse(); // el mod actual primero
			for (dir in found)
			{
				while (dir.endsWith('/')) dir = dir.substr(0, dir.length - 1);
				if (!dirs.contains(dir) && FileSystem.exists(dir) && FileSystem.isDirectory(dir))
					dirs.push(dir);
			}
		}
		return dirs;
	}

	static function readOsu(path:String):MoonchartFile
	{
		var text:String = File.getContent(path);
		var version:String = headerValue(text, 'Version');
		var file:MoonchartFile = {
			kind: 'osu',
			path: path,
			diffs: [version != null && version.length > 0 ? version : Path.withoutExtension(Path.withoutDirectory(path))],
			audio: headerValue(text, 'AudioFilename')
		};
		var mode:String = headerValue(text, 'Mode');
		var keys:Null<Int> = Std.parseInt(headerValue(text, 'CircleSize'));
		if (mode != '3') file.error = 'no es de osu!mania (Mode: $mode)';
		else if (keys != 4) file.error = 'es de $keys teclas y Flux solo juega charts de 4 teclas';
		return file;
	}

	static function readQuaver(path:String):MoonchartFile
	{
		var text:String = File.getContent(path);
		var name:String = headerValue(text, 'DifficultyName');
		var file:MoonchartFile = {
			kind: 'quaver',
			path: path,
			diffs: [name != null && name.length > 0 ? name : Path.withoutExtension(Path.withoutDirectory(path))],
			audio: headerValue(text, 'AudioFile')
		};
		var mode:String = headerValue(text, 'Mode');
		if (mode != 'Keys4') file.error = 'es de ${mode == 'Keys7' ? '7' : mode} teclas y Flux solo juega charts de 4 teclas';
		return file;
	}

	static function readStepMania(path:String, ssc:Bool):MoonchartFile
	{
		var format:DynamicFormat;
		if (ssc) format = new FluxStepManiaShark().fromFile(path);
		else format = new FluxStepMania().fromFile(path);
		var data:StepManiaFormat = format.data;
		var diffs:Array<String> = [for (diff in data.NOTES.keys()) diff];
		diffs.sort(function(a, b) return stepManiaOrder(a) - stepManiaOrder(b));
		var file:MoonchartFile = {
			kind: 'stepmania',
			path: path,
			diffs: diffs,
			audio: data.MUSIC,
			format: format
		};
		if (diffs.length == 0) file.error = 'no tiene charts de 4 teclas (dance-single)';
		return file;
	}

	static function stepManiaOrder(diff:String):Int
	{
		var index:Int = ['beginner', 'easy', 'medium', 'hard', 'challenge', 'edit'].indexOf(diff.toLowerCase());
		return index < 0 ? 99 : index;
	}

	/** "Clave: valor" de los archivos de osu! y Quaver */
	static function headerValue(text:String, name:String):String
	{
		for (line in text.split('\n'))
		{
			var trimmed:String = line.trim();
			if (trimmed.startsWith(name + ':'))
				return trimmed.substr(name.length + 1).trim();
		}
		return null;
	}

	/** Compara dificultades, con los nombres de StepMania (Medium = Normal, Challenge = Expert) */
	public static function matchesDifficulty(name:String, wanted:String):Bool
	{
		var formatted:String = Paths.formatToSongPath(name);
		if (formatted == wanted) return true;
		return switch (wanted)
		{
			case 'normal': formatted == 'medium';
			case 'medium': formatted == 'normal';
			case 'expert': formatted == 'challenge';
			case 'challenge': formatted == 'expert';
			default: false;
		}
	}

	/** El nombre como está en la semana ("Mi Canción"), si coincide con la carpeta */
	static function displayName(folder:String, title:String):String
	{
		var key:String = Paths.formatToSongPath(folder);
		if (title != null && Paths.formatToSongPath(title) == key) return title;
		for (week in WeekData.weeksLoaded)
		{
			if (week == null || week.songs == null) continue;
			for (song in week.songs)
			{
				var name:String = Std.string(song[0]);
				if (Paths.formatToSongPath(name) == key) return name;
			}
		}
		return folder;
	}

	// ------------------------------------------------------------------- audio

	static inline function audioKey(key:String):String
		return '${Mods.currentModDirectory}:$key';

	/** El instrumental de una canción cargada con Moonchart (null si no es de Moonchart) */
	public static function inst(song:String):Sound
	{
		var entry:MoonchartAudio = audio.get(audioKey(Paths.formatToSongPath(song)));
		if (entry == null) return null;
		var sound:Sound = loadSound(entry.inst);
		return sound != null ? sound : loadSound('${entry.folder}/Inst.ogg');
	}

	/** Las voces (Voices.ogg o Voices-<postfix>.ogg) de una canción cargada con Moonchart */
	public static function voices(song:String, ?postfix:String):Sound
	{
		var entry:MoonchartAudio = audio.get(audioKey(Paths.formatToSongPath(song)));
		if (entry == null) return null;
		return loadSound('${entry.folder}/Voices' + (postfix != null && postfix.length > 0 ? '-$postfix' : '') + '.ogg');
	}

	static function loadSound(path:String):Sound
	{
		if (path == null) return null;
		var ext:String = Path.extension(path).toLowerCase();
		if (ext != 'ogg' && ext != 'wav')
		{
			// en PC Lime solo reproduce OGG y WAV: probar el mismo nombre en .ogg
			var ogg:String = Path.withoutExtension(path) + '.ogg';
			if (!FileSystem.exists(ogg))
			{
				if (FileSystem.exists(path) && !warnedMp3.contains(path))
				{
					warnedMp3.push(path);
					trace('[Flux Moonchart] Flux no puede reproducir $path: conviértelo a OGG ($ogg)');
				}
				return null;
			}
			path = ogg;
		}
		if (!FileSystem.exists(path)) return null;

		if (!Paths.currentTrackedSounds.exists(path))
			Paths.currentTrackedSounds.set(path, Sound.fromFile(path));
		Paths.localTrackedAssets.push(path);
		return Paths.currentTrackedSounds.get(path);
	}
}

// --------------------------------------------------------------- StepMania

/** StepMania (.sm) que solo lee los charts de 4 teclas (dance-single) */
private class FluxStepMania extends StepMania
{
	public function new()
	{
		super();
		parser = new FluxStepManiaParser();
	}
}

private class FluxStepManiaParser extends BasicStepManiaParser<StepManiaFormat>
{
	override function parseMap(title:String, value:String, formatted:StepManiaFormat, currentMapData:StepManiaNotes):Void
	{
		var params:Array<String> = msdFile.values[idx];
		if (params.length < 2 || params[1].trim().toLowerCase() != 'dance-single') return;
		super.parseMap(title, value, formatted, currentMapData);
	}
}

/** StepMania 5 (.ssc) que solo lee los charts de 4 teclas (dance-single) */
private class FluxStepManiaShark extends StepManiaShark
{
	public function new()
	{
		super();
		parser = new FluxStepManiaSharkParser();
	}
}

private class FluxStepManiaSharkParser extends StepManiaSharkParser
{
	override function parseMap(title:String, value:String, formatted:SSCFormat, currentMapData:StepManiaNotes):Void
	{
		if (title != 'NOTES' && title != 'NOTES2')
		{
			super.parseMap(title, value, formatted, currentMapData);
			return;
		}

		// Moonchart 0.5.1 usa el mismo objeto para todos los charts del .ssc (las notas
		// se juntan y todas las dificultades quedan iguales): copiar cada chart aparte
		parseState = SONG_INFO;
		if (currentMapData.dance != null && currentMapData.dance.trim().toLowerCase() == 'dance-single')
		{
			var chart:StepManiaNotes = {
				dance: currentMapData.dance,
				diff: currentMapData.diff,
				desc: currentMapData.desc,
				notes: [],
				charter: currentMapData.charter,
				meter: currentMapData.meter,
				radar: currentMapData.radar
			};
			readNoteData(chart, value);
			formatted.NOTES.set(chart.diff, chart);
		}

		// el próximo chart empieza vacío
		currentMapData.dance = StepManiaDance.SINGLE;
		currentMapData.diff = 'Medium';
		currentMapData.desc = '';
		currentMapData.notes = [];
		currentMapData.charter = 'Unknown';
		currentMapData.meter = 1;
		currentMapData.radar = [0, 0, 0, 0, 0];
	}
}
#end
