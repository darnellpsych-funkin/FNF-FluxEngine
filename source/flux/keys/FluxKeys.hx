package flux.keys;

import backend.Song.SwagSection;
import backend.Song.SwagSong;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import objects.Note;
import objects.StrumNote;

/**
 * Flux Engine: multi-keys (de 4 a 17 teclas).
 *
 * - En Gameplay Changers está la opción "Multi-Keys": "Chart" usa las teclas del chart y
 *   "4K"..."17K" convierte cualquier canción a esa cantidad de teclas (se elige con izquierda/derecha).
 * - Los charts que ya traen más teclas (`keyCount` o `mania` de Psych Extra Keys / Shaggy) se juegan tal cual.
 * - Las teclas se cambian en Opciones > Controles con Q/E.
 *
 * En 4K todo queda igual que en Psych: cada función devuelve lo mismo que el código original.
 * Los scripts pueden leer `FluxKeys.current` (o la variable `keyCount` en Lua).
 */
class FluxKeys
{
	/** Ruta (en images/) de la nota círculo del carril del centro. */
	public static inline var CIRCLE_SKIN:String = 'noteSkins/NOTE_circle';

	/** Ancho máximo (px) de los carriles de un lado. */
	public static var maxSideWidth:Float = 600;

	/** Teclas de la canción que se está jugando (4 fuera de las canciones). */
	public static var current(default, null):Int = 4;

	/** Teclas que trae el chart (antes de convertirlo). */
	public static var chartCount(default, null):Int = 4;

	/** Tamaño de las notas comparado con 4K (1 = igual). */
	public static var noteScale(default, null):Float = 1;

	/** Ancho de cada carril en píxeles. */
	public static var laneWidth(default, null):Float = 160 * 0.7;

	/** Corrimiento de los splashes para que queden centrados en receptores más chicos. */
	public static var splashShift(default, null):Float = 0;

	static var directions:Array<Int> = [0, 1, 2, 3];
	static var slots:Array<Int> = [0, 1, 2, 3];
	static var resetBlocked:Bool = false;
	static var circleCache:Map<String, String> = new Map();

	/** Cambia la cantidad de teclas (no hace falta llamarla a mano: PlayState lo hace al empezar). */
	public static function setKeys(keys:Int):Int
	{
		if (!FluxKeysData.isValid(keys)) keys = 4;
		current = keys;
		directions = FluxKeysData.layout(keys);
		slots = FluxKeysData.colorSlots(keys);
		laneWidth = (keys == 4) ? Note.swagWidth : Math.min(Note.swagWidth, maxSideWidth / keys);
		// con middlescroll el oponente se parte a los costados del jugador: que entren las dos mitades
		if (keys != 4 && ClientPrefs.data.middleScroll)
			laneWidth = Math.min(laneWidth, (FlxG.width - 40) / (keys + 2 * Math.ceil(keys / 2)));
		noteScale = laneWidth / Note.swagWidth;
		splashShift = (keys == 4) ? 0 : Note.swagWidth / 2 * (1 - noteScale);
		return keys;
	}

	/** Vuelve a 4K (al salir de la canción). */
	public static function reset():Void
	{
		setKeys(4);
		chartCount = 4;
		resetBlocked = false;
		circleCache.clear();
	}

	// ------------------------------------------------------------------
	// Canción
	// ------------------------------------------------------------------

	/** Teclas elegidas en Gameplay Changers (null = las del chart). */
	public static function wantedKeys():Null<Int>
	{
		var value:Dynamic = ClientPrefs.data.gameplaySettings.get('keycount');
		return FluxKeysData.parseSetting(value);
	}

	/** Lo llama PlayState al crearse: elige las teclas y devuelve los nombres de los controles. */
	public static function setupSong(song:SwagSong):Array<String>
	{
		circleCache.clear();
		chartCount = song != null ? FluxKeysData.chartKeys(song) : 4;
		var wanted:Null<Int> = wantedKeys();
		setKeys(wanted != null ? wanted : chartCount);
		if (current != 4 || chartCount != 4)
			trace('[Flux multi-keys] chart de ${chartCount}K, se juega en ${current}K');

		var names:Array<String> = bindNames(current);
		resetBlocked = false;
		var resetKeys:Array<FlxKey> = ClientPrefs.keyBinds.get('reset');
		if (resetKeys != null)
			for (name in names)
			{
				var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(name);
				if (keys != null)
					for (key in keys)
						if (key != FlxKey.NONE && resetKeys.contains(key)) resetBlocked = true;
			}
		return names;
	}

