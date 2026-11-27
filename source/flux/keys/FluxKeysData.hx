package flux.keys;

using StringTools;

/**
 * Flux Engine: datos y lógica del multi-keys que no dependen de Flixel
 * (así se pueden probar aparte con `haxe --interp`).
 *
 * Direcciones de cada carril: 0 izquierda, 1 abajo, 2 arriba, 3 derecha, 4 centro (círculo).
 * Colores ("slots"): 0-3 son los colores de flecha del jugador (morado, azul, verde, rojo),
 * 4 amarillo, 5 violeta, 6 rojo oscuro, 7 azul oscuro y 8 blanco (el centro).
 */
class FluxKeysData
{
	public static inline var LEFT:Int = 0;
	public static inline var DOWN:Int = 1;
	public static inline var UP:Int = 2;
	public static inline var RIGHT:Int = 3;
	public static inline var CENTER:Int = 4;

	/** Menos y más teclas que puede tener un chart. */
	public static inline var MIN_KEYS:Int = 1;
	public static inline var MAX_KEYS:Int = 17;

	/** Teclas que se pueden elegir en Gameplay Changers. */
	public static inline var MIN_SETTING:Int = 4;

	/** Notas con menos de esta diferencia (ms) se toman como un acorde. */
	public static inline var CHORD_MS:Float = 2;

	public static final DIRECTION_NAMES:Array<String> = ['Left', 'Down', 'Up', 'Right', 'Center'];
	public static final SING_ANIMATIONS:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT', 'singUP'];

	/** Colores extra (relleno, brillo, borde) de los slots 4 a 8. Se pueden cambiar desde scripts. */
	public static var extraColors:Array<Array<Int>> = [
		[0xFFFFDE2E, 0xFFFFFFFF, 0xFF7A5C00], // amarillo
		[0xFFA05CFF, 0xFFFFFFFF, 0xFF3B1366], // violeta
		[0xFFD1202A, 0xFFFFFFFF, 0xFF4A0A0E], // rojo oscuro
		[0xFF2C4BE0, 0xFFFFFFFF, 0xFF0D1557], // azul oscuro
		[0xFFE8E8E8, 0xFFFFFFFF, 0xFF4C5466]  // blanco (centro)
	];
	public static var extraColorsPixel:Array<Array<Int>> = [
		[0xFFFFE23D, 0xFFFFFDF0, 0xFF6B4F00],
		[0xFFB07AFF, 0xFFFBF5FF, 0xFF34105C],
		[0xFFD9333C, 0xFFFFF5F5, 0xFF470808],
		[0xFF3D5CF0, 0xFFF5F7FF, 0xFF0A1252],
		[0xFFF0F0F0, 0xFFFFFFFF, 0xFF454C5C]
	];

	public static inline function isValid(keys:Int):Bool
		return keys >= MIN_KEYS && keys <= MAX_KEYS;

	/** Direcciones de los carriles: L izquierda, D abajo, U arriba, R derecha, S centro (círculo). */
	public static function layoutString(keys:Int):String
	{
		return switch (keys)
		{
			case 1: 'S';
			case 2: 'LR';
			case 3: 'LSR';
			case 4: 'LDUR';
			case 5: 'LDSUR';
			case 6: 'LURLDR';
			case 7: 'LURSLDR';
			case 8: 'LDURLDUR';
			case 9: 'LDURSLDUR';
			case 10: 'LDURSSLDUR';
			case 11: 'LDURLSRLDUR';
			case 12: 'LDURLDURLDUR';
			case 13: 'LDURLDSURLDUR';
			case 14: 'LDURLURLDRLDUR';
			case 15: 'LDURLURSLDRLDUR';
			case 16: 'LDURLDURLDURLDUR';
			case 17: 'LDURLDURSLDURLDUR';
			default: null;
		}
	}

