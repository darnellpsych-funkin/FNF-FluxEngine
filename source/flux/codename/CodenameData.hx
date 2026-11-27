package flux.codename;

import haxe.xml.Access;

using StringTools;

/**
 * Flux Engine: lectura de los archivos de Codename Engine (XML de personajes, escenarios y
 * semanas, y eventos de los charts). No usa Flixel, así se puede probar aparte.
 */
class CodenameData
{
	// ------------------------------------------------------------------
	// Utilidades
	// ------------------------------------------------------------------

	public static function parse(text:String):Access
	{
		if (text == null) return null;
		try
		{
			var xml:Xml = Xml.parse(text).firstElement();
			return xml != null ? new Access(xml) : null;
		}
		catch (e:Dynamic)
		{
			trace('[Flux Codename] XML inválido: $e');
			return null;
		}
	}

	/** "1..3,5,9..7" -> [1, 2, 3, 5, 9, 8, 7] (como CoolUtil.parseNumberRange de Codename). */
	public static function parseRange(text:String):Array<Int>
	{
		var result:Array<Int> = [];
		if (text == null) return result;
		for (part in text.split(','))
		{
			part = part.trim();
			var idx:Int = part.indexOf('..');
			if (idx != -1)
			{
				var start:Null<Int> = Std.parseInt(part.substring(0, idx).trim());
				var end:Null<Int> = Std.parseInt(part.substring(idx + 2).trim());
				if (start == null || end == null) continue;
				if (start <= end) for (j in start...end + 1) result.push(j);
				else
				{
					var j:Int = start;
					while (j >= end) result.push(j--);
				}
			}
			else
			{
				var num:Null<Int> = Std.parseInt(part);
				if (num != null) result.push(num);
			}
		}
		return result;
	}

	public static function att(node:Access, name:String):String
		return (node != null && node.x.exists(name)) ? node.x.get(name) : null;

	public static function float(node:Access, name:String, ?fallback:Null<Float>):Null<Float>
	{
		var text:String = att(node, name);
		if (text == null) return fallback;
		var value:Float = Std.parseFloat(text.trim());
		return Math.isNaN(value) ? fallback : value;
	}

	public static function int(node:Access, name:String, ?fallback:Null<Int>):Null<Int>
	{
		var text:String = att(node, name);
		if (text == null) return fallback;
		var value:Null<Int> = Std.parseInt(text.trim());
		return value == null ? fallback : value;
	}

	public static function bool(node:Access, name:String, ?fallback:Null<Bool>):Null<Bool>
	{
		var text:String = att(node, name);
		if (text == null) return fallback;
		return text.trim().toLowerCase() == 'true';
	}