	/** Las secciones que se van a jugar: las del chart o una copia convertida a `current` teclas. */
	public static function prepareSections(song:SwagSong):Array<SwagSection>
	{
		if (song == null || song.notes == null) return [];
		if (chartCount == current) return song.notes;
		var start:Float = haxe.Timer.stamp();
		var result:Array<Dynamic> = FluxKeysData.convertSections(cast song.notes, chartCount, current);
		trace('[Flux multi-keys] chart convertido de ${chartCount}K a ${current}K en ${Math.round((haxe.Timer.stamp() - start) * 1000)} ms');
		return cast result;
	}

	/** Animaciones de canto por carril (el círculo usa singUP). */
	public static function singAnimations():Array<String>
		return [for (lane in 0...current) FluxKeysData.SING_ANIMATIONS[dirOf(lane)]];

	/** true si la tecla de reinicio (R) también es una nota: así no te mata al tocarla. */
	public static var blocksReset(get, never):Bool;

	static function get_blocksReset():Bool
		return resetBlocked;

	/** Retraso de la aparición de cada receptor (en 4K: 0.2 por receptor, como Psych). */
	public static function introDelay(lane:Int):Float
		return current <= 4 ? 0.2 * lane : 0.2 * lane * 4 / current;

	// ------------------------------------------------------------------
	// Carriles
	// ------------------------------------------------------------------

	/** Dirección del carril: 0 izquierda, 1 abajo, 2 arriba, 3 derecha, 4 centro. */
	public static function dirOf(lane:Int):Int
	{
		if (lane < 0) return 0;
		var dir:Null<Int> = directions[lane % current];
		return dir == null ? lane % 4 : dir;
	}

	/** Dirección 0-3 (el centro cuenta como arriba), para lo que solo entiende 4 direcciones. */
	public static function dir4(lane:Int):Int
	{
		var dir:Int = dirOf(lane);
		return dir == FluxKeysData.CENTER ? FluxKeysData.UP : dir;
	}

	/** Slot de color del carril (0-3 = colores del jugador). En 4K es `lane % 4`. */
	public static function colorSlot(lane:Int):Int
	{
		if (lane < 0) return lane;
		var slot:Null<Int> = slots[lane % current];
		return slot == null ? lane % 4 : slot;
	}

	/** Colores (relleno, brillo, borde) de un slot. */
	public static function slotColors(slot:Int, pixel:Bool):Array<FlxColor>
	{
		if (slot < 0) return null;
		if (slot < 4) return pixel ? ClientPrefs.data.arrowRGBPixel[slot] : ClientPrefs.data.arrowRGB[slot];
		var list:Array<Array<Int>> = pixel ? FluxKeysData.extraColorsPixel : FluxKeysData.extraColors;
		var colors:Array<Int> = list[slot - 4];
		return colors == null ? null : [for (c in colors) (c : FlxColor)];
	}

	/** Colores de un carril. En 4K es `ClientPrefs.data.arrowRGB[lane]`, como en Psych. */
	public static function laneColors(lane:Int, pixel:Bool):Array<FlxColor>
	{
		if (current == 4) return pixel ? ClientPrefs.data.arrowRGBPixel[lane] : ClientPrefs.data.arrowRGB[lane];
		return slotColors(colorSlot(lane), pixel);
	}

	/**
	 * Nombre de color de las animaciones de la nota ("purple", "blue", "green", "red" o "white" para el círculo).
	 * @param wrap como `colArray[noteData % 4]` de Psych; si no, como `colArray[noteData]` (null fuera de rango)
	 */
	public static function laneAnim(note:Note, wrap:Bool = false):String
	{
		var lane:Int = note.noteData;
		if (current == 4)
			return wrap ? (lane < 0 ? null : Note.colArray[lane % Note.colArray.length]) : Note.colArray[lane];
		if (lane < 0) return null;
		if (lane >= current)
		{
			if (!wrap) return null;
			lane = lane % current;
		}
		var dir:Int = dirOf(lane);
		if (dir == FluxKeysData.CENTER) return isCircle(note) ? 'white' : Note.colArray[FluxKeysData.UP];
		return Note.colArray[dir];
	}

