package flux.dave.api;

#if FLUX_DAVE_SCRIPTS
import backend.ClientPrefs;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flux.dave.api.DaveLanguage;
import flux.dave.api.DaveModule;
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
		variables.set('ScriptEventDispatcher', DaveScriptEventDispatcher);
		variables.set('Module', DaveModule);
		variables.set('SongModule', DaveSongModule);
		variables.set('SongModuleHandler', flux.dave.DaveModules.DaveSongModuleHandler);
		variables.set('LanguageManager', DaveLanguageManager);
		variables.set('Preloader', flux.dave.DaveModules.DavePreloader);
		variables.set('SoundController', DaveSoundController);
		variables.set('RuntimeShader', DaveRuntimeShader);
		variables.set('PlayStatePlaylist', DavePlayStatePlaylist);
		variables.set('Preferences', DavePreferences);
		variables.set('Cursor', DaveCursor);
		variables.set('FreeplayState', DaveFreeplayState);
		variables.set('StoryMenuState', states.StoryMenuState);
		variables.set('MusicBeatState', backend.MusicBeatState);
		variables.set('Song', DaveSong);
		variables.set('Main', DaveMain);
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
		add(['play.save.Preferences'], DavePreferences);
		add(['play.PlayStatePlaylist'], DavePlayStatePlaylist);
		add(['play.song.SongModule', 'play.song.ScriptedSongModule'], DaveSongModule);
		add(['play.song.SongModuleHandler'], flux.dave.DaveModules.DaveSongModuleHandler);
		add(['play.song.Song'], DaveSong);
		add(['scripting.module.ModuleHandler'], flux.dave.DaveModules.DaveModuleHandler);
		add(['scripting.events.ScriptEventDispatcher'], DaveScriptEventDispatcher);
		add(['data.language.LanguageManager'], DaveLanguageManager);
		add(['util.tools.Preloader'], flux.dave.DaveModules.DavePreloader);
		add(['audio.SoundController'], DaveSoundController);
		add(['graphics.shaders.RuntimeShader', 'graphics.shaders.ScriptedRuntimeShader'], DaveRuntimeShader);
		add(['play.camera.FollowType'], DaveFollowType);
		add(['ui.Cursor'], DaveCursor);
		add(['ui.menu.freeplay.FreeplayState'], DaveFreeplayState);
		add(['ui.menu.freeplay.category.Category', 'ui.menu.freeplay.category.MainCategory'], DaveFreeplayCategory);
		add(['ui.menu.story.StoryMenuState'], states.StoryMenuState);
		add(['ui.MusicBeatState'], backend.MusicBeatState);
		add(['Main'], DaveMain);
		add(['flixel.math.FlxBasePoint'], flixel.math.FlxPoint.FlxBasePoint);
		add(['ui.select.charSelect.CharacterSelect'], DaveCharacterSelect);
		add(['audio.GameSound'], DaveGameSound);
		add(['audio.SoundType'], DaveSoundType);
		add(['backend.Conductor'], flux.vslice.api.VSliceApi.VSConductor);
		add(['scripting.module.Module', 'scripting.module.ScriptedModule'], DaveModule);
		add(['scripting.events.ScriptEvent'], ScriptEvent);
		add(['scripting.events.StateChangeScriptEvent'], DaveStateChangeEvent);
		add(['scripting.events.PreferenceScriptEvent'], DavePreferenceEvent);
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

/**
 * VoidBGSprite de Dave Engine: un BGSprite con el shader de "void" (glitchEffect), la
 * imagen que se ondula en las canciones 3D. `params`: {speed, frequency, amplitude}.
 * El shader es shaders/glitchEffect.frag de los mods (el de VsDnB); si no está, Flux usa
 * uno igual. Con los shaders apagados en las opciones queda la imagen sola.
 */
@:keep
class DaveVoidBGSprite extends DaveBGSprite
{
	/** El shader del efecto (null con los shaders apagados). */
	public var glitchShader(default, null):DaveRuntimeShader = null;