	/** Color de Codename ("#RRGGBB", "0xAARRGGBB", "RRGGBB") a [r, g, b]; null si no se entiende. */
	public static function rgb(text:String):Array<Int>
	{
		if (text == null) return null;
		var hex:String = text.trim();
		if (hex.startsWith('#')) hex = hex.substr(1);
		else if (hex.toLowerCase().startsWith('0x')) hex = hex.substr(2);
		if (hex.length == 8) hex = hex.substr(2); // sin el alfa
		if (hex.length != 6) return null;
		var value:Null<Int> = Std.parseInt('0x$hex');
		return value == null ? null : [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
	}

	// ------------------------------------------------------------------
	// Personajes (data/characters/<nombre>.xml)
	// ------------------------------------------------------------------

	/**
	 * Personaje de Codename a un JSON de personaje de Psych.
	 *
	 * En Codename los offsets de las animaciones están en píxeles del sprite (se escalan con él)
	 * y `x`/`y` del personaje corren al personaje: en Psych son los offsets por la escala y la
	 * `position`. Si el personaje se usa del otro lado (un oponente como jugador), Codename
	 * cambia singLEFT por singRIGHT y da vuelta los offsets: se hace lo mismo.
	 *
	 * Devuelve {json, interval, gameOverChar, centerCam, xmlIsPlayer} o null.
	 */
	public static function character(xml:Access, name:String, isPlayer:Bool):Dynamic
	{
		if (xml == null) return null;
		var scale:Float = float(xml, 'scale', 1);
		var xmlIsPlayer:Bool = bool(xml, 'isPlayer', false);
		var swapped:Bool = (isPlayer != xmlIsPlayer);
		var gx:Float = float(xml, 'x', 0);
		var gy:Float = float(xml, 'y', 0);
		var camx:Float = float(xml, 'camx', 0);
		var camy:Float = float(xml, 'camy', 0);
		var defaultFps:Float = float(xml, 'defFps', 24);

		var anims:Array<Dynamic> = [];
		for (node in xml.elements)
		{
			if (node.name != 'anim') continue;
			var animName:String = att(node, 'name');
			if (animName == null) continue;
			var ox:Float = float(node, 'x', 0) * scale;
			var oy:Float = float(node, 'y', 0) * scale;
			if (swapped) ox = -ox;
			var anim:Dynamic = {
				anim: animName,
				name: att(node, 'anim') != null ? att(node, 'anim') : '',
				fps: Std.int(float(node, 'fps', defaultFps)),
				loop: bool(node, 'loop', false),
				indices: parseRange(att(node, 'indices')),
				offsets: [ox, oy]
			};
			anims.push(anim);
		}
		if (swapped) swapLeftRight(anims);

		var color:Array<Int> = rgb(att(xml, 'color'));
		var sprite:String = att(xml, 'sprite') != null ? att(xml, 'sprite') : name;
		var json:Dynamic = {
			animations: anims,
			image: 'characters/$sprite',
			scale: scale,
			sing_duration: float(xml, 'holdTime', 4),
			healthicon: att(xml, 'icon') != null ? att(xml, 'icon') : name,
			position: [swapped ? -gx : gx, gy],
			// Psych resta la x de la cámara para el jugador; Codename la suma siempre
			camera_position: [isPlayer ? -camx : camx, camy],
			flip_x: bool(xml, 'flipX', false),
			no_antialiasing: bool(xml, 'antialiasing', true) == false,
			healthbar_colors: color != null ? color : [161, 161, 161],
			vocals_file: null,
			_editor_isPlayer: xmlIsPlayer
		};
		return {
			json: json,
			interval: int(xml, 'interval'),
			gameOverChar: att(xml, 'gameOverChar'),
			centerCam: bool(xml, 'centercam', true),
			xmlIsPlayer: xmlIsPlayer
		};
	}

	/** Cambia singLEFT* por singRIGHT* (y al revés), como swapLeftRightAnimations de Codename. */
	static function swapLeftRight(anims:Array<Dynamic>):Void
	{
		for (anim in anims)
		{
			var name:String = anim.anim;
			if (name.startsWith('singLEFT')) anim.anim = 'singRIGHT' + name.substr(8);
			else if (name.startsWith('singRIGHT')) anim.anim = 'singLEFT' + name.substr(9);
		}
	}

	// ------------------------------------------------------------------
	// Escenarios (data/stages/<nombre>.xml)
	// ------------------------------------------------------------------

	/**
	 * Escenario de Codename: {zoom, startCamX, startCamY, nodes}. Cada nodo:
	 * - kind: "sprite", "box", "boyfriend", "girlfriend" o "dad"
	 * - lo demás según el tipo (x, y, sprite, scroll, scale, anims, beat...)
	 * Los de `high-memory`/`low-memory` traen `quality` = "high" / "low".
	 */
	public static function stage(xml:Access):Dynamic
	{
		if (xml == null) return null;
		var folder:String = att(xml, 'folder') != null ? att(xml, 'folder') : '';
		if (folder.length > 0 && !folder.endsWith('/')) folder += '/';

		var nodes:Array<Dynamic> = [];
		for (node in xml.elements)
		{
			switch (node.name)
			{
				case 'high-memory', 'low-memory':
					var quality:String = node.name == 'high-memory' ? 'high' : 'low';
					for (child in node.elements) pushStageNode(nodes, child, folder, quality);
				default:
					pushStageNode(nodes, node, folder, null);
			}
		}

		// Codename agrega al final las posiciones de personaje que faltan
		for (role in ['girlfriend', 'dad', 'boyfriend'])
		{
			var found:Bool = false;
			for (n in nodes) if (n.kind == role) found = true;
			if (!found) nodes.push(charNode(role, null));
		}

		return {
			zoom: float(xml, 'zoom', 1.05),
			startCamX: float(xml, 'startCamPosX'),
			startCamY: float(xml, 'startCamPosY'),
			name: att(xml, 'name'),
			nodes: nodes
		};
	}

	static function pushStageNode(nodes:Array<Dynamic>, node:Access, folder:String, quality:String):Void
	{
		var result:Dynamic = switch (node.name)
		{
			case 'sprite', 'spr', 'sparrow':
				if (att(node, 'sprite') == null || att(node, 'name') == null) null;
				else spriteNode(node, folder);
			case 'box', 'solid':
				if (att(node, 'name') == null || att(node, 'width') == null || att(node, 'height') == null) null;
				else {
					kind: 'box',
					name: att(node, 'name'),
					x: float(node, 'x', 0),
					y: float(node, 'y', 0),
					width: float(node, 'width', 1),
					height: float(node, 'height', 1),
					color: att(node, 'color'),
					scrollX: scrollOf(node, 'x'),
					scrollY: scrollOf(node, 'y'),
					alpha: float(node, 'alpha'),
					properties: propertiesOf(node)
				};
			case 'boyfriend', 'bf', 'player':
				charNode('boyfriend', node);
			case 'girlfriend', 'gf':
				charNode('girlfriend', node);
			case 'dad', 'opponent':
				charNode('dad', node);
			default:
				null; // ratings, use-extension, character extra...: más adelante
		}
		if (result != null)
		{
			result.quality = quality;
			nodes.push(result);
		}
	}

	static function spriteNode(node:Access, folder:String):Dynamic
	{
		var anims:Array<Dynamic> = [];
		for (child in node.elements)
		{
			if (child.name != 'anim' || att(child, 'name') == null) continue;
			anims.push({
				name: att(child, 'name'),
				prefix: att(child, 'anim'),
				fps: float(child, 'fps', 24),
				loop: bool(child, 'loop', false),
				indices: parseRange(att(child, 'indices')),
				x: float(child, 'x', 0),
				y: float(child, 'y', 0),
				forced: bool(child, 'forced')
			});
		}
		var type:String = att(node, 'type') != null ? att(node, 'type').toLowerCase() : 'loop';
		var interval:Null<Int> = int(node, 'beatInterval');
		if (interval == null) interval = int(node, 'interval', 2);
		return {
			kind: 'sprite',
			name: att(node, 'name'),
			sprite: folder + att(node, 'sprite'),
			x: float(node, 'x', 0),
			y: float(node, 'y', 0),
			scrollX: scrollOf(node, 'x'),
			scrollY: scrollOf(node, 'y'),
			scaleX: scaleOf(node, 'x'),
			scaleY: scaleOf(node, 'y'),
			graphicSize: int(node, 'graphicSize'),
			alpha: float(node, 'alpha'),
			angle: float(node, 'angle'),
			color: att(node, 'color'),
			blend: att(node, 'blend'),
			flipX: bool(node, 'flipX'),
			flipY: bool(node, 'flipY'),
			antialiasing: bool(node, 'antialiasing', true),
			updateHitbox: bool(node, 'updateHitbox', false),
			animType: (type == 'beat' || type == 'onbeat') ? 'beat' : (type == 'none' ? 'none' : 'loop'),
			beatInterval: interval < 1 ? 1 : interval,
			beatOffset: int(node, 'beatOffset', 0),
			skipNegativeBeats: bool(node, 'playOnCountdown', false),
			anims: anims,
			properties: propertiesOf(node)
		};
	}

	/** Posición de personaje (StageCharPos de Codename) con los valores por defecto. */
	static function charNode(role:String, node:Access):Dynamic
	{
		var defaults:Array<Float> = switch (role)
		{
			case 'boyfriend': [770, 100, 1];
			case 'girlfriend': [400, 130, 0.95];
			default: [100, 100, 1];
		}
		var scroll:Null<Float> = float(node, 'scroll');
		return {
			kind: role,
			x: float(node, 'x', defaults[0]),
			y: float(node, 'y', defaults[1]),
			scrollX: float(node, 'scrollx', scroll != null ? scroll : defaults[2]),
			scrollY: float(node, 'scrolly', scroll != null ? scroll : defaults[2]),
			camX: float(node, 'camxoffset', 0),
			camY: float(node, 'camyoffset', 0),
			alpha: float(node, 'alpha'),
			angle: float(node, 'angle'),
			flipX: (node != null && (node.has.flip || node.has.flipX)) ? (att(node, 'flip') == 'true' || att(node, 'flipX') == 'true') : null,
			scale: float(node, 'scale')
		};
	}

	static function scrollOf(node:Access, axis:String):Float
	{
		var specific:Null<Float> = float(node, 'scroll$axis');
		if (specific != null) return specific;
		return float(node, 'scroll', 1);
	}

	static function scaleOf(node:Access, axis:String):Float
	{
		var specific:Null<Float> = float(node, 'scale$axis');
		if (specific != null) return specific;
		return float(node, 'scale', 1);
	}

	/** <property name="alpha" type="float" value="0.5"/> */
	static function propertiesOf(node:Access):Array<Dynamic>
	{
		var list:Array<Dynamic> = [];
		for (child in node.elements)
			if (child.name == 'property' && att(child, 'name') != null)
				list.push({name: att(child, 'name'), type: att(child, 'type'), value: att(child, 'value')});
		return list;
	}

	/** Valor de una <property> según su tipo (float, int, bool, color, string). */
	public static function propertyValue(type:String, value:String):Dynamic
	{
		if (value == null) return null;
		return switch (type != null ? type.toLowerCase() : 'string')
		{
			case 'float', 'number', 'f': Std.parseFloat(value);
			case 'int', 'integer', 'i': Std.parseInt(value);
			case 'bool', 'boolean', 'b': value.trim().toLowerCase() == 'true';
			case 'color', 'c':
				var c:Array<Int> = rgb(value);
				c == null ? value : (0xFF000000 | (c[0] << 16) | (c[1] << 8) | c[2]);
			default: value;
		}
	}

	// ------------------------------------------------------------------
	// Semanas (data/weeks/weeks/<semana>.xml)
	// ------------------------------------------------------------------

	/** {name, sprite, chars, songs: [{name, hide, displayName}], difficulties} o null. */
	public static function week(xml:Access, id:String):Dynamic
	{
		if (xml == null) return null;
		var songs:Array<Dynamic> = [];
		for (node in xml.elements)
		{
			if (node.name != 'song') continue;
			var name:String = node.innerData != null ? node.innerData.trim() : '';
			if (name.length == 0) continue;
			songs.push({name: name, hide: bool(node, 'hide', false), displayName: att(node, 'displayName')});
		}
		if (songs.length == 0) return null;

		var diffs:Array<String> = [];
		for (node in xml.elements)
			if (node.name == 'difficulty' && att(node, 'name') != null) diffs.push(att(node, 'name'));
		if (diffs.length == 0) diffs = ['easy', 'normal', 'hard'];

		var chars:Array<String> = [];
		if (att(xml, 'chars') != null)
			for (c in att(xml, 'chars').split(','))
			{
				var trimmed:String = c.trim();
				chars.push((trimmed == '' || trimmed == 'none' || trimmed == 'null') ? '' : trimmed);
			}

		return {
			name: att(xml, 'name') != null ? att(xml, 'name') : id,
			sprite: att(xml, 'sprite') != null ? att(xml, 'sprite') : id,
			chars: chars,
			songs: songs,
			difficulties: diffs
		};
	}

	// ------------------------------------------------------------------
	// Eventos de los charts
	// ------------------------------------------------------------------

	/**
	 * Eventos de Codename (del chart y de events.json) a eventos de Psych:
	 * - "Add Camera Zoom" y "Camera Bop" -> "Add Camera Zoom"
	 * - "Play Animation" -> "Play Animation"; "Character Change" -> "Change Character"
	 * - "Scroll Speed Change" -> "Change Scroll Speed"; "Camera Position" -> "Camera Follow Pos"
	 *   (y se suelta en el próximo "Camera Movement")
	 * - "Camera Zoom", "Camera Flash", "Camera Modulo Change", "HScript Call" y
	 *   "Alt Animation Toggle" quedan con su nombre y todos los parámetros en JSON (los hace Flux)
	 * - "Camera Movement" y "BPM Change" ya los pasa Moonchart a las secciones; "Time Signature Change" no se usa
	 * - los demás (eventos de scripts) quedan con su nombre y los dos primeros parámetros
	 *
	 * @param lines las strumLines del chart (para saber de quién es cada una)
	 * @param speed velocidad del chart; @param bpm el bpm (para pasar steps a segundos)
	 * @return {events: eventos de Psych, alt: [{time, line, enabled}]}
	 */
	public static function events(list:Array<Dynamic>, lines:Array<Dynamic>, speed:Float, bpm:Float):Dynamic
	{
		var result:Array<Dynamic> = [];
		var alt:Array<Dynamic> = [];
		if (list == null) return {events: result, alt: alt};

		var sorted:Array<Dynamic> = list.copy();
		sorted.sort((a, b) -> {
			var ta:Float = timeOf(a);
			var tb:Float = timeOf(b);
			return ta < tb ? -1 : (ta > tb ? 1 : 0);
		});

		var stepSeconds:Float = (bpm > 0 ? 60 / bpm / 4 : 0.15);
		var forcedCamera:Bool = false;
		for (event in sorted)
		{
			var name:String = event.name != null ? Std.string(event.name) : '';
			var params:Array<Dynamic> = Std.isOfType(event.params, Array) ? event.params : [];
			var time:Float = timeOf(event);
			inline function push(eventName:String, value1:Dynamic, value2:Dynamic)
				result.push([time, [[eventName, value1 == null ? '' : Std.string(value1), value2 == null ? '' : Std.string(value2)]]]);

			switch (name)
			{
				case 'Camera Movement':
					if (forcedCamera)
					{
						push('Camera Follow Pos', '', '');
						forcedCamera = false;
					}
				case 'BPM Change', 'Time Signature Change', 'Unknown':
					// las secciones y los BPM ya los arma Moonchart
				case 'Add Camera Zoom':
					var amount:Dynamic = params.length > 0 ? params[0] : 0.015;
					if (params.length > 1 && params[1] == 'camHUD') push('Add Camera Zoom', 0, amount);
					else push('Add Camera Zoom', amount, 0);
				case 'Camera Bop':
					var amount:Dynamic = params.length > 0 ? params[0] : 0.015;
					push('Add Camera Zoom', amount, amount);
				case 'Play Animation':
					push('Play Animation', params.length > 1 ? params[1] : 'hey', roleOf(lines, params.length > 0 ? params[0] : 0));
				case 'Character Change':
					if (params.length > 2 && toInt(params[1]) == 0) // solo el primer personaje de la strumLine
						push('Change Character', roleOf(lines, params[0]), params[2]);
				case 'Scroll Speed Change':
					var target:Float = params.length > 1 ? toFloat(params[1], 1) : 1;
					var multiply:Bool = params.length > 5 && params[5] == true;
					var value:Float = multiply || speed <= 0 ? target : target / speed;
					var tween:Bool = params.length > 0 && params[0] == true;
					var seconds:Float = tween ? toFloat(params.length > 2 ? params[2] : 4, 4) * stepSeconds : 0;
					push('Change Scroll Speed', value, seconds);
				case 'Camera Position':
					forcedCamera = true;
					push('Camera Follow Pos', params.length > 0 ? params[0] : 0, params.length > 1 ? params[1] : 0);
				case 'Alt Animation Toggle':
					alt.push({time: time, line: toInt(params.length > 2 ? params[2] : 0), enabled: params.length > 0 && params[0] == true});
					// valor 2: de quién es la strumLine ("dad", "bf" o "gf"), para el idle -alt
					result.push([time, [[name, haxe.Json.stringify(params), roleOf(lines, params.length > 2 ? params[2] : 0)]]]);
				case 'Camera Zoom', 'Camera Flash', 'Camera Modulo Change', 'HScript Call':
					result.push([time, [[name, haxe.Json.stringify(params), '']]]);
				default:
					push(name, params.length > 0 ? params[0] : null, params.length > 1 ? params[1] : null);
			}
		}
		return {events: result, alt: alt};
	}

	/** "dad", "bf" o "gf" según la posición de la strumLine de Codename. */
	public static function roleOf(lines:Array<Dynamic>, index:Dynamic):String
	{
		var i:Int = toInt(index);
		var line:Dynamic = (lines != null && i >= 0 && i < lines.length) ? lines[i] : null;
		var position:String = line != null && line.position != null ? Std.string(line.position) : null;
		if (position == null && line != null && line.type != null)
			position = switch (toInt(line.type)) { case 1: 'boyfriend'; case 2: 'girlfriend'; default: 'dad'; }
		if (position == null) position = switch (i) { case 1: 'boyfriend'; case 2: 'girlfriend'; default: 'dad'; }
		return switch (position)
		{
			case 'boyfriend', 'bf', 'player': 'bf';
			case 'girlfriend', 'gf': 'gf';
			default: 'dad';
		}
	}

	static function timeOf(event:Dynamic):Float
		return event != null ? toFloat(event.time, 0) : 0;

	static function toFloat(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return value;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function toInt(value:Dynamic):Int
		return Std.int(toFloat(value, 0));
}