	/** Columna del sprite pixel (en 4K es noteData, como en Psych). */
	public static function pixelColumn(note:Note):Int
	{
		if (current == 4) return note.noteData;
		var dir:Int = dirOf(note.noteData);
		if (dir == FluxKeysData.CENTER) return isCircle(note) ? 0 : FluxKeysData.UP;
		return dir;
	}

	/** Si la animación no existe (cambió la textura del círculo a una flecha), usa la equivalente. */
	public static function fixAnim(note:Note, name:String):String
	{
		if (current == 4 || name == null || note.animation.exists(name)) return name;
		var other:String = null;
		if (name.startsWith('white')) other = 'green' + name.substr(5);
		else if (name.startsWith('green')) other = 'white' + name.substr(5);
		return (other != null && note.animation.exists(other)) ? other : name;
	}

	/** Animaciones del receptor: 0-3 flechas, 4 círculo. En 4K es `noteData % 4`, como en Psych. */
	public static function strumDir(lane:Int, strum:FlxSprite):Int
	{
		if (current == 4) return Std.int(Math.abs(lane)) % 4;
		var dir:Int = dirOf(Std.int(Math.abs(lane)));
		if (dir == FluxKeysData.CENTER && !isCircle(strum)) return FluxKeysData.UP;
		return dir;
	}

	/** Animación del splash (0-3) para el carril. En 4K no cambia nada. */
	public static function splashDir(lane:Int):Int
	{
		if (current == 4 || lane < 0) return lane;
		return dir4(lane);
	}

	/**
	 * Textura del carril: el carril del centro usa la nota círculo si la hay
	 * (con la skin de Psych siempre; con otra skin, si existe `<skin>-circle.png`). Si no, la misma flecha.
	 */
	public static function laneSkin(skin:String, lane:Int):String
	{
		if (current == 4 || skin == null || lane < 0 || dirOf(lane) != FluxKeysData.CENTER) return skin;

		var key:String = (PlayState.isPixelStage ? 'pixel:' : '') + skin;
		var cached:String = circleCache.get(key);
		if (cached != null) return cached.length > 0 ? cached : skin;

		var circle:String = null;
		var folder:String = PlayState.isPixelStage ? 'images/pixelUI/' : 'images/';
		if (Paths.fileExists('$folder$skin-circle.png', IMAGE)) circle = '$skin-circle'; // la skin trae su propio círculo
		else if (skin.startsWith(Note.defaultNoteSkin) || skin.startsWith('NOTE_assets')) circle = CIRCLE_SKIN;
		circleCache.set(key, circle == null ? '' : circle);
		return circle != null ? circle : skin;
	}

	/** true si el sprite tiene cargada una textura de círculo. */
	public static function isCircle(sprite:FlxSprite):Bool
	{
		if (sprite == null || sprite.graphic == null || sprite.graphic.key == null) return false;
		var key:String = sprite.graphic.key;
		return key.indexOf('NOTE_circle') != -1 || key.indexOf('-circle.') != -1 || key.indexOf('-circleENDS') != -1;
	}