	/** Colores de los carriles: p morado, b azul, g verde, r rojo, y amarillo, v violeta, d rojo oscuro, k azul oscuro, w blanco. */
	public static function colorString(keys:Int):String
	{
		return switch (keys)
		{
			case 1: 'w';
			case 2: 'pr';
			case 3: 'pwr';
			case 4: 'pbgr';
			case 5: 'pbwgr';
			case 6: 'pgrybk';
			case 7: 'pgrwybk';
			case 8: 'pbgryvdk';
			case 9: 'pbgrwyvdk';
			case 10: 'pbgrwwyvdk';
			case 11: 'pbgrywkpbgr';
			case 12: 'pbgryvdkpbgr';
			case 13: 'pbgryvwdkpbgr';
			case 14: 'pbgrydkyvkpbgr';
			case 15: 'pbgrydkwyvkpbgr';
			case 16: 'pbgryvdkyvdkpbgr';
			case 17: 'pbgryvdkwyvdkpbgr';
			default: null;
		}
	}

	/** Teclas por defecto (nombres de FlxKey). Cada carril: [principal, alternativa]. 4K usa las de Psych. */
	public static function defaultKeyNames(keys:Int):Array<Array<String>>
	{
		var main:Array<String> = switch (keys)
		{
			case 1: ['SPACE'];
			case 2: ['F', 'J'];
			case 3: ['F', 'SPACE', 'J'];
			case 5: ['D', 'F', 'SPACE', 'J', 'K'];
			case 6: ['S', 'D', 'F', 'J', 'K', 'L'];
			case 7: ['S', 'D', 'F', 'SPACE', 'J', 'K', 'L'];
			case 8: ['A', 'S', 'D', 'F', 'H', 'J', 'K', 'L'];
			case 9: ['A', 'S', 'D', 'F', 'SPACE', 'H', 'J', 'K', 'L'];
			case 10: ['A', 'S', 'D', 'F', 'V', 'N', 'J', 'K', 'L', 'SEMICOLON'];
			case 11: ['A', 'S', 'D', 'F', 'R', 'SPACE', 'U', 'J', 'K', 'L', 'SEMICOLON'];
			case 12: ['A', 'S', 'D', 'F', 'E', 'R', 'U', 'I', 'J', 'K', 'L', 'SEMICOLON'];
			case 13: ['A', 'S', 'D', 'F', 'E', 'R', 'SPACE', 'U', 'I', 'J', 'K', 'L', 'SEMICOLON'];
			case 14: ['A', 'S', 'D', 'F', 'W', 'E', 'R', 'U', 'I', 'O', 'J', 'K', 'L', 'SEMICOLON'];
			case 15: ['A', 'S', 'D', 'F', 'W', 'E', 'R', 'SPACE', 'U', 'I', 'O', 'J', 'K', 'L', 'SEMICOLON'];
			case 16: ['A', 'S', 'D', 'F', 'Q', 'W', 'E', 'R', 'U', 'I', 'O', 'P', 'J', 'K', 'L', 'SEMICOLON'];
			case 17: ['A', 'S', 'D', 'F', 'Q', 'W', 'E', 'R', 'SPACE', 'U', 'I', 'O', 'P', 'J', 'K', 'L', 'SEMICOLON'];
			default: [];
		}
		// 5K: las flechas también sirven (como en 4K)
		var alt:Array<String> = keys == 5 ? ['LEFT', 'DOWN', null, 'UP', 'RIGHT'] : [];
		return [for (i in 0...main.length) (alt[i] != null) ? [main[i], alt[i]] : [main[i]]];
	}

	/** Botones de mando por defecto (de 5 a 9 teclas; con más no entran en un mando). */
	public static function defaultButtonNames(keys:Int):Array<Array<String>>
	{
		var shoulders:Array<String> = ['LEFT_SHOULDER', 'RIGHT_SHOULDER'];
		return switch (keys)
		{
			case 5: [['DPAD_LEFT', 'X'], ['DPAD_DOWN', 'A'], shoulders, ['DPAD_UP', 'Y'], ['DPAD_RIGHT', 'B']];
			case 6: [['DPAD_LEFT'], ['DPAD_UP'], ['DPAD_RIGHT'], ['X'], ['A'], ['B']];
			case 7: [['DPAD_LEFT'], ['DPAD_UP'], ['DPAD_RIGHT'], shoulders, ['X'], ['A'], ['B']];
			case 8: [['DPAD_LEFT'], ['DPAD_DOWN'], ['DPAD_UP'], ['DPAD_RIGHT'], ['X'], ['A'], ['Y'], ['B']];
			case 9: [['DPAD_LEFT'], ['DPAD_DOWN'], ['DPAD_UP'], ['DPAD_RIGHT'], shoulders, ['X'], ['A'], ['Y'], ['B']];
			default: [];
		}
	}

