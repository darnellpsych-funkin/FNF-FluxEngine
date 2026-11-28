package flux.dave.api;

#if FLUX_DAVE_SCRIPTS
import flixel.FlxCamera;
import flixel.animation.FlxAnimationController;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flux.dave.DaveCharacters;
import flux.dave.DaveData;
import flux.dave.api.DaveApi;
import objects.Character;

using StringTools;

/**
 * El `Character` de Dave Engine (VS Dave and Bambi) para los scripts de personajes
 * (scripts/characters/<id>.hxc: `class DaveCharacter extends Character`).
 *
 * No es un sprite: lo del sprite (frames, animation, x, y, visible, flipX...) va al
 * personaje de Psych (`target`), que es el que está en el juego. Lo de Dave (skins,
 * danceTypes, altDanceSuffix, offsets, cómo baila...) vive acá. Los scripts pueden
 * cambiar load(), update(), onCreate(), playDanceAnimation()... como en Dave.
 */
@:keep
class DaveCharacter
{
	/** El personaje de Psych que va a usar el script que se está creando (lo pone DaveCharacters). */
	public static var pendingTarget:Character = null;

	public var id(default, null):String;

	/** El personaje de Psych (el sprite que está en el juego). */
	public var target(default, null):Character;

	/** El JSON de Dave (data/characters/<id>.json). */
	public var _data:Dynamic;

	/** La clase del .hxc (para los mensajes de error). */
	public var scriptClass:String = null;

	/** El intérprete del script (ver unsuper). */
	public var scriptInterp:rulescript.RuleScriptInterp = null;

	// ----- Datos de Dave -----
	public var skins:Map<String, String> = new Map<String, String>();
	public var danceTypes:Array<String> = ['idle'];
	public var altDanceSuffix:String = '';
	public var altSingSuffix:String = '';
	public var canDance:Bool = true;
	public var canSing:Bool = true;
	public var danceSnap:Int = 2;
	public var singDuration:Float = 4;
	public var globalOffset:Array<Float> = [0, 0];
	public var cameraOffset:Array<Float> = [0, 0];
	public var characterColor:FlxColor = FlxColor.WHITE;
	public var countdownGraphicType:String = 'normal';
	public var countdownSoundType:String = 'default';
	public var nativelyPlayable:Bool = false;
	public var startsCountdown:Bool = false;
	public var isDead:Bool = false;

	/** PLAYER, OPPONENT, GF u OTHER (CharacterType). */
	public var characterType:String = 'OTHER';

	public var baseScale:Float = 1;
	public var offsetScale:Float = 1;
	public var scaleOffset(default, null):FlxPoint = FlxPoint.get();

	/** Los offsets de Dave por animación, sin escalar (Psych usa los animOffsets del personaje). */
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

	public var sheetsInUse(default, null):Array<Dynamic> = [];

	/** Animaciones de canto que Flux dio vuelta (LEFT <-> RIGHT): nombre que se toca -> nombre original. */
	public var swappedAnims(default, null):Map<String, String> = new Map<String, String>();

	/** Esperando que termine 'cheer' para volver a bailar (playComboAnimation). */
	public var waitingCheer:Bool = false;

	/** Si el script tiene su propio update() (Flux lo llama cada cuadro solo en ese caso). */
	public var scriptedUpdate:Bool = false;

	public var characterName(get, never):String;
	public var characterIcon(get, never):String;
	public var cameraFocusPoint(get, never):FlxPoint;