	public function new(?name:String, ?x:Float = 0, ?y:Float = 0, ?graphic:Dynamic, ?animations:Array<Dynamic>, ?params:Dynamic)
	{
		super(name, x, y, graphic, animations);
		#if (!flash && sys)
		if (ClientPrefs.data.shaders)
		{
			try
			{
				var shader:DaveRuntimeShader = new DaveRuntimeShader(DaveShaders.glitchEffect());
				shader.setFloat('uWaveAmplitude', param(params, 'amplitude', 0.1));
				shader.setFloat('uFrequency', param(params, 'frequency', 5));
				shader.setFloat('uSpeed', param(params, 'speed', 2));
				shader.setFloat('uAlpha', 1);
				shader.setBool('enableAlpha', true);
				shader.setFloat('uTime', 0);
				glitchShader = shader;
				this.shader = shader;
			}
			catch (e:Dynamic)
			{
				trace('[Flux Dave Engine] VoidBGSprite sin shader: $e');
				glitchShader = null;
			}
		}
		#end
		active = true;
		antialiasing = false;
	}

	static function param(params:Dynamic, name:String, fallback:Float):Float
	{
		var value:Dynamic = params != null ? Reflect.field(params, name) : null;
		return value != null ? value : fallback;
	}

	override function update(elapsed:Float):Void
	{
		#if (!flash && sys)
		if (glitchShader != null)
		{
			var time:Null<Float> = glitchShader.getFloat('uTime');
			glitchShader.setFloat('uTime', (time != null ? time : 0) + elapsed);
		}
		#end
		super.update(elapsed);
	}

	override function set_alpha(value:Float):Float
	{
		#if (!flash && sys)
		if (glitchShader != null)
			glitchShader.setFloat('uAlpha', value < 0 ? 0 : (value > 1 ? 1 : value));
		#end
		return super.set_alpha(value);
	}
}

/** Los shaders de Dave que usa Flux (de los mods, o los de acá si el mod no los trae). */
class DaveShaders
{
	/** El código de shaders/<nombre>.frag en los mods activos (null si no está). */
	public static function fromMods(name:String):String
	{
		#if sys
		var path:String = flux.dave.DaveScripts.findFile('shaders/$name.frag');
		if (path != null && sys.FileSystem.exists(path))
			return sys.io.File.getContent(path);
		#end
		return null;
	}

	/** El shader de VoidBGSprite (glitchEffect.frag). */
	public static function glitchEffect():String
	{
		var code:String = fromMods('glitchEffect');
		return code != null ? code : GLITCH_EFFECT;
	}

	/**
	 * Ondas en la imagen que se mueven con el tiempo: el "GlitchEffect" de Dave and Bambi,
	 * con los mismos uniforms. La transparencia y el color los pone el sprite
	 * (flixel_texture2D), así que uAlpha y enableAlpha quedan para los scripts.
	 */
	public static final GLITCH_EFFECT:String = '
#pragma header

uniform float uTime;
uniform float uSpeed;
uniform float uFrequency;
uniform float uWaveAmplitude;
uniform float uAlpha;
uniform bool enableAlpha;

vec2 sineWave(vec2 pt)
{
	float offsetX = sin(pt.y * uFrequency + 10.0 + uTime * uSpeed) * (uWaveAmplitude / pt.x * pt.y);
	float offsetY = sin(pt.x * uFrequency + 5.0 + uTime * uSpeed) * (uWaveAmplitude / pt.y * pt.x);
	return vec2(pt.x + offsetX, pt.y + offsetY);
}

void main()
{
	gl_FragColor = flixel_texture2D(bitmap, sineWave(openfl_TextureCoordv));
}
';
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

/**
 * SoundController de Dave Engine: los sonidos y la música con FlxG.sound
 * (play devuelve el FlxSound, así `.stop()` o `.volume` funcionan).
 */
@:keep
class DaveSoundController
{
	public static var music(get, set):FlxSound;

	static function get_music():FlxSound
		return FlxG.sound.music;

	static function set_music(value:FlxSound):FlxSound
		return FlxG.sound.music = value;

