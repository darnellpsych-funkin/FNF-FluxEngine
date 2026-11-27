package flux.dave.api;

#if FLUX_DAVE_SCRIPTS
import backend.ClientPrefs;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flux.vslice.api.ScriptEvent;
import flux.vslice.api.VSliceApi.VSPaths;
import openfl.utils.AssetType;
import substates.GameOverSubstate;

using StringTools;

/**
 * Las clases de Dave Engine (VS Dave and Bambi Volume 1) que usan los scripts .hxc
 * de personajes y escenarios, hechas con lo de Psych/Flux.
 */
class DaveTypes
{
	static var aliases:Map<String, Dynamic>;

	/** Lo que un script de Dave tiene sin importar nada (los "default imports" de su Polymod). */
	public static function applyGlobals(variables:Map<String, Dynamic>):Void
	{
		variables.set('Paths', DavePaths);
		variables.set('PlayState', states.PlayState);
		variables.set('GameOverSubstate', DaveGameOver);
		variables.set('PauseSubState', substates.PauseSubState);
		variables.set('Character', DaveCharacter);
		variables.set('Stage', DaveStage);
		variables.set('BGSprite', DaveBGSprite);
		variables.set('VoidBGSprite', DaveVoidBGSprite);
		variables.set('GameSound', DaveGameSound);
		variables.set('CharacterSelect', DaveCharacterSelect);
		variables.set('Conductor', flux.vslice.api.VSliceApi.VSConductor);
		variables.set('ScriptEvent', ScriptEvent);
		variables.set('Module', flux.vslice.api.Module);
		variables.set('FlxG', FlxG);
		variables.set('FlxCamera', flixel.FlxCamera);
		variables.set('FlxSprite', FlxSprite);
		variables.set('FlxState', flixel.FlxState);
		variables.set('FlxText', flixel.text.FlxText);
		variables.set('FlxEase', flixel.tweens.FlxEase);
		variables.set('FlxTween', flixel.tweens.FlxTween);
		variables.set('FlxGroup', flixel.group.FlxGroup.FlxTypedGroup);
		variables.set('FlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
		variables.set('FlxSpriteGroup', flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup);
		variables.set('FlxTypedSpriteGroup', flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup);
		variables.set('FlxTimer', flixel.util.FlxTimer);
		variables.set('ColorMatrixFilter', openfl.filters.ColorMatrixFilter);
		variables.set('ShaderFilter', openfl.filters.ShaderFilter);
		#if hxvlc
		variables.set('FlxVideo', hxvlc.flixel.FlxVideo);
		variables.set('FlxVideoSprite', hxvlc.flixel.FlxVideoSprite);
		#end
		variables.set('StringTools', StringTools);
		variables.set('Date', Date);
		variables.set('DateTools', DateTools);
		variables.set('EReg', EReg);
	}

	/** `import play.stage.BGSprite;` y compañía (null si no es de Dave Engine). */
	public static function resolve(path:String):Dynamic
	{
		if (aliases == null)
			init();
		if (path == null)
			return null;
		var type:Dynamic = aliases.get(path);
		if (type != null)
			return type;
		// "scripting.events.ScriptEvent.UpdateScriptEvent" -> "scripting.events.UpdateScriptEvent"
		var parts:Array<String> = path.split('.');
		if (parts.length > 2)
		{
			var module:String = parts[parts.length - 2];
			if (module.length > 0 && module.charAt(0) == module.charAt(0).toUpperCase())
			{
				parts.splice(parts.length - 2, 1);
				return aliases.get(parts.join('.'));
			}
		}
		return null;
	}

	static function init():Void
	{
		aliases = new Map<String, Dynamic>();
		var add = function(names:Array<String>, type:Dynamic) for (name in names) aliases.set(name, type);

		add(['Paths'], DavePaths);
		add(['play.PlayState'], states.PlayState);
		add(['play.GameOverSubstate'], DaveGameOver);
		add(['play.PauseSubState'], substates.PauseSubState);
		add(['play.character.Character', 'play.character.ScriptedCharacter'], DaveCharacter);
		add(['play.character.CharacterType'], DaveCharacterType);
		add(['play.stage.Stage', 'play.stage.ScriptedStage'], DaveStage);
		add(['play.stage.BGSprite', 'play.stage.ScriptedBGSprite'], DaveBGSprite);
		add(['play.stage.VoidBGSprite', 'play.stage.ScriptedVoidBGSprite'], DaveVoidBGSprite);
		add(['play.ui.CountdownStep'], DaveCountdownStep);
		add(['play.save.Preferences'], flux.vslice.api.VSliceApi.VSPreferences);
		add(['ui.select.charSelect.CharacterSelect'], DaveCharacterSelect);
		add(['audio.GameSound'], DaveGameSound);
		add(['audio.SoundType'], DaveSoundType);
		add(['backend.Conductor'], flux.vslice.api.VSliceApi.VSConductor);
		add(['scripting.module.Module', 'scripting.module.ScriptedModule'], flux.vslice.api.Module);
		add(['scripting.events.ScriptEvent'], ScriptEvent);
		add(['scripting.events.UpdateScriptEvent'], UpdateScriptEvent);
		add(['scripting.events.ConductorScriptEvent'], DaveConductorEvent);
		add(['scripting.events.CountdownScriptEvent'], DaveCountdownEvent);
		add(['scripting.events.CameraScriptEvent'], DaveCameraEvent);
		add(['scripting.events.NoteScriptEvent'], DaveNoteEvent);
		add(['scripting.events.HoldNoteScriptEvent'], DaveHoldNoteEvent);
		add(['scripting.events.GhostNoteScriptEvent'], DaveGhostNoteEvent);
		add(['scripting.events.AddPropScriptEvent'], DaveAddPropEvent);
		add(['scripting.events.AddCharacterScriptEvent'], DaveAddCharacterEvent);
	}
}

/**
 * Paths de Dave Engine: los de Flux para V-Slice (buscan en el mod actual, en `shared/`
 * y en el mod del script). La "library" ('shared'...) no hace falta.
 */
@:keep
class DavePaths
{
	public static function image(key:String, ?library:String):Dynamic
		return VSPaths.image(key, library);

