package flux.vslice;

#if FLUX_VSLICE
import backend.Song;
import haxe.Json;
import openfl.media.Sound;
import states.editors.content.VSlice;

using StringTools;

/** Una canción de V-Slice registrada desde un level (semana) */
typedef VSliceSongRef =
{
	var id:String;                       // carpeta en data/songs/
	var variations:Map<String, String>;  // dificultad -> variación ('' = la normal)
}

/**
 * Compatibilidad con mods de V-Slice, fase 1: canciones.
 *
 * Si no existe el chart de Psych, Song.getChart() llama a FluxVSlice.getChart(),
 * que busca el formato de V-Slice:
 *   data/songs/<id>/<id>-metadata[-variacion].json
 *   data/songs/<id>/<id>-chart[-variacion].json
 * y lo convierte con el convertidor de V-Slice que trae Psych (VSlice.convertToPsych).
 *
 * El audio se busca con los nombres de V-Slice:
 *   songs/<id>/Inst[-instrumental].ogg
 *   songs/<id>/Voices-<personaje>[-variacion].ogg
 *
 * Las variaciones con dificultades propias (erect, nightmare) se juntan con la
 * canción normal; las que repiten dificultades (pico, bf) salen aparte en Freeplay
 * con su propio nombre, por ejemplo "Bopeebo (Pico Mix)".
 */
class FluxVSlice
{
	/** nombre formateado de la canción en Freeplay -> canción de V-Slice */
	public static var songLookup:Map<String, VSliceSongRef> = new Map();

	public static function registerSong(displayName:String, ref:VSliceSongRef)
		songLookup.set(Paths.formatToSongPath(displayName), ref);

	public static inline function info(song:SwagSong):Dynamic
		return song != null ? Reflect.field(song, 'fluxVSlice') : null;

	public static inline function isVSlice(song:SwagSong):Bool
		return info(song) != null;

	// ------------------------------------------------------------------ charts