	public static function play(asset:Dynamic, volume:Float = 1, looped:Bool = false, ?soundType:Dynamic, ?group:Dynamic, autoDestroy:Bool = true,
			?onComplete:Void->Void):FlxSound
	{
		if (Std.isOfType(asset, String) && !Std.string(asset).contains('/') && !Std.string(asset).contains('.'))
			asset = DavePaths.sound(asset);
		return asset != null ? FlxG.sound.play(asset, volume, looped, null, autoDestroy, onComplete) : null;
	}

	public static function playMusic(asset:Dynamic, volume:Float = 1, looped:Bool = true, ?group:Dynamic):Void
	{
		if (Std.isOfType(asset, String) && !Std.string(asset).contains('/') && !Std.string(asset).contains('.'))
			asset = DavePaths.music(asset);
		if (asset != null)
			FlxG.sound.playMusic(asset, volume, looped);
	}

	public static function load(asset:Dynamic, volume:Float = 1, looped:Bool = false, ?soundType:Dynamic, ?group:Dynamic, autoDestroy:Bool = false,
			?onComplete:Void->Void):FlxSound
		return asset != null ? FlxG.sound.load(asset, volume, looped, null, autoDestroy, false, null, onComplete) : null;

	public static function pause():Void
		FlxG.sound.pause();

	public static function resume():Void
		FlxG.sound.resume();

	public static function cache(key:String):Dynamic
		return DavePaths.sound(key);

	public static function add(sound:Dynamic):Dynamic
	{
		if (sound != null && Std.isOfType(sound, FlxSound))
			FlxG.sound.list.add(sound);
		return sound;
	}

	public static function remove(sound:Dynamic):Dynamic
	{
		if (sound != null && Std.isOfType(sound, FlxSound))
			FlxG.sound.list.remove(sound);
		return sound;
	}
}

/**
 * RuntimeShader de Dave Engine: `new RuntimeShader(Paths.frag('nombre'))`. En Dave recibe
 * la ruta del .frag; también sirve el código del shader directo.
 */
#if (!flash && sys)
@:keep
class DaveRuntimeShader extends flixel.addons.display.FlxRuntimeShader
{
	public function new(fragmentSource:String, ?vertexSource:String)
	{
		super(DaveRuntimeShader.code(fragmentSource), DaveRuntimeShader.code(vertexSource));
	}

	/** El código: el texto mismo, o lo que hay en el archivo (también buscado en los mods). */
	public static function code(source:String):String
	{
		if (source == null || source.length == 0)
			return null;
		if (source.contains('void main') || source.contains('#pragma'))
			return source;
		var path:String = source;
		if (!sys.FileSystem.exists(path))
		{
			var found:String = flux.dave.DaveScripts.findFile(source);
			if (found != null)
				path = found;
		}
		return sys.FileSystem.exists(path) ? sys.io.File.getContent(path) : null;
	}
}
#else
@:keep
class DaveRuntimeShader extends flixel.system.FlxAssets.FlxShader
{
	public function new(fragmentSource:String, ?vertexSource:String)
		super();
}
#end

/** ScriptEventDispatcher de Dave Engine: manda un evento a un script (onScriptEvent y su función). */
@:keep
class DaveScriptEventDispatcher
{
	public static function callEvent(target:Dynamic, event:Dynamic):Void
	{
		var method:String = flux.dave.FluxDaveStage.methodOf(event);
		if (target != null && method != null)
			flux.dave.DaveScripts.dispatch(target, method, event);
	}
}

/** PlayStatePlaylist de Dave Engine: el modo historia de Psych. */
@:keep
class DavePlayStatePlaylist
{
	public static var isStoryMode(get, set):Bool;
	public static var songList(get, set):Array<String>;
	public static var campaignScore(get, set):Int;
	public static var storyWeek(get, set):Int;

	static function get_isStoryMode():Bool
		return states.PlayState.isStoryMode;

	static function set_isStoryMode(value:Bool):Bool
		return states.PlayState.isStoryMode = value;

	static function get_songList():Array<String>
		return states.PlayState.storyPlaylist;

	static function set_songList(value:Array<String>):Array<String>
		return states.PlayState.storyPlaylist = value != null ? value : [];

	static function get_campaignScore():Int
		return states.PlayState.campaignScore;