	/** En Dave es la ruta del .png; acá es el gráfico ya cargado (sirve igual para loadGraphic, FlxBackdrop...). */
	public static function imagePath(key:String, ?library:String):Dynamic
		return VSPaths.image(key, library);

	public static function getSparrowAtlas(key:String, ?library:String):Dynamic
		return VSPaths.getSparrowAtlas(key, library);

	public static function getPackerAtlas(key:String, ?library:String):Dynamic
		return VSPaths.getPackerAtlas(key, library);

	public static function sound(key:String, ?library:String):Dynamic
		return VSPaths.sound(key, library);

	public static function soundRandom(key:String, min:Int, max:Int, ?library:String):Dynamic
		return VSPaths.soundRandom(key, min, max, library);

	public static function music(key:String, ?library:String):Dynamic
		return VSPaths.music(key, library);

	public static function font(key:String):String
		return VSPaths.font(key);

	public static function frag(key:String):String
		return VSPaths.frag(key);

	public static function vert(key:String):String
		return VSPaths.vert(key);

	public static function video(key:String):String
		return VSPaths.video(key);

	public static function file(key:String, ?library:String):String
		return VSPaths.file(key, library);

	public static function json(key:String, ?library:String):String
		return VSPaths.json(key, library);

	public static function txt(key:String, ?library:String):String
		return VSPaths.txt(key, library);

	public static function xml(key:String, ?library:String):String
		return VSPaths.xml(key, library);

	/** La carpeta de un atlas de Adobe Animate (images/<key>). */
	public static function atlas(key:String, ?library:String):String
		return VSPaths.file('images/$key', library);

	/** data/offsets/<personaje>.txt */
	public static function offsetFile(character:String):String
		return VSPaths.file('data/offsets/$character.txt');
}

/**
 * BGSprite de Dave Engine: un prop del escenario con nombre (getProp('bg')).
 * `graphic` puede ser el gráfico (Paths.image) o, con animaciones, el atlas ('backgrounds/...').
 */
@:keep
class DaveBGSprite extends FlxSprite
{
	public var spriteName:String;

	public function new(spriteName:String, posX:Float, posY:Float, ?graphic:Dynamic, ?animations:Array<Dynamic>, scrollX:Float = 1,
			scrollY:Float = 1, antialiasing:Bool = true, active:Bool = false)
	{
		super(posX, posY);
		this.spriteName = spriteName;

		if (graphic != null)
		{
			if (animations != null)
			{
				var atlas:Dynamic = Std.isOfType(graphic, String) ? DavePaths.getSparrowAtlas(graphic) : null;
				if (atlas != null)
				{
					frames = atlas;
					for (anim in animations)
						DaveAnimation.addToSprite(this, anim);
				}
			}
			else
			{
				var image:Dynamic = Std.isOfType(graphic, String) ? DavePaths.image(graphic) : graphic;
				if (image != null)
					loadGraphic(image);
			}
		}
		this.antialiasing = antialiasing && ClientPrefs.data.antialiasing;
		scrollFactor.set(scrollX, scrollY);
		this.active = active;
	}