	/**
	 * jsonInput: "bopeebo-hard" (canción + dificultad), folder: "bopeebo".
	 * Devuelve null si no es una canción de V-Slice.
	 */
	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null) folder = jsonInput;
		var key:String = Paths.formatToSongPath(folder);
		var input:String = Paths.formatToSongPath(jsonInput);
		if (!input.startsWith(key)) return null; // ej. "events"

		var postfix:String = input.substr(key.length);
		var diff:String = null;
		if (postfix.length == 0) diff = Paths.formatToSongPath(Difficulty.getDefault());
		else if (postfix.charAt(0) == '-') diff = postfix.substr(1);
		if (diff == null || diff.length == 0) return null;

		var id:String = key;
		var variation:String = null;
		var ref:VSliceSongRef = songLookup.get(key);
		if (ref != null)
		{
			id = ref.id;
			if (ref.variations.exists(diff)) variation = ref.variations.get(diff);
		}
		if (variation == null) variation = findVariationForDifficulty(id, diff);
		if (variation == null) return null;

		try
		{
			var metaPath:String = findDataFile(id, 'metadata', variation);
			var chartPath:String = findDataFile(id, 'chart', variation);
			if (metaPath == null || chartPath == null) return null;

			var metadata:Dynamic = Json.parse(File.getContent(metaPath));
			var chart:Dynamic = Json.parse(File.getContent(chartPath));
			return convert(chart, metadata, diff, id, variation);
		}
		catch (e:Dynamic)
		{
			trace('[Flux V-Slice] Error al cargar $id ($diff): $e');
			return null;
		}
	}

	/** Convierte un chart + metadata de V-Slice a una dificultad de Psych */
	public static function convert(chart:Dynamic, metadata:Dynamic, diff:String, id:String, variation:String):SwagSong
	{
		var playData:Dynamic = metadata.playData;
		var difficulties:Array<String> = playData.difficulties;
		if (difficulties == null || !difficulties.contains(diff)) return null;

		if (metadata.timeChanges == null || (metadata.timeChanges : Array<Dynamic>).length == 0)
			metadata.timeChanges = [{t: 0, bpm: 100}];

		// Copia de los cambios de BPM: el convertidor de Psych modifica la lista
		var timeChanges:Array<Dynamic> = [for (tc in (metadata.timeChanges : Array<Dynamic>)) {t: tc.t, bpm: tc.bpm}];
		timeChanges.sort((a, b) -> a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

		// Psych se encarga de secciones, notas, BPM y FocusCamera; el resto de eventos los convierto aquí
		var allEvents:Array<Dynamic> = chart.events != null ? chart.events : [];
		chart.events = allEvents.filter(e -> e.e == 'FocusCamera');
		var otherEvents:Array<Dynamic> = allEvents.filter(e -> e.e != 'FocusCamera');
		if (chart.notes == null) chart.notes = {};
		if (chart.scrollSpeed == null) chart.scrollSpeed = {};
		playData.difficulties = [diff]; // solo convertir la dificultad pedida

		var pack:PsychPackage = VSlice.convertToPsych(cast chart, cast metadata);
		var song:SwagSong = pack.difficulties.get(diff);
		if (song == null) return null;

		if (Math.isNaN(song.speed) || song.speed <= 0)
		{
			var speed:Null<Float> = Reflect.field(chart.scrollSpeed, 'default');
			song.speed = (speed != null && speed > 0) ? speed : 1;
		}

		for (section in song.notes)
			for (note in section.sectionNotes)
				if (note.length > 3 && note[3] != null)
					note[3] = noteKind(Std.string(note[3]));

		song.events = convertEvents(otherEvents, timeChanges, song.speed);

		var characters:Dynamic = playData.characters != null ? playData.characters : {};
		var instrumental:String = characters.instrumental != null ? Std.string(characters.instrumental) : '';
		var playerVocals:Array<String> = toStringArray(characters.playerVocals, song.player1);
		var opponentVocals:Array<String> = toStringArray(characters.opponentVocals, song.player2);
		Reflect.setField(song, 'fluxVSlice', {
			id: id,
			variation: variation,
			difficulty: diff,
			instrumental: instrumental,
			playerVocals: playerVocals,
			opponentVocals: opponentVocals,
			noteStyle: playData.noteStyle
		});
		return song;
	}

	static function toStringArray(value:Dynamic, fallback:String):Array<String>
	{
		var list:Array<String> = [];
		if (value != null && Std.isOfType(value, Array))
			for (item in (value : Array<Dynamic>))
				if (item != null) list.push(Std.string(item));
		if (list.length == 0 && fallback != null) list.push(fallback);
		return list;
	}

	/** Busca en qué variación está una dificultad (null si en ninguna) */
	public static function findVariationForDifficulty(id:String, diff:String):String
	{
		var metaPath:String = findDataFile(id, 'metadata', '');
		if (metaPath == null) return null;
		try
		{
			var meta:Dynamic = Json.parse(File.getContent(metaPath));
			var diffs:Array<String> = meta.playData.difficulties;
			if (diffs != null && diffs.contains(diff)) return '';

			var variations:Array<String> = meta.playData.songVariations;
			if (variations != null)
				for (variation in variations)
				{
					var path:String = findDataFile(id, 'metadata', variation);
					if (path == null) continue;
					var vmeta:Dynamic = Json.parse(File.getContent(path));
					var vdiffs:Array<String> = vmeta.playData.difficulties;
					if (vdiffs != null && vdiffs.contains(diff)) return variation;
				}
		}
		catch (e:Dynamic) {}
		return null;
	}

	/** data/songs/<id>/<id>-<kind>[-variation].json en el mod actual, mods globales o assets */
	public static function findDataFile(id:String, kind:String, variation:String):String
	{
		var file:String = 'data/songs/$id/$id-$kind' + (variation != null && variation.length > 0 ? '-$variation' : '') + '.json';
		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders(file);
		if (FileSystem.exists(modPath)) return modPath;
		#end
		var shared:String = Paths.getSharedPath(file);
		if (FileSystem.exists(shared)) return shared;
		return null;
	}

	/** Tipos de nota de V-Slice -> tipos de Psych */
	static function noteKind(kind:String):String
	{
		return switch (kind)
		{
			case 'alt': 'Alt Animation';
			case 'noAnim' | 'noanim' | 'no-anim': 'No Animation';
			case 'hey': 'Hey!';
			case 'gf' | 'gfSing' | 'gf-sing': 'GF Sing';
			case 'hurt': 'Hurt Note';
			default: kind;
		}
	}

	/** Eventos de V-Slice -> eventos de Psych ([tiempo, [[nombre, valor1, valor2]]]) */
	static function convertEvents(events:Array<Dynamic>, timeChanges:Array<Dynamic>, baseSpeed:Float):Array<Dynamic>
	{
		// Se ordenan los eventos originales (objetos). No ordenar "out" después: en C++,
		// ordenar una lista de arrays Dynamic puede convertirlos a arrays de números.
		events.sort((a, b) -> Reflect.compare(a.t, b.t));
		var out:Array<Dynamic> = [];
		for (event in events)
		{
			var time:Float = event.t;
			var name:String = event.e;
			var v:Dynamic = event.v;
			switch (name)
			{
				case 'PlayAnimation':
					var target:String = v != null && v.target != null ? Std.string(v.target).toLowerCase() : '';
					var anim:String = v != null && v.anim != null ? Std.string(v.anim) : null;
					var psychChar:String = switch (target)
					{
						case 'bf' | 'boyfriend' | 'player': 'bf';
						case 'dad' | 'opponent': 'dad';
						case 'gf' | 'girlfriend': 'gf';
						default: null;
					}
					if (psychChar != null && anim != null)
						out.push(psychEvent(time, 'Play Animation', anim, psychChar));
					else
						out.push(psychEvent(time, name, Json.stringify(v), ''));

				case 'ScrollSpeed':
					var scroll:Float = (v != null && v.scroll != null) ? v.scroll : 1;
					var absolute:Bool = v != null && v.absolute == true;
					var steps:Float = (v != null && v.duration != null) ? v.duration : 4;
					var ease:String = (v != null && v.ease != null) ? Std.string(v.ease) : 'linear';
					var mult:Float = absolute ? scroll / baseSpeed : scroll;
					var seconds:Float = (ease.toUpperCase() == 'INSTANT' || steps <= 0) ? 0 : steps * stepCrochetAt(time, timeChanges) / 1000;
					out.push(psychEvent(time, 'Change Scroll Speed', Std.string(mult), Std.string(seconds)));

				default:
					// ZoomCamera, SetCameraBop... los maneja FluxVSliceEvents; el resto llega a onEvent de los scripts
					out.push(psychEvent(time, name, Std.isOfType(v, String) ? v : Json.stringify(v), ''));
			}
		}
		return out;
	}

	/**
	 * [tiempo, [[nombre, valor1, valor2]]] armado con push(): en C++ un Array<Dynamic>
	 * creado como literal que empieza con un Float guarda solo números y la lista
	 * quedaría en 0. Con push() queda igual que un chart leído de JSON.
	 */
	static function psychEvent(time:Float, name:String, value1:String, value2:String):Array<Dynamic>
	{
		var entry:Array<Dynamic> = [];
		entry.push(name);
		entry.push(value1);
		entry.push(value2);
		var list:Array<Dynamic> = [];
		list.push(entry);
		var event:Array<Dynamic> = [];
		event.push(time);
		event.push(list);
		return event;
	}

	static function stepCrochetAt(time:Float, timeChanges:Array<Dynamic>):Float
	{
		var bpm:Float = timeChanges.length > 0 ? timeChanges[0].bpm : 100;
		for (change in timeChanges)
		{
			if (change.t > time) break;
			bpm = change.bpm;
		}
		return 60000 / bpm / 4;
	}

	// ------------------------------------------------------------------- audio

	/** Instrumental: Inst-<instrumental>, Inst-<variación>, Inst */
	public static function inst(song:SwagSong):Sound
	{
		var data:Dynamic = info(song);
		if (data == null) return null;
		var id:String = data.id;
		var names:Array<String> = [];
		if (data.instrumental != null && data.instrumental.length > 0) names.push('Inst-' + data.instrumental);
		if (data.variation != null && data.variation.length > 0) names.push('Inst-' + data.variation);
		names.push('Inst');
		for (name in names)
		{
			var sound:Sound = Paths.returnSound('$id/$name', 'songs', true, false);
			if (sound != null) return sound;
		}
		return null;
	}

	/**
	 * Voces como en V-Slice: Voices-<personaje>-<variación>, quitando partes del
	 * nombre si no existe (pico-playable -> pico), después sin variación.
	 * Para el jugador, al final prueba Voices-<variación> y Voices (un solo archivo).
	 */
	public static function voices(song:SwagSong, player:Bool):Sound
	{
		var data:Dynamic = info(song);
		if (data == null) return null;
		var id:String = data.id;
		var suffix:String = (data.variation != null && data.variation.length > 0) ? '-' + data.variation : '';
		var vocalIds:Array<String> = player ? data.playerVocals : data.opponentVocals;
		if (vocalIds == null || vocalIds.length == 0) vocalIds = [player ? song.player1 : song.player2];

		for (useSuffix in [true, false])
		{
			var charId:String = vocalIds[0];
			while (charId != null && charId.length > 0)
			{
				var sound:Sound = Paths.voices(id, charId + (useSuffix ? suffix : ''));
				if (sound != null) return sound;
				var parts:Array<String> = charId.split('-');
				parts.pop();
				charId = parts.join('-');
			}
			if (suffix.length == 0) break;
		}

		if (player)
		{
			if (suffix.length > 0)
			{
				var single:Sound = Paths.voices(id, suffix.substr(1));
				if (single != null) return single;
			}
			return Paths.voices(id);
		}
		return null;
	}
}
#end