	static function set_campaignScore(value:Int):Int
		return states.PlayState.campaignScore = value;

	static function get_storyWeek():Int
		return states.PlayState.storyWeek;

	static function set_storyWeek(value:Int):Int
		return states.PlayState.storyWeek = value;
}

/** Preferences de Dave Engine: las opciones de Psych con los nombres de Dave. */
@:keep
class DavePreferences
{
	public static var downscroll(get, never):Bool;
	public static var ghostTapping(get, never):Bool;
	public static var flashingLights(get, never):Bool;
	public static var cameraShaking(get, never):Bool;
	public static var cameraNoteMovement(get, never):Bool;
	public static var gimmickWarnings(get, never):Bool;
	public static var cutscenes(get, never):Bool;
	public static var hitsounds(get, never):Bool;
	public static var minimalUI(get, never):Bool;
	public static var debugUI(get, never):Bool;
	public static var antialiasing(get, never):Bool;
	public static var language(get, never):String;

	static function get_downscroll():Bool
		return ClientPrefs.data.downScroll;

	static function get_ghostTapping():Bool
		return ClientPrefs.data.ghostTapping;

	static function get_flashingLights():Bool
		return ClientPrefs.data.flashing;

	static function get_cameraShaking():Bool
		return ClientPrefs.data.camZooms;

	static function get_cameraNoteMovement():Bool
		return false;

	static function get_gimmickWarnings():Bool
		return true;

	static function get_cutscenes():Bool
		return true;

	static function get_hitsounds():Bool
		return ClientPrefs.data.hitsoundVolume > 0;

	static function get_minimalUI():Bool
		return ClientPrefs.data.hideHud;

	static function get_debugUI():Bool
		return ClientPrefs.data.showFPS;

	static function get_antialiasing():Bool
		return ClientPrefs.data.antialiasing;

	static function get_language():String
		return DaveLanguageManager.language;
}

/** Cursor de Dave Engine: el mouse de Flixel. */
@:keep
class DaveCursor
{
	public static var visible(get, set):Bool;

	static function get_visible():Bool
		return #if FLX_MOUSE FlxG.mouse.visible #else false #end;

	static function set_visible(value:Bool):Bool
	{
		#if FLX_MOUSE
		FlxG.mouse.visible = value;
		#end
		return value;
	}
}

/** FollowType de Dave Engine (la cámara de Flux sigue como la de Psych). */
@:keep
class DaveFollowType
{
	public static var INSTANT(default, null):String = 'INSTANT';
	public static var LERP(default, null):String = 'LERP';
}

/**
 * FreeplayState de Dave Engine: Flux usa el Freeplay de Psych (las canciones de Dave
 * están en la semana de su mod), así que esto solo deja que los scripts no fallen.
 */
@:keep
class DaveFreeplayState
{
	/** Las canciones que no piden elegir personaje (Flux no tiene esa pantalla). */
	public static var skipSelect:Array<String> = [];

	public static function unlockSong(id:String):Void {}
}

/** Las categorías del Freeplay de Dave Engine (Flux no las usa). */
@:keep
class DaveFreeplayCategory
{
	public var id:String;

	public function new(?id:String)
		this.id = id;

	public function getName():String
		return id;

	public function getIcon():String
		return id;

	public function getSongs():Array<Dynamic>
		return [];
}

/** play.song.Song de Dave Engine (lo que usan los scripts de sus funciones estáticas). */
@:keep
class DaveSong
{
	public static var DEFAULT_VARIATION(default, null):String = 'default';

	public static function validateVariation(?variation:String):String
		return flux.dave.DaveModules.validateVariation(variation);

	public static function validateVariationPath(?variation:String):String
	{
		var v:String = flux.dave.DaveModules.validateVariation(variation);
		return v == 'default' ? '' : '-$v';
	}
}

/** Main de Dave Engine: el nombre de la ventana. */
@:keep
class DaveMain
{
	public static var applicationName(get, never):String;

	static function get_applicationName():String
		return lime.app.Application.current != null && lime.app.Application.current.meta != null ? lime.app.Application.current.meta.get('title') : 'Friday Night Funkin\'';
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