	/** El prop con ese nombre de una lista (BGSprite.getBGSprite de Dave). */
	public static function getBGSprite(group:Dynamic, spriteName:String):DaveBGSprite
	{
		var members:Array<Dynamic> = group != null ? Reflect.getProperty(group, 'members') : null;
		if (members == null && Std.isOfType(group, Array))
			members = group;
		if (members != null)
			for (member in members)
				if (Std.isOfType(member, DaveBGSprite) && (cast member : DaveBGSprite).spriteName == spriteName)
					return cast member;
		return null;
	}
}

/** VoidBGSprite de Dave Engine (el fondo con shader de "void"). Por ahora sin el shader. */
@:keep
class DaveVoidBGSprite extends DaveBGSprite
{
	public function new(spriteName:String, posX:Float, posY:Float, ?graphic:Dynamic, ?animations:Array<Dynamic>, scrollX:Float = 1,
			scrollY:Float = 1, antialiasing:Bool = true, active:Bool = true)
	{
		super(spriteName, posX, posY, graphic, animations, scrollX, scrollY, antialiasing, active);
	}
}

/** Animation.addToSprite de Dave Engine: {name, prefix, frameRate, loop, flip, indices}. */
class DaveAnimation
{
	public static function addToSprite(target:FlxSprite, data:Dynamic):Void
	{
		if (target == null || data == null || data.name == null)
			return;
		var fps:Int = data.frameRate != null ? Std.int(data.frameRate) : 24;
		var loop:Bool = data.loop == true;
		var flip:Array<Dynamic> = Std.isOfType(data.flip, Array) ? data.flip : [false, false];
		var flipX:Bool = flip.length > 0 && flip[0] == true;
		var flipY:Bool = flip.length > 1 && flip[1] == true;
		var prefix:String = data.prefix != null ? Std.string(data.prefix) : '';
		if (Std.isOfType(data.indices, Array))
			target.animation.addByIndices(data.name, prefix, data.indices, '', fps, loop, flipX, flipY);
		else
			target.animation.addByPrefix(data.name, prefix, fps, loop, flipX, flipY);
	}
}

/**
 * GameOverSubstate de Dave Engine: los scripts de los personajes de muerte ponen
 * `GameOverSubstate.deathSuffix = '-dave'` y Flux elige el sonido y la música de Psych
 * (sounds/death/fnf_loss_sfx-dave, music/gameOver/gameOver-pixel...) si existen.
 */
@:keep
class DaveGameOver
{
	public static var deathSuffix(default, set):String = '';
	public static var musicSuffix(default, set):String = '';

	static function set_deathSuffix(value:String):String
	{
		deathSuffix = value != null ? value : '';
		apply();
		return deathSuffix;
	}

	static function set_musicSuffix(value:String):String
	{
		musicSuffix = value != null ? value : '';
		apply();
		return musicSuffix;
	}

	public static function reset():Void
	{
		@:bypassAccessor deathSuffix = '';
		@:bypassAccessor musicSuffix = '';
		apply();
	}

	/** Los nombres del game over de Psych según los sufijos de Dave (solo si están los archivos). */
	public static function apply():Void
	{
		var death:String = 'death/fnf_loss_sfx' + deathSuffix;
		if (Paths.fileExists('sounds/$death.${Paths.SOUND_EXT}', SOUND))
			GameOverSubstate.deathSoundName = death;
		var music:String = 'gameOver/gameOver' + (musicSuffix.length > 0 ? '-' + musicSuffix : '');
		if (Paths.fileExists('music/$music.${Paths.SOUND_EXT}', MUSIC))
		{
			GameOverSubstate.loopSoundName = music;
			if (Paths.fileExists('music/$music-end.${Paths.SOUND_EXT}', MUSIC))
				GameOverSubstate.endSoundName = music + '-end';
		}
	}
}

/** CharacterType de Dave Engine. */
@:keep
class DaveCharacterType
{
	public static var PLAYER(default, null):String = 'PLAYER';
	public static var OPPONENT(default, null):String = 'OPPONENT';
	public static var GF(default, null):String = 'GF';
	public static var OTHER(default, null):String = 'OTHER';
}

/** CountdownStep de Dave Engine. */
@:keep
class DaveCountdownStep
{
	public static var START(default, null):String = 'START';
	public static var THREE(default, null):String = 'THREE';
	public static var TWO(default, null):String = 'TWO';
	public static var ONE(default, null):String = 'ONE';
	public static var GO(default, null):String = 'GO';
	public static var FINISH(default, null):String = 'FINISH';
}

/** CharacterSelect de Dave Engine: Flux no tiene selección de personaje. */
@:keep
class DaveCharacterSelect
{
	public static var selectedCharacter:String = null;
}

/** SoundType de Dave Engine. */
@:keep
class DaveSoundType
{
	public static var SFX(default, null):String = 'SFX';
	public static var MUSIC(default, null):String = 'MUSIC';
	public static var VOICES(default, null):String = 'VOICES';
}

/** GameSound de Dave Engine: un FlxSound con load/play. */
@:keep
class DaveGameSound
{
	public var sound(default, null):FlxSound;
	public var type:String;
	public var volume(get, set):Float;
	public var pitch(get, set):Float;
	public var playing(get, never):Bool;