	/** Direcciones (0-4) de cada carril. */
	public static function layout(keys:Int):Array<Int>
	{
		var str:String = layoutString(keys);
		if (str == null) return [];
		return [for (i in 0...str.length) 'LDURS'.indexOf(str.charAt(i))];
	}

	/** Color (slot 0-8) de cada carril. */
	public static function colorSlots(keys:Int):Array<Int>
	{
		var str:String = colorString(keys);
		if (str == null) return [];
		return [for (i in 0...str.length) 'pbgryvdkw'.indexOf(str.charAt(i))];
	}

	/** Nombre del carril para el menú de controles: "Left", "Down 2", "Center"... */
	public static function laneName(keys:Int, lane:Int):String
	{
		var dirs:Array<Int> = layout(keys);
		if (lane < 0 || lane >= dirs.length) return 'Key ${lane + 1}';
		var dir:Int = dirs[lane];
		var total:Int = 0;
		var index:Int = 0;
		for (i in 0...dirs.length)
		{
			if (dirs[i] != dir) continue;
			total++;
			if (i <= lane) index = total;
		}
		return total > 1 ? '${DIRECTION_NAMES[dir]} $index' : DIRECTION_NAMES[dir];
	}

	/** Valores de la opción de Gameplay Changers: "Chart", "4K" ... "17K". */
	public static function settingValues():Array<String>
	{
		var list:Array<String> = ['Chart'];
		for (k in MIN_SETTING...MAX_KEYS + 1) list.push('${k}K');
		return list;
	}

	/** Lee el valor de la opción ("7K"); devuelve null si es "Chart" o no se entiende. */
	public static function parseSetting(value:Dynamic):Null<Int>
	{
		if (value == null) return null;
		var str:String = Std.string(value).trim().toUpperCase();
		if (str.endsWith('K')) str = str.substr(0, str.length - 1);
		var keys:Null<Int> = Std.parseInt(str);
		return (keys != null && isValid(keys)) ? keys : null;
	}

	/**
	 * Cuántas teclas tiene un chart. Mira `keyCount` y si no, `mania`:
	 * con Psych Extra Keys (formato psych_v1, o charts de Psych con `splashSkin`/`cutsceneType`) son `mania + 1`;
	 * si no, se toma como el mod de Shaggy (0 = 4K, 1 = 6K, 2 = 7K, 3 = 9K, 4 = 5K).
	 * @param legacy el chart no era psych_v1 antes de convertirlo (Song.convert)
	 */
	public static function chartKeys(song:Dynamic, legacy:Bool = false):Int
	{
		if (song == null) return 4;
		var count:Null<Int> = intField(song, 'keyCount');
		if (count != null && isValid(count)) return count;

		var mania:Null<Int> = intField(song, 'mania');
		if (mania != null)
		{
			var format:Dynamic = Reflect.field(song, 'format');
			var extraKeys:Bool = (!legacy && format != null && Std.string(format).startsWith('psych_v1'))
				|| Reflect.hasField(song, 'splashSkin') || Reflect.hasField(song, 'cutsceneType');
			var keys:Int = extraKeys ? mania + 1 : switch (mania)
			{
				case 0: 4;
				case 4: 5;
				case 1, 5, 6: 6;
				case 2, 7: 7;
				case 3, 8: 9;
				default: mania;
			}
			if (isValid(keys)) return keys;
		}
		return 4;
	}

	static function intField(obj:Dynamic, name:String):Null<Int>
	{
		var value:Dynamic = Reflect.field(obj, name);
		if (value == null) return null;
		if (Std.isOfType(value, Int)) return value;
		if (Std.isOfType(value, Float)) return Std.int(value);
		if (Std.isOfType(value, String)) return Std.parseInt(value);
		return null;
	}

	// ------------------------------------------------------------------
	// Conversión de charts
	// ------------------------------------------------------------------