	public function new(id:String)
	{
		this.id = id;
		target = pendingTarget;
		_data = DaveCharacters.readData(id);
		if (_data != null)
		{
			globalOffset = DaveCharacters.pair(_data.globalOffset);
			cameraOffset = DaveCharacters.pair(_data.cameraOffsets);
			danceSnap = Std.int(Math.max(1, DaveData.num(_data.danceSnap, 2)));
			singDuration = DaveData.num(_data.singDuration, 4);
			var rgb:Array<Int> = DaveData.rgb(_data.color);
			if (rgb != null)
				characterColor = FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]);
			if (_data.countdownData != null)
			{
				if (_data.countdownData.graphicPath != null)
					countdownGraphicType = Std.string(_data.countdownData.graphicPath);
				if (_data.countdownData.soundPath != null)
					countdownSoundType = Std.string(_data.countdownData.soundPath);
			}
			nativelyPlayable = _data.nativelyPlayable == true;
		}
		skins.set('normal', id);
		skins.set('gfSkin', 'gf-none');
		skins.set('noteSkin', 'normal');
		skins.set('deathSkin', 'generic-death');
	}

	/** Character.create de Dave: un personaje nuevo del juego (de Dave o de Psych). */
	public static function create(x:Float = 0, y:Float = 0, id:String, ?characterType:String):Character
	{
		var char:Character = new Character(x, y, id, characterType == DaveCharacterType.PLAYER);
		if (char.daveScript != null && characterType != null)
			char.daveScript.characterType = characterType;
		return char;
	}

	/**
	 * RuleScript marca "super" mientras corre `super.onCreate(e)` del script, y entonces lo
	 * que esa función llama (load(), playDanceAnimation()...) usaría la versión base en vez
	 * de la del script. Las funciones base que llaman a otras lo desmarcan primero.
	 */
	inline function unsuper():Void
	{
		if (scriptInterp != null)
			scriptInterp.isSuperCall = false;
	}

	// ----- Lo de Dave -----

	/** Lo llama Flux al crear el personaje: load(), la escala del JSON y el jugador mirando para el otro lado. */
	public function onCreate(event:Dynamic):Void
	{
		unsuper();
		load();
		var scale:Float = _data != null ? DaveData.num(_data.scale, 1) : 1;
		setScale(scale, scale);
		baseScale = scale;
		if (target != null)
		{
			target.jsonScale = scale;
			target.updateHitbox();
		}
		if (characterType == DaveCharacterType.PLAYER)
			flipX = !flipX;
		refreshOffsets();
	}

	/** El script carga acá el sprite: frames, animaciones, skins... */
	function load():Void {}

	/** Cada cuadro (el script la cambia para moverse, etc.). El sprite lo actualiza Psych. */
	public function update(elapsed:Float):Void {}

	public function dance(force:Bool = false):Void
	{
		unsuper();
		if (!canDance || target == null)
			return;
		if (!force)
		{
			var current:String = currentAnimation();
			if (hasEase(current))
				return;
			if (isSinging())
				return;
			if (!isSingAnimation(current) && !isDanceAnimation(current) && !isAnimationFinished())
				return;
		}
		playDanceAnimation(force);
	}

	public function playDanceAnimation(force:Bool = false):Void
	{
		unsuper();
		if (danceTypes != null && danceTypes.contains('alternate'))
		{
			danced = !danced;
			playAnim(danced ? 'danceRight' : 'danceLeft', true);
		}
		else
			playAnim('idle', true);
	}

	/** Los sufijos (altDanceSuffix / altSingSuffix) y canDance / canSing los pone Psych en su playAnim. */
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void
	{
		if (target != null && name != null)
			target.playAnim(name, force, reversed, frame);
	}

	/** Canta para una dirección (0-3). Flux ya dio vuelta LEFT/RIGHT cuando el personaje mira al revés. */
	public function sing(direction:Int, miss:Bool = false, ?alt:String, ?singArray:Array<String>):Void
	{
		unsuper();
		if (singArray == null || singArray.length == 0)
			singArray = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
		var note:String = singArray[Std.int(Math.abs(direction)) % singArray.length];
		if (miss)
			note += 'miss';
		if (target != null)
			target.holdTimer = 0;
		playAnim('sing' + note + (alt != null ? alt : ''), true);
	}

	public function playLoopingAnimation(?name:String, force:Bool = true):Void
	{
		unsuper();
		if (name == null)
			name = currentAnimation();
		var base:String = fetchBaseAnimationName(name);
		if (hasAnimation(base + '-loop'))
			playAnim(base + '-loop', force);
	}

	public function playComboAnimation(combo:Int):Void
	{
		unsuper();
		if (combo % 100 == 0 && hasAnimation('cheer'))
		{
			canDance = false;
			playAnim('cheer', true);
			waitingCheer = true;
		}
	}

	public function fetchBaseAnimationName(name:String):String
	{
		if (name == null)
			return '';
		for (suffix in ['-loop', '-ease'])
			if (name.contains(suffix))
				name = name.substring(0, name.lastIndexOf(suffix));
		return name;
	}

	public function hasEase(?name:String):Bool
	{
		if (name == null)
			name = currentAnimation();
		return hasAnimation(name + '-ease');
	}

	public function hasLoopAnimation(?name:String):Bool
	{
		if (name == null)
			name = currentAnimation();
		return hasAnimation(fetchBaseAnimationName(name) + '-loop');
	}

	public function isSinging():Bool
		return isSingAnimation(currentAnimation());

	public function isDancing():Bool
		return isDanceAnimation(currentAnimation());

	public function isSingAnimation(?name:String):Bool
		return name != null && name.startsWith('sing');

	public function isDanceAnimation(?name:String):Bool
		return name != null && (name.startsWith('idle') || name.startsWith('dance'));

	public function isLoopAnimation(?name:String):Bool
	{
		if (name == null)
			name = currentAnimation();
		return name.endsWith('-loop');
	}

	public function isEaseAnimation(?name:String):Bool
	{
		if (name == null)
			name = currentAnimation();
		return name.endsWith('-ease');
	}

	/** Escala relativa a la del JSON (setScale de Dave): recalcula el hitbox y los offsets. */
	public function setScale(x:Float, y:Float):Void
	{
		unsuper();
		if (target == null)
			return;
		target.scale.set(baseScale * x, baseScale * y);
		target.width = Math.abs(baseScale * x) * target.frameWidth;
		target.height = Math.abs(baseScale * y) * target.frameHeight;
		scaleOffset.set(-0.5 * (target.width - target.frameWidth), -0.5 * (target.height - target.frameHeight));
		refreshOffsets();
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		unsuper();
		animOffsets.set(name, [x, y]);
		refreshOffsets();
	}

	/** data/offsets/<nombre>.txt ("anim x y" por línea). */
	public function loadOffsetFile(character:String):Void
	{
		unsuper();
		if (character == null)
			return;
		for (name => offset in DaveCharacters.readOffsets(character, scriptClass))
			animOffsets.set(name, offset);
		refreshOffsets();
	}

	/**
	 * Agrega otro atlas (Sparrow) con más animaciones al personaje.
	 * `animations`: [{name: 'singLEFT-alt', prefix: 'alt-left'}, ...]
	 */
	public function addCharAtlas(path:String, animations:Array<Dynamic>, ?offsetFile:String):Void
	{
		unsuper();
		if (target == null)
			return;
		var atlas:FlxAtlasFrames = Std.downcast(DavePaths.getSparrowAtlas(path), FlxAtlasFrames);
		var current:FlxAtlasFrames = Std.downcast(target.frames, FlxAtlasFrames);
		if (atlas != null)
		{
			if (current == null)
				target.frames = atlas;
			else if (current != atlas)
				current.addAtlas(atlas); // sin volver a poner frames: eso borraría las animaciones
		}
		if (animations != null)
			for (anim in animations)
				DaveAnimation.addToSprite(target, anim);
		if (offsetFile != null)
			loadOffsetFile(offsetFile);
		sheetsInUse.push({path: path, anims: animations, offsetFile: offsetFile});
		refreshOffsets();
	}

	/** Pasa los offsets de Dave (escalados y con el de la escala) a todas las animaciones del personaje de Psych. */
	public function refreshOffsets():Void
	{
		if (target == null || target.animation == null || target.animOffsets == null)
			return;
		for (name in target.animation.getNameList())
		{
			var original:String = swappedAnims.exists(name) ? swappedAnims.get(name) : name;
			var offset:Array<Float> = animOffsets.get(original);
			var x:Float = offset != null ? offset[0] * offsetScale : 0;
			var y:Float = offset != null ? offset[1] * offsetScale : 0;
			target.animOffsets.set(name, [x + scaleOffset.x, y + scaleOffset.y]);
		}
	}

	/** En Flux la cámara la calcula PlayState con cameraPosition (ver DaveCharacters.load). */
	public function resetCameraFocusPoint():Void {}

	public function reposition():Void
	{
		if (target == null)
			return;
		target.x += globalOffset.length > 0 ? globalOffset[0] : 0;
		target.y += globalOffset.length > 1 ? globalOffset[1] : 0;
	}

	public function flip():Void
	{
		unsuper();
		flipX = !flipX;
		nativelyPlayable = !nativelyPlayable;
	}

	public function hasAnimation(name:String):Bool
		return target != null && target.animation != null && name != null && target.animation.exists(name);

	public function isAnimationFinished():Bool
		return target != null && target.animation != null && target.animation.curAnim != null && target.animation.curAnim.finished;

	inline function currentAnimation():String
	{
		var anim:FlxAnimationController = target != null ? target.animation : null;
		return (anim != null && anim.curAnim != null) ? anim.curAnim.name : '';
	}

	function get_characterName():String
		return (_data != null && _data.name != null) ? Std.string(_data.name) : 'Unknown';

	function get_characterIcon():String
		return (_data != null && _data.icon != null) ? Std.string(_data.icon) : id;

	function get_cameraFocusPoint():FlxPoint
	{
		if (target == null)
			return FlxPoint.get();
		var point:FlxPoint = target.getMidpoint();
		point.add(cameraOffset.length > 0 ? cameraOffset[0] : 0, cameraOffset.length > 1 ? cameraOffset[1] : 0);
		var stage:flux.dave.FluxDaveStage = flux.dave.FluxDaveStage.current;
		if (stage != null)
		{
			var offsets:Array<Float> = stage.cameraOffsetsOf(characterType);
			point.add(offsets[0], offsets[1]);
		}
		return point;
	}

	// ----- Lo del sprite (va al personaje de Psych) -----

	public var frames(get, set):FlxFramesCollection;
	public var animation(get, never):FlxAnimationController;
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var width(get, set):Float;
	public var height(get, set):Float;
	public var alpha(get, set):Float;
	public var angle(get, set):Float;
	public var visible(get, set):Bool;
	public var active(get, set):Bool;
	public var exists(get, set):Bool;
	public var antialiasing(get, set):Bool;
	public var flipX(get, set):Bool;
	public var flipY(get, set):Bool;
	public var color(get, set):FlxColor;
	public var shader(get, set):Dynamic;
	public var blend(get, set):Dynamic;
	public var cameras(get, set):Array<FlxCamera>;
	public var camera(get, set):FlxCamera;
	public var scale(get, never):FlxPoint;
	public var offset(get, never):FlxPoint;
	public var origin(get, never):FlxPoint;
	public var scrollFactor(get, never):FlxPoint;
	public var velocity(get, never):FlxPoint;
	public var acceleration(get, never):FlxPoint;
	public var graphic(get, never):Dynamic;
	public var frameWidth(get, never):Int;
	public var frameHeight(get, never):Int;
	public var holdTimer(get, set):Float;
	public var danced(get, set):Bool;
	public var debugMode(get, set):Bool;

	function get_frames():FlxFramesCollection
		return target != null ? target.frames : null;

	function set_frames(value:FlxFramesCollection):FlxFramesCollection
	{
		if (target != null)
			target.frames = value;
		return value;
	}

	function get_animation():FlxAnimationController
		return target != null ? target.animation : null;

	function get_x():Float
		return target != null ? target.x : 0;

	function set_x(value:Float):Float
	{
		if (target != null)
			target.x = value;
		return value;
	}

	function get_y():Float
		return target != null ? target.y : 0;

	function set_y(value:Float):Float
	{
		if (target != null)
			target.y = value;
		return value;
	}

	function get_width():Float
		return target != null ? target.width : 0;

	function set_width(value:Float):Float
	{
		if (target != null)
			target.width = value;
		return value;
	}

	function get_height():Float
		return target != null ? target.height : 0;

	function set_height(value:Float):Float
	{
		if (target != null)
			target.height = value;
		return value;
	}

	function get_alpha():Float
		return target != null ? target.alpha : 1;

	function set_alpha(value:Float):Float
	{
		if (target != null)
			target.alpha = value;
		return value;
	}

	function get_angle():Float
		return target != null ? target.angle : 0;

	function set_angle(value:Float):Float
	{
		if (target != null)
			target.angle = value;
		return value;
	}

	function get_visible():Bool
		return target != null && target.visible;

	function set_visible(value:Bool):Bool
	{
		if (target != null)
			target.visible = value;
		return value;
	}

	function get_active():Bool
		return target != null && target.active;

	function set_active(value:Bool):Bool
	{
		if (target != null)
			target.active = value;
		return value;
	}

	function get_exists():Bool
		return target != null && target.exists;

	function set_exists(value:Bool):Bool
	{
		if (target != null)
			target.exists = value;
		return value;
	}

	function get_antialiasing():Bool
		return target != null && target.antialiasing;

	function set_antialiasing(value:Bool):Bool
	{
		if (target != null)
			target.antialiasing = value && backend.ClientPrefs.data.antialiasing;
		return value;
	}

	function get_flipX():Bool
		return target != null && target.flipX;

	/** Como en Dave: el flipX elige el archivo de offsets (el del jugador si quedó al revés que en el JSON). */
	function set_flipX(value:Bool):Bool
	{
		unsuper();
		if (target == null)
			return value;
		target.flipX = value;
		animOffsets.clear();
		if (_data != null)
		{
			var flipped:Bool = value != (_data.flipX == true);
			var file:Dynamic = flipped ? _data.offsetFilePlayer : _data.offsetFileOpponent;
			if (file != null)
				loadOffsetFile(Std.string(file));
		}
		refreshOffsets();
		return value;
	}

	function get_flipY():Bool
		return target != null && target.flipY;

	function set_flipY(value:Bool):Bool
	{
		if (target != null)
			target.flipY = value;
		return value;
	}

	function get_color():FlxColor
		return target != null ? target.color : FlxColor.WHITE;

	function set_color(value:FlxColor):FlxColor
	{
		if (target != null)
			target.color = value;
		return value;
	}

	function get_shader():Dynamic
		return target != null ? target.shader : null;

	function set_shader(value:Dynamic):Dynamic
	{
		if (target != null)
			target.shader = value;
		return value;
	}

	function get_blend():Dynamic
		return target != null ? target.blend : null;

	function set_blend(value:Dynamic):Dynamic
	{
		if (target != null)
			target.blend = value;
		return value;
	}

	function get_cameras():Array<FlxCamera>
		return target != null ? target.cameras : null;

	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		if (target != null)
			target.cameras = value;
		return value;
	}

	function get_camera():FlxCamera
		return target != null ? target.camera : null;

	function set_camera(value:FlxCamera):FlxCamera
	{
		if (target != null)
			target.camera = value;
		return value;
	}

	function get_scale():FlxPoint
		return target != null ? target.scale : null;

	function get_offset():FlxPoint
		return target != null ? target.offset : null;

	function get_origin():FlxPoint
		return target != null ? target.origin : null;

	function get_scrollFactor():FlxPoint
		return target != null ? target.scrollFactor : null;

	function get_velocity():FlxPoint
		return target != null ? target.velocity : null;

	function get_acceleration():FlxPoint
		return target != null ? target.acceleration : null;

	function get_graphic():Dynamic
		return target != null ? target.graphic : null;

	function get_frameWidth():Int
		return target != null ? target.frameWidth : 0;

	function get_frameHeight():Int
		return target != null ? target.frameHeight : 0;

	function get_holdTimer():Float
		return target != null ? target.holdTimer : 0;

	function set_holdTimer(value:Float):Float
	{
		if (target != null)
			target.holdTimer = value;
		return value;
	}

	function get_danced():Bool
		return target != null && target.danced;

	function set_danced(value:Bool):Bool
	{
		if (target != null)
			target.danced = value;
		return value;
	}

	function get_debugMode():Bool
		return target != null && target.debugMode;

	function set_debugMode(value:Bool):Bool
	{
		if (target != null)
			target.debugMode = value;
		return value;
	}

	public function updateHitbox():Void
		if (target != null) target.updateHitbox();

	public function setGraphicSize(width:Float = 0, height:Float = 0):Void
		if (target != null) target.setGraphicSize(width, height);

	public function loadGraphic(graphic:Dynamic, animated:Bool = false, frameWidth:Int = 0, frameHeight:Int = 0):Dynamic
	{
		if (target != null)
			target.loadGraphic(Std.isOfType(graphic, String) ? DavePaths.image(graphic) : graphic, animated, frameWidth, frameHeight);
		return this;
	}

	public function makeGraphic(width:Int, height:Int, color:FlxColor = FlxColor.WHITE):Dynamic
	{
		if (target != null)
			target.makeGraphic(width, height, color);
		return this;
	}

	public function setPosition(x:Float = 0, y:Float = 0):Void
		if (target != null) target.setPosition(x, y);

	public function screenCenter(?axes:Dynamic):Dynamic
	{
		if (target != null)
		{
			if (axes == null)
				target.screenCenter();
			else
				target.screenCenter(axes);
		}
		return this;
	}

	public function getPosition(?result:FlxPoint):FlxPoint
		return target != null ? target.getPosition(result) : FlxPoint.get();

	public function getMidpoint(?point:FlxPoint):FlxPoint
		return target != null ? target.getMidpoint(point) : FlxPoint.get();

	public function getGraphicMidpoint(?point:FlxPoint):FlxPoint
		return target != null ? target.getGraphicMidpoint(point) : FlxPoint.get();

	public function getScreenPosition(?result:FlxPoint, ?camera:FlxCamera):FlxPoint
		return target != null ? target.getScreenPosition(result, camera) : FlxPoint.get();

	public function centerOffsets(adjustPosition:Bool = false):Void
		if (target != null) target.centerOffsets(adjustPosition);

	public function centerOrigin():Void
		if (target != null) target.centerOrigin();

	public function kill():Void
		if (target != null) target.kill();

	public function revive():Void
		if (target != null) target.revive();

	public function toString():String
		return 'Character(id = $id, name = $characterName, type = $characterType)';

	// ----- Eventos (el script cambia los que usa) -----

	public function onScriptEvent(event:Dynamic):Void {}

	public function onScriptEventPost(event:Dynamic):Void {}

	public function onUpdate(event:Dynamic):Void {}

	public function onDestroy(event:Dynamic):Void {}

	public function onNoteSpawn(event:Dynamic):Void {}

	public function onPreferenceChanged(event:Dynamic):Void {}

	public function onStepHit(event:Dynamic):Void {}

	public function onBeatHit(event:Dynamic):Void {}

	public function onMeasureHit(event:Dynamic):Void {}

	public function onTimeChangeHit(event:Dynamic):Void {}

	public function onCreatePost(event:Dynamic):Void {}

	public function onCreateUI(event:Dynamic):Void {}

	public function onSongStart(event:Dynamic):Void {}

	public function onSongLoad(event:Dynamic):Void {}

	public function onSongEnd(event:Dynamic):Void {}

	public function onPause(event:Dynamic):Void {}

	public function onResume(event:Dynamic):Void {}

	public function onPressSeven(event:Dynamic):Void {}

	public function onGameOver(event:Dynamic):Void {}

	public function onCountdownStart(event:Dynamic):Void {}

	public function onCountdownTick(event:Dynamic):Void {}

	public function onCountdownTickPost(event:Dynamic):Void {}

	public function onCountdownFinish(event:Dynamic):Void {}

	public function onCameraMove(event:Dynamic):Void {}

	public function onCameraMoveSection(event:Dynamic):Void {}

	public function onOpponentNoteHit(event:Dynamic):Void {}

	public function onPlayerNoteHit(event:Dynamic):Void {}

	/** En Dave hace la animación de fallo; en Flux la hace Psych. */
	public function onNoteMiss(event:Dynamic):Void {}

	public function onGhostNoteMiss(event:Dynamic):Void {}

	public function onHoldNoteDrop(event:Dynamic):Void {}
}

/**
 * Personaje de Dave cuyo código viene de un .hxc: la macro de RuleScript genera el
 * constructor `new(clase, [args])` y un override de cada función que usa la del script.
 */
@:keep
class FluxScriptedDaveCharacter extends DaveCharacter implements rulescript.scriptedClass.RuleScriptedClass {}
#end