	public function new(?type:String)
	{
		this.type = type != null ? type : DaveSoundType.SFX;
	}

	public function load(asset:Dynamic, looped:Bool = false, autoDestroy:Bool = false):DaveGameSound
	{
		if (asset == null)
			return this;
		if (sound == null)
		{
			sound = new FlxSound();
			FlxG.sound.list.add(sound);
		}
		sound.loadEmbedded(asset, looped, autoDestroy);
		return this;
	}

	public function play(forceRestart:Bool = false, startTime:Float = 0):DaveGameSound
	{
		if (sound != null)
			sound.play(forceRestart, startTime);
		return this;
	}

	public function stop():Void
		if (sound != null) sound.stop();

	public function pause():Void
		if (sound != null) sound.pause();

	public function resume():Void
		if (sound != null) sound.resume();

	function get_volume():Float
		return sound != null ? sound.volume : 1;

	function set_volume(value:Float):Float
	{
		if (sound != null)
			sound.volume = value;
		return value;
	}

	function get_pitch():Float
		return #if FLX_PITCH sound != null ? sound.pitch : #end 1;

	function set_pitch(value:Float):Float
	{
		#if FLX_PITCH
		if (sound != null)
			sound.pitch = value;
		#end
		return value;
	}

	function get_playing():Bool
		return sound != null && sound.playing;
}

// ----- Eventos de Dave Engine (scripting.events.*) -----

/** onStepHit / onBeatHit / onMeasureHit. */
@:keep
class DaveConductorEvent extends ScriptEvent
{
	public var step(default, null):Int;
	public var beat(default, null):Int;
	public var measure(default, null):Int;

	public function new(type:String, step:Int, beat:Int, measure:Int, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.step = step;
		this.beat = beat;
		this.measure = measure;
	}
}

/** onCountdownStart / onCountdownTick / onCountdownFinish (`step`: THREE, TWO, ONE, GO...). */
@:keep
class DaveCountdownEvent extends ScriptEvent
{
	public var step(default, null):String;

	public function new(type:String, step:String, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.step = step;
	}
}

/** onCameraMove: si la cámara va al oponente. */
@:keep
class DaveCameraEvent extends ScriptEvent
{
	public var isOpponent(default, null):Bool;

	public function new(type:String, isOpponent:Bool, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.isOpponent = isOpponent;
	}
}

/** onPlayerNoteHit / onOpponentNoteHit / onNoteMiss: la nota de Psych y el personaje que canta. */
@:keep
class DaveNoteEvent extends ScriptEvent
{
	public var note(default, null):Dynamic;
	public var character(default, null):Dynamic;
	public var healthChange:Float;
	public var comboCount(default, null):Int;

	/** En Dave un script puede cambiar el sonido del fallo; Flux todavía usa el de Psych. */
	public var missSound:Dynamic = null;

	public function new(type:String, note:Dynamic, character:Dynamic, healthChange:Float = 0, comboCount:Int = 0, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.note = note;
		this.character = character;
		this.healthChange = healthChange;
		this.comboCount = comboCount;
	}
}

@:keep
class DaveHoldNoteEvent extends DaveNoteEvent
{
	public var holdNote(default, null):Dynamic;

	public function new(type:String, holdNote:Dynamic, character:Dynamic, healthChange:Float = 0, comboCount:Int = 0, cancelable:Bool = false)
	{
		super(type, holdNote, character, healthChange, comboCount, cancelable);
		this.holdNote = holdNote;
	}
}

/** onGhostNoteMiss: tocaste sin nota (`direction` 0-3). */
@:keep
class DaveGhostNoteEvent extends DaveNoteEvent
{
	public var direction(default, null):Int;

	public function new(direction:Int, character:Dynamic, healthChange:Float = 0, comboCount:Int = 0, cancelable:Bool = false)
	{
		super('ghost_note_miss', null, character, healthChange, comboCount, cancelable);
		this.direction = direction;
	}
}

/** onAdd: se agregó un prop al escenario. */
@:keep
class DaveAddPropEvent extends ScriptEvent
{
	public var prop(default, null):Dynamic;

	public function new(prop:Dynamic, cancelable:Bool = false)
	{
		super('on_add', cancelable);
		this.prop = prop;
	}
}

/** onCharacterAdd: un personaje llegó al escenario (`character` es el personaje del juego). */
@:keep
class DaveAddCharacterEvent extends ScriptEvent
{
	public var character(default, null):Dynamic;

	public function new(character:Dynamic, cancelable:Bool = false)
	{
		super('on_character_add', cancelable);
		this.character = character;
	}
}
#end