	/**
	 * Carriles a los que puede ir cada carril de origen al pasar de `from` a `to` teclas.
	 * Se respeta la dirección (una izquierda sigue siendo izquierda); los círculos del destino
	 * reciben notas de abajo y de arriba, y si el destino no tiene círculo, el del origen va a
	 * abajo/arriba (los más cercanos al centro).
	 */
	public static function candidates(from:Int, to:Int):Array<Array<Int>>
	{
		var src:Array<Int> = layout(from);
		var dst:Array<Int> = layout(to);
		var byDir:Array<Array<Int>> = [for (d in 0...5) []];
		for (i in 0...dst.length) byDir[dst[i]].push(i);

		var middle:Float = (to - 1) / 2;
		var result:Array<Array<Int>> = [];
		for (lane in 0...src.length)
		{
			var dir:Int = src[lane];
			var list:Array<Int> = byDir[dir].copy();
			if (dir == DOWN || dir == UP)
				for (c in byDir[CENTER]) list.push(c);
			else if (dir == CENTER && list.length == 0)
			{
				list = byDir[DOWN].concat(byDir[UP]);
				list.sort((a, b) -> {
					var da:Float = Math.abs(a - middle);
					var db:Float = Math.abs(b - middle);
					return da < db ? -1 : (da > db ? 1 : a - b);
				});
			}
			if (list.length == 0) list = [for (i in 0...to) i]; // por las dudas (destinos de 1 a 3 teclas)
			result.push(list);
		}
		return result;
	}

	/**
	 * Convierte las secciones de un chart psych_v1 (carriles 0..from-1 jugador, from..2*from-1 oponente)
	 * a `to` teclas. Devuelve copias: el chart original no se toca. Es determinista (misma canción,
	 * mismo resultado), mantiene los jacks y los acordes, no pone notas encima de una sostenida y
	 * reparte las notas por todos los carriles.
	 */
	public static function convertSections(sections:Array<Dynamic>, from:Int, to:Int):Array<Dynamic>
	{
		if (sections == null) return [];
		if (from == to || !isValid(from) || !isValid(to)) return sections;

		var entries:Array<KeyNote> = [];
		var perSection:Array<Array<KeyNote>> = [];
		var order:Int = 0;
		for (section in sections)
		{
			var list:Array<KeyNote> = [];
			var notes:Array<Dynamic> = section != null ? Reflect.field(section, 'sectionNotes') : null;
			if (notes != null)
			{
				for (raw in notes)
				{
					var note:Array<Dynamic> = raw;
					var entry:KeyNote = new KeyNote(note, from, order++);
					list.push(entry);
					if (entry.lane >= 0) entries.push(entry);
				}
			}
			perSection.push(list);
		}

		assignLanes(entries, from, to);

		var result:Array<Dynamic> = [];
		for (i in 0...sections.length)
		{
			var section:Dynamic = sections[i];
			if (section == null)
			{
				result.push(null);
				continue;
			}
			var copy:Dynamic = Reflect.copy(section);
			var notes:Array<Dynamic> = [];
			for (entry in perSection[i])
			{
				if (entry.lane < 0)
				{
					notes.push(entry.note.copy()); // carril raro (eventos viejos): queda igual
					continue;
				}
				if (entry.newLane < 0) continue; // no entraba (acorde más grande que las teclas)
				var note:Array<Dynamic> = entry.note.copy();
				note[1] = entry.newLane + (entry.side == 1 ? to : 0);
				notes.push(note);
			}
			Reflect.setField(copy, 'sectionNotes', notes);
			result.push(copy);
		}
		return result;
	}

	/** Lo mismo que convertSections pero con una lista suelta de notas `[tiempo, carril, largo, tipo]`. */
	public static function convertNotes(notes:Array<Array<Dynamic>>, from:Int, to:Int):Array<Array<Dynamic>>
	{
		var result:Array<Dynamic> = convertSections([{sectionNotes: notes}], from, to);
		return result.length > 0 ? cast Reflect.field(result[0], 'sectionNotes') : [];
	}

