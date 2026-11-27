package flux.dave;

using StringTools;

/**
 * Flux Engine: lectura de los archivos de Dave Engine (VS Dave and Bambi Volume 1).
 * No usa Flixel, así se puede probar aparte.
 *
 * Canciones: data/songs/<id>/<id>-metadata[-variación].json y <id>-chart[-variación].json,
 * con el audio en songs/<id>/Inst.ogg y Voices.ogg (como V-Slice, pero con secciones y una sola dificultad).
 */
class DaveData
{
	/** Un metadata de Dave Engine (songName, player/opponent arriba; V-Slice usa playData). */
	public static function isSongMeta(meta:Dynamic):Bool
		return meta != null && Reflect.field(meta, 'playData') == null && Reflect.field(meta, 'songName') != null
			&& (Reflect.field(meta, 'player') != null || Reflect.field(meta, 'opponent') != null);

	/** Un chart de Dave Engine (secciones en "notes" con mustHitSection). */
	public static function isChart(chart:Dynamic):Bool
	{
		if (chart == null || !Std.isOfType(Reflect.field(chart, 'notes'), Array)) return false;
		var notes:Array<Dynamic> = Reflect.field(chart, 'notes');
		return notes.length == 0 || Reflect.hasField(notes[0], 'mustHitSection') || Reflect.hasField(notes[0], 'notes');
	}

	/** Un personaje de Dave Engine (data/characters/<id>.json): sin animaciones, con archivos de offsets. */
	public static function isCharacter(json:Dynamic):Bool
		return json != null && Reflect.field(json, 'assetPath') == null && !Std.isOfType(Reflect.field(json, 'animations'), Array)
			&& (Reflect.hasField(json, 'offsetFileOpponent') || Reflect.hasField(json, 'offsetFilePlayer') || Reflect.hasField(json, 'danceSnap'));

	/** Un escenario de Dave Engine (data/stages/<id>.json): player/opponent/gf con position, sin props. */
	public static function isStage(json:Dynamic):Bool
		return json != null && !Std.isOfType(Reflect.field(json, 'props'), Array)
			&& (Reflect.field(json, 'player') != null || Reflect.field(json, 'opponent') != null);

	/**
	 * Canción de Dave Engine a un JSON de chart de Psych (formato viejo con mustHitSection:
	 * Song.parseJSON lo pasa a psych_v1). Las notas de dirección 4-7 son del otro lado, como en Dave.
	 * @param id carpeta de la canción (se usa como nombre si el songName no da la misma carpeta)
	 */
	public static function toPsychSong(meta:Dynamic, chart:Dynamic, id:String, ?formatName:String->String):Dynamic
	{
		var changes:Array<Dynamic> = Std.isOfType(meta.timeChanges, Array) ? (meta.timeChanges : Array<Dynamic>).copy() : [];
		changes.sort((a, b) -> num(a.time, 0) < num(b.time, 0) ? -1 : (num(a.time, 0) > num(b.time, 0) ? 1 : 0));
		var bpm:Float = changes.length > 0 ? num(changes[0].bpm, 100) : 100;
		var nextChange:Int = 1;

		var sections:Array<Dynamic> = [];
		var time:Float = 0;
		var curBpm:Float = bpm;
		var source:Array<Dynamic> = Std.isOfType(chart.notes, Array) ? chart.notes : [];
		for (sec in source)
		{
			var section:Dynamic = {
				sectionNotes: [],
				sectionBeats: 4,
				mustHitSection: sec != null && sec.mustHitSection == true,
				gfSection: false,
				altAnim: false,
				changeBPM: false,
				bpm: curBpm
			};
			// cambios de BPM: van en la sección donde empiezan
			while (nextChange < changes.length && num(changes[nextChange].time, 0) <= time + 1)
			{
				curBpm = num(changes[nextChange].bpm, curBpm);
				section.changeBPM = true;
				section.bpm = curBpm;
				nextChange++;
			}
			var notes:Array<Dynamic> = (sec != null && Std.isOfType(sec.notes, Array)) ? sec.notes : [];
			var list:Array<Dynamic> = section.sectionNotes;
			for (n in notes)
			{
				if (n == null) continue;
				var note:Array<Dynamic> = [];
				note.push(num(n.time, 0));
				note.push(Std.int(num(n.direction, 0)));
				note.push(num(n.length, 0));
				note.push(n.type != null ? Std.string(n.type) : '');
				list.push(note);
			}
			sections.push(section);
			time += 4 * 60000 / curBpm;
		}

		var name:String = meta.songName != null ? Std.string(meta.songName) : id;
		if (formatName != null && formatName(name) != id) name = id; // el nombre tiene que dar la carpeta del audio
		var gf:Dynamic = meta.gf != null ? meta.gf : meta.girlfriend;
		return {
			song: name,
			notes: sections,
			events: [],
			bpm: bpm,
			needsVoices: true,
			speed: num(chart.speed, 1),
			offset: 0,
			player1: meta.player != null ? Std.string(meta.player) : 'bf',
			player2: meta.opponent != null ? Std.string(meta.opponent) : 'dave',
			gfVersion: gf != null ? Std.string(gf) : 'gf',
			stage: meta.stage != null ? Std.string(meta.stage) : 'stage',
			format: 'dave_engine'
		};
	}

	/** Archivo de offsets de Dave Engine ("anim x y" por línea). */
	public static function parseOffsets(text:String):Map<String, Array<Float>>
	{
		var result:Map<String, Array<Float>> = new Map();
		if (text == null) return result;
		for (line in text.split('\n'))
		{
			var parts:Array<String> = [for (p in line.trim().split(' ')) if (p.length > 0) p];
			if (parts.length < 3) continue;
			var x:Float = Std.parseFloat(parts[parts.length - 2]);
			var y:Float = Std.parseFloat(parts[parts.length - 1]);
			if (Math.isNaN(x) || Math.isNaN(y)) continue;
			// el nombre puede tener espacios
			result.set(parts.slice(0, parts.length - 2).join(' '), [x, y]);
		}
		return result;
	}

	/** Color de Dave ("0x0F5FFF", "#0F5FFF") a [r, g, b]. */
	public static function rgb(text:Dynamic):Array<Int>
	{
		if (text == null) return null;
		var hex:String = Std.string(text).trim();
		if (hex.startsWith('#')) hex = hex.substr(1);
		else if (hex.toLowerCase().startsWith('0x')) hex = hex.substr(2);
		if (hex.length == 8) hex = hex.substr(2);
		if (hex.length != 6) return null;
		var value:Null<Int> = Std.parseInt('0x$hex');
		return value == null ? null : [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
	}

	public static function num(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return value;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}