	/** Acomoda un receptor para `current` teclas (en 4K no hace nada). */
	public static function placeStrum(strum:StrumNote, lane:Int, player:Int):Void
	{
		if (current == 4 || strum == null) return;
		var keys:Int = current;
		var width:Float = laneWidth;
		var x:Float;
		if (!ClientPrefs.data.middleScroll)
		{
			// mismo centro que los 4 receptores de Psych
			var center:Float = PlayState.STRUM_X + 50 + Note.swagWidth * 2 + (FlxG.width / 2) * player;
			x = center - keys * width / 2 + lane * width;
		}
		else
		{
			var playerCenter:Float = PlayState.STRUM_X_MIDDLESCROLL + 50 + Note.swagWidth * 2 + FlxG.width / 2;
			if (player == 1)
				x = playerCenter - keys * width / 2 + lane * width;
			else
			{
				// el oponente se parte en dos, a los costados del jugador (como Psych)
				var playerLeft:Float = playerCenter - keys * width / 2;
				var playerRight:Float = playerCenter + keys * width / 2;
				var leftCenter:Float = PlayState.STRUM_X_MIDDLESCROLL + 50 + 310 + Note.swagWidth;
				var rightCenter:Float = leftCenter + FlxG.width / 2 + 25 + Note.swagWidth * 2;
				var leftCount:Int = Math.floor(keys / 2);
				var rightCount:Int = keys - leftCount;
				if (lane < leftCount)
				{
					var c:Float = Math.min(leftCenter, playerLeft - 10 - leftCount * width / 2);
					x = c - leftCount * width / 2 + lane * width;
				}
				else
				{
					var c:Float = Math.max(rightCenter, playerRight + 10 + rightCount * width / 2);
					x = c - rightCount * width / 2 + (lane - leftCount) * width;
				}
			}
		}
		strum.x = x;
		// receptores más chicos: misma línea del centro que en 4K
		strum.y += Note.swagWidth / 2 * (1 - noteScale);
	}

	// ------------------------------------------------------------------
	// Controles
	// ------------------------------------------------------------------

	/** Nombre del control de un carril (4K usa los de Psych: note_left, note_down...). */
	public static function bindName(keys:Int, lane:Int):String
	{
		if (keys == 4) return ['note_left', 'note_down', 'note_up', 'note_right'][lane];
		return 'note_${keys}k_$lane';
	}

	public static function bindNames(keys:Int):Array<String>
		return [for (lane in 0...keys) bindName(keys, lane)];

	/** Agrega los controles por defecto de 1 a 17 teclas (lo llama ClientPrefs.loadDefaultKeys). */
	public static function addDefaultBinds(keyboard:Map<String, Array<FlxKey>>, gamepad:Map<String, Array<FlxGamepadInputID>>):Void
	{
		for (keys in FluxKeysData.MIN_KEYS...FluxKeysData.MAX_KEYS + 1)
		{
			if (keys == 4) continue;
			var keyNames:Array<Array<String>> = FluxKeysData.defaultKeyNames(keys);
			var buttonNames:Array<Array<String>> = FluxKeysData.defaultButtonNames(keys);
			for (lane in 0...keys)
			{
				var name:String = bindName(keys, lane);
				if (keyboard != null && !keyboard.exists(name))
				{
					var list:Array<String> = lane < keyNames.length ? keyNames[lane] : [];
					keyboard.set(name, [for (k in list) FlxKey.fromString(k)]);
				}
				if (gamepad != null && !gamepad.exists(name) && lane < buttonNames.length)
					gamepad.set(name, [for (b in buttonNames[lane]) FlxGamepadInputID.fromString(b)]);
			}
		}
	}

	/** Vuelve a las teclas por defecto de una cantidad de teclas. */
	public static function resetBinds(keys:Int, controller:Null<Bool> = null):Void
	{
		for (name in bindNames(keys))
		{
			if (controller != true && ClientPrefs.defaultKeys != null && ClientPrefs.defaultKeys.exists(name))
				ClientPrefs.keyBinds.set(name, ClientPrefs.defaultKeys.get(name).copy());
			if (controller != false && ClientPrefs.defaultButtons != null && ClientPrefs.defaultButtons.exists(name))
				ClientPrefs.gamepadBinds.set(name, ClientPrefs.defaultButtons.get(name).copy());
		}
	}

	/** Lista para el menú de controles (mismo formato que ControlsSubState). */
	public static function controlOptions(keys:Int, resetLabel:String):Array<Dynamic>
	{
		var onGamepad:Bool = FluxKeysData.defaultButtonNames(keys).length > 0;
		var list:Array<Dynamic> = [[true, '$keys KEYS']];
		for (lane in 0...keys)
		{
			var name:String = FluxKeysData.laneName(keys, lane);
			list.push([onGamepad, name, bindName(keys, lane), '${keys}K $name']);
		}
		list.push([true]);
		list.push([true]);
		list.push([true, resetLabel]);
		return list;
	}
}