	static function assignLanes(entries:Array<KeyNote>, from:Int, to:Int):Void
	{
		var lists:Array<Array<Int>> = candidates(from, to);
		for (side in 0...2)
		{
			var sideNotes:Array<KeyNote> = [for (e in entries) if (e.side == side) e];
			sideNotes.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : a.order - b.order));
			assignSide(sideNotes, from, to, lists);
		}
	}

	static function assignSide(notes:Array<KeyNote>, from:Int, to:Int, lists:Array<Array<Int>>):Void
	{
		var pointer:Array<Int> = [for (i in 0...from) -1];
		var lastTarget:Array<Int> = [for (i in 0...from) -1];
		var busyUntil:Array<Float> = [for (i in 0...to) Math.NEGATIVE_INFINITY];
		var prevSrc:Array<Int> = [];
		var prevDst:Array<Int> = [];

		var i:Int = 0;
		while (i < notes.length)
		{
			var start:Float = notes[i].time;
			var j:Int = i + 1;
			while (j < notes.length && notes[j].time - start < CHORD_MS) j++;

			var chord:Array<KeyNote> = notes.slice(i, j);
			// los jacks van primero para quedarse con su carril de antes
			chord.sort((a, b) -> {
				var ja:Int = prevSrc.contains(a.src) ? 0 : 1;
				var jb:Int = prevSrc.contains(b.src) ? 0 : 1;
				if (ja != jb) return ja - jb;
				if (a.src != b.src) return a.src - b.src;
				return a.order - b.order;
			});

			var used:Array<Int> = [];
			var curSrc:Array<Int> = [];
			for (note in chord)
			{
				var time:Float = note.time;
				var free = function(lane:Int):Bool return !used.contains(lane) && busyUntil[lane] - time < 1;

				// la misma nota repetida en el chart (nota fantasma): al mismo carril, así Psych la limpia
				if (curSrc.contains(note.src))
				{
					note.newLane = lastTarget[note.src];
					continue;
				}

				var list:Array<Int> = lists[note.src];
				var pick:Int = -1;

				// jack: mismo carril que la vez anterior
				if (prevSrc.contains(note.src) && lastTarget[note.src] >= 0 && free(lastTarget[note.src]))
					pick = lastTarget[note.src];

				// si no, rotar entre los carriles de esa dirección (sin inventar jacks)
				if (pick < 0)
				{
					for (pass in 0...2)
					{
						for (k in 1...list.length + 1)
						{
							var index:Int = (pointer[note.src] + k) % list.length;
							var lane:Int = list[index];
							if (!free(lane) || (pass == 0 && prevDst.contains(lane))) continue;
							pick = lane;
							pointer[note.src] = index;
							break;
						}
						if (pick >= 0) break;
					}
				}

				// todos ocupados: el carril libre más cercano
				if (pick < 0)
				{
					var wanted:Int = list[(pointer[note.src] + 1 + list.length) % list.length];
					for (dist in 1...to)
					{
						if (wanted - dist >= 0 && free(wanted - dist))
						{
							pick = wanted - dist;
							break;
						}
						if (wanted + dist < to && free(wanted + dist))
						{
							pick = wanted + dist;
							break;
						}
					}
				}

				curSrc.push(note.src);
				if (pick < 0)
				{
					note.newLane = -1; // no entra
					lastTarget[note.src] = -1;
					continue;
				}

				note.newLane = pick;
				used.push(pick);
				lastTarget[note.src] = pick;
				if (note.hold > 0) busyUntil[pick] = Math.max(busyUntil[pick], time + note.hold);
			}
			prevSrc = curSrc;
			prevDst = used;
			i = j;
		}
	}
}

/** Nota del chart mientras se convierte. */
@:allow(flux.keys.FluxKeysData)
class KeyNote
{
	public var note:Array<Dynamic>;
	public var time:Float = 0;
	public var hold:Float = 0;
	/** Carril original completo (con el lado), -1 si no es una nota normal. */
	public var lane:Int = -1;
	public var side:Int = 0;
	public var src:Int = 0;
	public var order:Int = 0;
	public var newLane:Int = -1;

	public function new(note:Array<Dynamic>, from:Int, order:Int)
	{
		this.note = note;
		this.order = order;
		if (note == null || note.length < 2) return;
		time = toFloat(note[0]);
		hold = note.length > 2 ? toFloat(note[2]) : 0;
		var rawLane:Dynamic = note[1];
		if (rawLane == null || !(Std.isOfType(rawLane, Int) || Std.isOfType(rawLane, Float))) return;
		var laneNum:Int = Std.int(rawLane);
		if (laneNum < 0) return;
		lane = laneNum;
		side = laneNum < from ? 0 : 1;
		src = laneNum % from;
	}

	static function toFloat(value:Dynamic):Float
	{
		if (value == null) return 0;
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
		{
			var f:Float = value;
			return Math.isNaN(f) ? 0 : f;
		}
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? 0 : parsed;
	}
}
