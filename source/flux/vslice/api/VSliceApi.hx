package flux.vslice.api;

#if FLUX_VSLICE_SCRIPTS
import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.Difficulty;
import backend.Paths;
import backend.WeekData;
import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.util.FlxSave;
import flux.vslice.api.ScriptEvent;
import flux.vslice.modules.FluxVSliceModules;
import states.PlayState;
import backend.Mods;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * Versiones "de mentira" de clases de V-Slice para que los módulos .hxc
 * funcionen en Flux (Psych Engine 1.0.4). Cada una traduce a lo que hay en Psych.
 *
 * El mapa de nombres (funkin.Conductor -> VSConductor, etc.) está en
 * flux.vslice.modules.VSliceTypes.
 */
@:keep
class VSConductor
{
	public static var instance(get, never):VSConductor;
	static var _instance:VSConductor;

	static function get_instance():VSConductor
	{
		if (_instance == null)
			_instance = new VSConductor();
		return _instance;
	}

	public function new() {}

	public var songPosition(get, set):Float;

	function get_songPosition():Float
		return Conductor.songPosition;

	function set_songPosition(value:Float):Float
		return Conductor.songPosition = value;

	public var bpm(get, never):Float;

	function get_bpm():Float
		return Conductor.bpm;

	public var startingBPM(get, never):Float;

	function get_startingBPM():Float
		return PlayState.SONG != null ? PlayState.SONG.bpm : Conductor.bpm;

	/** Duración de un beat en milisegundos (Psych: Conductor.crochet). */
	public var beatLengthMs(get, never):Float;

	function get_beatLengthMs():Float
		return Conductor.crochet;

	public var stepLengthMs(get, never):Float;

	function get_stepLengthMs():Float
		return Conductor.stepCrochet;

	public var measureLengthMs(get, never):Float;

	function get_measureLengthMs():Float
		return Conductor.crochet * 4;

	public var currentBeatTime(get, never):Float;

	function get_currentBeatTime():Float
		return Conductor.getBeat(Conductor.songPosition);

	public var currentStepTime(get, never):Float;

	function get_currentStepTime():Float
		return Conductor.getStep(Conductor.songPosition);

	public var currentBeat(get, never):Int;

	function get_currentBeat():Int
		return Math.floor(currentBeatTime);

	public var currentStep(get, never):Int;

	function get_currentStep():Int
		return Math.floor(currentStepTime);

	public var currentMeasure(get, never):Int;

	function get_currentMeasure():Int
		return Math.floor(currentBeatTime / 4);

	public var currentMeasureTime(get, never):Float;

	function get_currentMeasureTime():Float
		return currentBeatTime / 4;

	public var beatsPerMeasure(get, never):Int;

	function get_beatsPerMeasure():Int
		return 4;

	public var stepsPerMeasure(get, never):Int;

	function get_stepsPerMeasure():Int
		return 16;

	public var timeSignatureNumerator(get, never):Int;

	function get_timeSignatureNumerator():Int
		return 4;

	public var timeSignatureDenominator(get, never):Int;

	function get_timeSignatureDenominator():Int
		return 4;

	public var combinedOffset(get, never):Float;

	function get_combinedOffset():Float
		return Conductor.offset;

	public var instrumentalOffset(get, never):Float;

	function get_instrumentalOffset():Float
		return 0;

	public var inputOffset(get, never):Float;

	function get_inputOffset():Float
		return 0;

	public var audioVisualOffset(get, never):Float;

	function get_audioVisualOffset():Float
		return 0;

	public function getTimeWithDiff():Float
		return Conductor.songPosition;
}

/** Save.instance.modOptions de V-Slice (se guarda aparte, en "fluxVSlice"). */
@:keep
class VSSave
{
	public static var instance(get, never):VSSave;
	static var _instance:VSSave;

	static function get_instance():VSSave
	{
		if (_instance == null)
			_instance = new VSSave();
		return _instance;
	}

	var save:FlxSave;

	public function new()
	{
		save = new FlxSave();
		try
		{
			save.bind('fluxVSlice', CoolUtil.getSavePath());
		}
		catch (e:Dynamic)
		{
			trace('[V-Slice] No se pudo abrir el guardado de opciones de mods: $e');
		}
		if (save.data.modOptions == null)
			save.data.modOptions = new Map<String, Dynamic>();
	}

	public var modOptions(get, never):Map<String, Dynamic>;

	function get_modOptions():Map<String, Dynamic>
		return save.data.modOptions;

	public function flush():Void
	{
		try
		{
			save.flush();
		}
		catch (e:Dynamic)
		{
			trace('[V-Slice] No se pudo guardar: $e');
		}
	}
}

/** Datos compartidos entre módulos durante la sesión (V-Slice: ModStore). */
@:keep
class VSModStore
{
	public static var stores(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	public static function register(id:String, ?data:Dynamic):Dynamic
	{
		if (stores.exists(id))
			return stores.get(id);
		if (data == null)
			data = {};
		stores.set(id, data);
		return data;
	}

	public static function get(id:String):Dynamic
		return stores.get(id);

	public static function remove(id:String):Dynamic
	{
		var data:Dynamic = stores.get(id);
		stores.remove(id);
		return data;
	}
}

/** Highscore.tallies de V-Slice: lee los contadores de Psych. */
@:keep
class VSHighscore
{
	public static var tallies(default, null):VSTallies = new VSTallies();
	public static var talliesLevel(default, null):VSTallies = new VSTallies();
}

/**
 * Contadores de la canción. combo/missed/score/sick/good/bad/shit vienen de Psych;
 * cualquier otro campo que el script escriba se guarda aquí mismo.
 * (Los lee y escribe flux.vslice.modules.VSliceAdapter.)
 */
@:keep
class VSTallies
{
	var extra:Map<String, Dynamic> = new Map<String, Dynamic>();

	public function new() {}

	public function getValue(name:String):Dynamic
	{
		var game:PlayState = PlayState.instance;
		if (game != null)
		{
			switch (name)
			{
				case 'combo':
					return game.combo;
				case 'missed':
					return game.songMisses;
				case 'score':
					return game.songScore;
				case 'totalNotesHit':
					return game.songHits;
				case 'totalNotes':
					return game.totalPlayed;
				case 'killer' | 'sick':
					return ratingHits(game, 0);
				case 'good':
					return ratingHits(game, 1);
				case 'bad':
					return ratingHits(game, 2);
				case 'shit':
					return ratingHits(game, 3);
				case 'maxCombo':
					var max:Int = extra.exists('maxCombo') ? extra.get('maxCombo') : 0;
					return game.combo > max ? game.combo : max;
				default:
			}
		}
		return extra.exists(name) ? extra.get(name) : 0;
	}

	public function setValue(name:String, value:Dynamic):Dynamic
	{
		var game:PlayState = PlayState.instance;
		if (game != null)
		{
			switch (name)
			{
				case 'combo':
					game.combo = Std.int(value);
					return value;
				case 'missed':
					game.songMisses = Std.int(value);
					return value;
				case 'score':
					game.songScore = Std.int(value);
					return value;
				default:
			}
		}
		// el resto (totalNotesHit, sick...) ya lo cuenta Psych al pegar la nota
		extra.set(name, value);
		return value;
	}

	static function ratingHits(game:PlayState, index:Int):Int
	{
		var data = game.ratingsData;
		return (data != null && index < data.length && data[index] != null) ? data[index].hits : 0;
	}
}

/** Puntaje y juicio de V-Slice (sistema PBOT1). */
@:keep
class VSScoring
{
	public static function scoreNote(msTiming:Float, ?scoringSystem:Dynamic):Int
	{
		var absTiming:Float = Math.abs(msTiming);
		if (absTiming > 160)
			return -100;
		if (absTiming < 5)
			return 500;
		var factor:Float = 1.0 - (1.0 / (1.0 + Math.exp(-0.080 * (absTiming - 54.99))));
		return Std.int(500 * factor + 9);
	}

	public static function judgeNote(msTiming:Float, ?scoringSystem:Dynamic):String
	{
		var absTiming:Float = Math.abs(msTiming);
		if (absTiming < 45)
			return 'sick';
		if (absTiming < 90)
			return 'good';
		if (absTiming < 135)
			return 'bad';
		if (absTiming < 160)
			return 'shit';
		return 'miss';
	}
}

/** Constantes de V-Slice que usan los módulos (vida, tiempos...). */
@:keep
class VSConstants
{
	public static var HEALTH_MAX:Float = 2.0;
	public static var HEALTH_STARTING:Float = 1.0;
	public static var HEALTH_MIN:Float = 0.0;
	public static var HEALTH_KILLER_BONUS:Float = 2.0 / 100.0 * 2.0;
	public static var HEALTH_SICK_BONUS:Float = 1.5 / 100.0 * 2.0;
	public static var HEALTH_GOOD_BONUS:Float = 0.75 / 100.0 * 2.0;
	public static var HEALTH_BAD_BONUS:Float = 0.0;
	public static var HEALTH_SHIT_BONUS:Float = -1.0 / 100.0 * 2.0;
	public static var HEALTH_MISS_PENALTY:Float = 4.0 / 100.0 * 2.0;
	public static var HEALTH_GHOST_MISS_PENALTY:Float = 2.0 / 100.0 * 2.0;
	public static var HEALTH_HOLD_BONUS_PER_SECOND:Float = 7.5 / 100.0 * 2.0;
	public static var HEALTH_HOLD_DROP_PENALTY_PER_SECOND:Float = 0.0;
	public static var HEALTH_MINE_PENALTY:Float = 15.0 / 100.0 * 2.0;
	public static var SCORE_HOLD_BONUS_PER_SECOND:Float = 250.0;
	public static var MS_PER_SEC:Int = 1000;
	public static var SECS_PER_MIN:Int = 60;
	public static var STEPS_PER_BEAT:Int = 4;
	public static var DEFAULT_BPM:Float = 100.0;
	public static var DEFAULT_SONG:String = 'tutorial';
	public static var DEFAULT_DIFFICULTY:String = 'normal';
	public static var DEFAULT_VARIATION:String = 'default';
	public static var DEFAULT_CHARACTER:String = 'bf';
	public static var DEFAULT_STAGE:String = 'mainStage';
	public static var DEFAULT_NOTE_STYLE:String = 'funkin';
	public static var STRUMLINE_SIZE:Int = 4;
	public static var PIXELS_PER_MS:Float = 0.45;
	public static var COLOR_HEALTH_BAR_RED:Int = 0xFFFF0000;
	public static var COLOR_HEALTH_BAR_GREEN:Int = 0xFF66FF33;
}

/** PlayStatePlaylist de V-Slice -> estáticos de PlayState (Psych). */
@:keep
class VSPlayStatePlaylist
{
	public static var isStoryMode(get, set):Bool;

	static function get_isStoryMode():Bool
		return PlayState.isStoryMode;

	static function set_isStoryMode(value:Bool):Bool
		return PlayState.isStoryMode = value;

	public static var campaignScore(get, set):Int;

	static function get_campaignScore():Int
		return PlayState.campaignScore;

	static function set_campaignScore(value:Int):Int
		return PlayState.campaignScore = value;

	public static var playlistSongIds(get, never):Array<String>;

	static function get_playlistSongIds():Array<String>
		return PlayState.storyPlaylist;

	public static var campaignId(get, never):String;

	static function get_campaignId():String
		return WeekData.getWeekFileName();

	public static var campaignDifficulty(get, never):String;

	static function get_campaignDifficulty():String
		return Paths.formatToSongPath(Difficulty.getString());
}

/** ReflectUtil de V-Slice (en los .hxc "Reflect" es esta clase, como en Polymod). */
@:keep
class VSReflectUtil
{
	public static function getClassNameOf(obj:Dynamic):String
	{
		if (obj == null)
			return null;
		var cls = Type.getClass(obj);
		return cls != null ? Type.getClassName(cls) : null;
	}

	public static function getClassName(cls:Dynamic):String
		return cls != null ? Type.getClassName(cls) : null;

	public static function field(o:Dynamic, name:String):Dynamic
		return Reflect.field(o, name);

	public static function getField(o:Dynamic, name:String):Dynamic
		return Reflect.field(o, name);

	public static function setField(o:Dynamic, name:String, value:Dynamic):Void
		Reflect.setField(o, name, value);

	public static function getProperty(o:Dynamic, name:String):Dynamic
		return Reflect.getProperty(o, name);

	public static function setProperty(o:Dynamic, name:String, value:Dynamic):Void
		Reflect.setProperty(o, name, value);

	public static function hasField(o:Dynamic, name:String):Bool
		return Reflect.hasField(o, name);

	public static function callMethod(o:Dynamic, func:Dynamic, ?args:Array<Dynamic>):Dynamic
	{
		if (Std.isOfType(func, String))
			func = Reflect.getProperty(o, func);
		return Reflect.callMethod(o, func, args == null ? [] : args);
	}

	public static function fields(o:Dynamic):Array<String>
		return Reflect.fields(o);

	public static function isObject(v:Dynamic):Bool
		return Reflect.isObject(v);

	public static function isFunction(v:Dynamic):Bool
		return Reflect.isFunction(v);

	public static function isEnumValue(v:Dynamic):Bool
		return Reflect.isEnumValue(v);

	public static function compare(a:Dynamic, b:Dynamic):Int
		return Reflect.compare(a, b);

	public static function copy(o:Dynamic):Dynamic
		return Reflect.copy(o);

	public static function deleteField(o:Dynamic, name:String):Bool
		return Reflect.deleteField(o, name);

	public static function getAnonymousFieldsOf(o:Dynamic):Array<String>
		return Reflect.fields(o);

	public static function getAnonymousField(o:Dynamic, name:String):Dynamic
		return Reflect.field(o, name);

	public static function setAnonymousField(o:Dynamic, name:String, value:Dynamic):Void
		Reflect.setField(o, name, value);

	public static function hasAnonymousField(o:Dynamic, name:String):Bool
		return Reflect.hasField(o, name);

	public static function getClassFields(cls:Dynamic):Array<String>
		return Type.getClassFields(cls);

	public static function getClassFieldsOf(obj:Dynamic):Array<String>
		return Type.getClassFields(Type.getClass(obj));

	public static function getInstanceFields(cls:Dynamic):Array<String>
		return Type.getInstanceFields(cls);

	public static function getInstanceFieldsOf(obj:Dynamic):Array<String>
		return Type.getInstanceFields(Type.getClass(obj));
}

/** ModuleHandler de V-Slice. */
@:keep
class VSModuleHandler
{
	public static function getModule(moduleId:String):Module
		return FluxVSliceModules.getModule(moduleId);

	public static function callEvent(event:ScriptEvent):Void
		FluxVSliceModules.callEvent(event);

	public static function activateModule(moduleId:String):Void
	{
		var module:Module = getModule(moduleId);
		if (module != null)
			module.active = true;
	}

	public static function deactivateModule(moduleId:String):Void
	{
		var module:Module = getModule(moduleId);
		if (module != null)
			module.active = false;
	}

	public static function getModuleIds():Array<String>
		return [for (module in FluxVSliceModules.modules) module.moduleId];

	/** Vuelve a leer los .hxc de todos los mods activos. */
	public static function loadModuleCache():Void
		FluxVSliceModules.reload(true);
}

/** ScriptEventDispatcher de V-Slice. */
@:keep
class VSScriptEventDispatcher
{
	public static function callEvent(target:Dynamic, event:ScriptEvent):Void
		FluxVSliceModules.dispatchTo(target, event);
}

/**
 * Paths de V-Slice. Usa los de Psych (que ya buscan en el mod actual y los
 * globales) y, si no encuentra el archivo, prueba en el mod del módulo.
 * Ojo: como en Psych, image() devuelve el gráfico y sound()/music() el sonido
 * (sirven igual para loadGraphic, FlxG.sound.play, etc.). El "library" de
 * V-Slice se ignora porque las carpetas de Psych son otras.
 */
@:keep
class VSPaths
{
	public static function image(key:String, ?library:String):Dynamic
		return FluxVSliceModules.withModFallback(() -> Paths.image(key));

	public static function sound(key:String, ?library:String):Dynamic
		return FluxVSliceModules.withModFallback(() -> Paths.sound(key));

	public static function soundRandom(key:String, min:Int, max:Int, ?library:String):Dynamic
		return sound(key + FlxG.random.int(min, max), library);

	public static function music(key:String, ?library:String):Dynamic
		return FluxVSliceModules.withModFallback(() -> Paths.music(key));

	public static function font(key:String):String
		return Paths.font(key);

	public static function getSparrowAtlas(key:String, ?library:String):Dynamic
		return FluxVSliceModules.withModFallback(() -> Paths.getSparrowAtlas(key));

	public static function getPackerAtlas(key:String, ?library:String):Dynamic
		return FluxVSliceModules.withModFallback(() -> Paths.getPackerAtlas(key));

	public static function json(key:String, ?library:String):String
		return findPath('data/$key.json');

	public static function txt(key:String, ?library:String):String
		return findPath('data/$key.txt');

	public static function xml(key:String, ?library:String):String
		return findPath('data/$key.xml');

	public static function file(file:String, ?library:String):String
		return findPath(file);

	public static function frag(key:String):String
		return findPath('shaders/$key.frag');

	public static function vert(key:String):String
		return findPath('shaders/$key.vert');

	/** El archivo en el mod (también el del módulo) o la ruta de Psych si no está. */
	static function findPath(file:String):String
	{
		var found:String = VSAssets.findFile(file);
		return found != null ? found : Paths.getPath(file);
	}

	public static function video(key:String):String
		return Paths.video(key);

	public static function videos(key:String):String
		return Paths.video(key);

	/** La música de una canción (en Flux es el sonido, como en Psych). */
	public static function inst(song:String, ?suffix:String, ?withExtension:Bool):Dynamic
		return FluxVSliceModules.withModFallback(() -> Paths.inst(song));

	public static function voices(song:String, ?suffix:String, ?withExtension:Bool):Dynamic
		return FluxVSliceModules.withModFallback(() -> Paths.voices(song, (suffix != null && suffix.length > 0) ? suffix : null));

	/** La "biblioteca" de assets de la semana (assets/<carpeta>/) como en Psych. */
	public static function setCurrentLevel(name:String):Void
	{
		if (name != null && name.length > 0)
			Paths.setCurrentLevel(name);
	}
}

/** FlxTweenUtil de V-Slice: pausar y seguir los tweens de un objeto. */
@:keep
class VSFlxTweenUtil
{
	public static function pauseTween(tween:flixel.tweens.FlxTween):Void
	{
		if (tween != null)
			tween.active = false;
	}

	public static function resumeTween(tween:flixel.tweens.FlxTween):Void
	{
		if (tween != null)
			tween.active = true;
	}

	public static function pauseTweensOf(object:Dynamic, ?fieldPaths:Array<String>):Void
	{
		if (object != null)
			@:privateAccess flixel.tweens.FlxTween.globalManager.forEachTweensOf(object, fieldPaths, pauseTween);
	}

	public static function resumeTweensOf(object:Dynamic, ?fieldPaths:Array<String>):Void
	{
		if (object != null)
			@:privateAccess flixel.tweens.FlxTween.globalManager.forEachTweensOf(object, fieldPaths, resumeTween);
	}
}

/** PolymodErrorHandler de V-Slice: los avisos de los mods van a la consola (y a la pantalla). */
@:keep
class VSPolymodErrorHandler
{
	public static function showAlert(title:String, message:String):Void
		FluxVSliceModules.reportError(title, message);
}

/** FunkinMemory de V-Slice: precargar imágenes y sonidos (Psych ya los guarda al cargarlos). */
@:keep
class VSFunkinMemory
{
	public static function cacheTexture(key:Dynamic):Void
	{
		if (key != null && Std.isOfType(key, String))
			VSPaths.image(cleanImageKey(key));
	}

	public static function permanentCacheTexture(key:Dynamic):Void
		cacheTexture(key);

	public static function isTextureCached(key:Dynamic):Bool
		return key != null;

	public static function cacheSound(key:Dynamic):Void
	{
		if (key != null && Std.isOfType(key, String))
			VSPaths.sound(cleanSoundKey(key));
	}

	public static function permanentCacheSound(key:Dynamic):Void
		cacheSound(key);

	public static function purgeTextureCache():Void {}

	public static function purgeSoundCache():Void {}

	public static function preparePurgeTextureCache():Void {}

	public static function preparePurgeSoundCache():Void {}

	/** "assets/images/x.png" o "images/x.png" -> "x" (lo que espera Paths.image de Psych). */
	static function cleanImageKey(key:String):String
	{
		var path:String = VSAssets.contentPath(key);
		if (path.startsWith('images/'))
			path = path.substr('images/'.length);
		if (path.endsWith('.png'))
			path = path.substr(0, path.length - 4);
		return path;
	}

	static function cleanSoundKey(key:String):String
	{
		var path:String = VSAssets.contentPath(key);
		if (path.startsWith('sounds/'))
			path = path.substr('sounds/'.length);
		for (ext in ['.ogg', '.mp3', '.wav'])
			if (path.endsWith(ext))
				path = path.substr(0, path.length - ext.length);
		return path;
	}
}

/**
 * Para los `import` de V-Slice que solo son tipos de datos (StageData, SongEventSchema...):
 * con esto el módulo no avisa que falta algo que no usa.
 */
@:keep
class VSDataType
{
	public function new() {}
}

/** Preferencias de V-Slice -> opciones de Psych (ClientPrefs). */
@:keep
class VSPreferences
{
	public static var downscroll(get, never):Bool;

	static function get_downscroll():Bool
		return ClientPrefs.data.downScroll;

	public static var middlescroll(get, never):Bool;

	static function get_middlescroll():Bool
		return ClientPrefs.data.middleScroll;

	public static var flashingLights(get, never):Bool;

	static function get_flashingLights():Bool
		return ClientPrefs.data.flashing;

	public static var zoomCamera(get, never):Bool;

	static function get_zoomCamera():Bool
		return ClientPrefs.data.camZooms;

	public static var ghostTapping(get, never):Bool;

	static function get_ghostTapping():Bool
		return ClientPrefs.data.ghostTapping;

	public static var debugDisplay(get, never):Bool;

	static function get_debugDisplay():Bool
		return ClientPrefs.data.showFPS;

	public static var framerate(get, never):Int;

	static function get_framerate():Int
		return ClientPrefs.data.framerate;

	public static var naughtyness(get, never):Bool;

	static function get_naughtyness():Bool
		return true;

	public static var globalOffset(get, never):Int;

	static function get_globalOffset():Int
		return ClientPrefs.data.noteOffset;

	/** Flux muestra los subtítulos de V-Slice siempre. */
	public static var subtitles(get, never):Bool;

	static function get_subtitles():Bool
		return true;

	public static var autoPause(get, never):Bool;

	static function get_autoPause():Bool
		return ClientPrefs.data.autoPause;

	public static var strumlineBackgroundOpacity(get, never):Float;

	static function get_strumlineBackgroundOpacity():Float
		return 0;

	public static var screenshotFormat(get, never):String;

	static function get_screenshotFormat():String
		return 'png';
}

/** FunkinSound de V-Slice (lo básico). */
@:keep
class VSFunkinSound
{
	public static function playOnce(key:Dynamic, volume:Float = 1.0, ?onComplete:Void->Void, ?onLoad:Void->Void):FlxSound
		return FlxG.sound.play(key, volume, false, null, true, onComplete);

	public static function load(key:Dynamic, volume:Float = 1.0, looped:Bool = false, autoDestroy:Bool = false, autoPlay:Bool = false,
			?onComplete:Void->Void):FlxSound
	{
		var sound:FlxSound = FlxG.sound.load(key, volume, looped, null, autoDestroy, autoPlay, null, onComplete);
		return sound;
	}

	public static function playMusic(key:String, ?params:Dynamic):Bool
	{
		var volume:Float = (params != null && params.startingVolume != null) ? params.startingVolume : 1.0;
		var loop:Bool = (params != null && params.loop != null) ? params.loop : true;
		FlxG.sound.playMusic(Paths.music(key), volume, loop);
		return true;
	}
}

/**
 * funkin.Assets de V-Slice (en los .hxc también openfl.utils.Assets y lime.utils.Assets).
 * En V-Slice, Polymod pone los archivos de los mods dentro de Assets; en Flux se leen
 * del disco. "assets/shaders/x.frag", "shared:assets/shared/images/x.png" o la ruta que
 * devuelve Paths se buscan en el mod actual, los globales y el mod del módulo; si no
 * están, se usa Assets de OpenFL (los archivos del juego).
 */
@:keep
class VSAssets
{
	/** Carpetas de contenido: lo que no es una de estas después de "assets/" es una biblioteca de V-Slice (shared, week1...). */
	static var CONTENT_FOLDERS:Array<String> = [
		'data', 'images', 'sounds', 'music', 'songs', 'shaders', 'fonts', 'videos', 'characters', 'stages', 'weeks', 'scripts'
	];

	public static var cache(get, never):openfl.utils.IAssetCache;

	static function get_cache():openfl.utils.IAssetCache
		return openfl.utils.Assets.cache;

	public static function getPath(path:String):String
	{
		var file:String = findFile(path);
		return file != null ? file : path;
	}

	public static function exists(path:String, ?type:openfl.utils.AssetType):Bool
	{
		if (findFile(path) != null)
			return true;
		return path != null && openfl.utils.Assets.exists(path, type);
	}

	public static function getText(path:String):String
	{
		var file:String = findFile(path);
		if (file != null)
			return File.getContent(file);
		return (path != null && openfl.utils.Assets.exists(path, TEXT)) ? openfl.utils.Assets.getText(path) : null;
	}

	public static function getBytes(path:String):haxe.io.Bytes
	{
		var file:String = findFile(path);
		if (file != null)
			return File.getBytes(file);
		return (path != null && openfl.utils.Assets.exists(path)) ? openfl.utils.Assets.getBytes(path) : null;
	}

	public static function getBitmapData(path:String, useCache:Bool = true):openfl.display.BitmapData
	{
		var file:String = findFile(path);
		if (file != null)
		{
			var graphic:flixel.graphics.FlxGraphic = useCache ? FlxG.bitmap.get(file) : null;
			return graphic != null ? graphic.bitmap : openfl.display.BitmapData.fromFile(file);
		}
		return (path != null && openfl.utils.Assets.exists(path, IMAGE)) ? openfl.utils.Assets.getBitmapData(path, useCache) : null;
	}

	public static function getSound(path:String):openfl.media.Sound
	{
		var file:String = findFile(path);
		if (file != null)
			return openfl.media.Sound.fromFile(file);
		return (path != null && openfl.utils.Assets.exists(path, SOUND)) ? openfl.utils.Assets.getSound(path) : null;
	}

	public static function getMusic(path:String):openfl.media.Sound
	{
		var file:String = findFile(path);
		if (file != null)
			return openfl.media.Sound.fromFile(file);
		return (path != null && openfl.utils.Assets.exists(path, MUSIC)) ? openfl.utils.Assets.getMusic(path) : null;
	}

	public static function loadText(path:String):lime.app.Future<String>
		return lime.app.Future.withValue(getText(path));

	public static function loadBytes(path:String):lime.app.Future<haxe.io.Bytes>
		return lime.app.Future.withValue(getBytes(path));

	public static function loadBitmapData(path:String):lime.app.Future<openfl.display.BitmapData>
		return lime.app.Future.withValue(getBitmapData(path));

	public static function loadSound(path:String):lime.app.Future<openfl.media.Sound>
		return lime.app.Future.withValue(getSound(path));

	public static function loadMusic(path:String):lime.app.Future<openfl.media.Sound>
		return lime.app.Future.withValue(getMusic(path));

	public static function hasLibrary(name:String):Bool
		return openfl.utils.Assets.hasLibrary(name);

	public static function getLibrary(name:String):lime.utils.AssetLibrary
		return openfl.utils.Assets.getLibrary(name);

	/** Los archivos del juego y los de los mods activos (como "assets/data/..."). */
	public static function list(?type:openfl.utils.AssetType):Array<String>
	{
		var result:Array<String> = openfl.utils.Assets.list(type);
		#if MODS_ALLOWED
		var extensions:Array<String> = extensionsOf(type);
		for (mod in FluxVSliceModules.enabledMods)
			listFolder(Paths.mods(mod), '', 0, extensions, result);
		#end
		return result;
	}

	static function listFolder(dir:String, relative:String, depth:Int, extensions:Array<String>, out:Array<String>):Void
	{
		if (depth > 8 || !FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
			return;
		for (entry in FileSystem.readDirectory(dir))
		{
			var path:String = '$dir/$entry';
			var rel:String = relative.length > 0 ? '$relative/$entry' : entry;
			if (FileSystem.isDirectory(path))
				listFolder(path, rel, depth + 1, extensions, out);
			else if (extensions == null || extensions.contains(haxe.io.Path.extension(entry).toLowerCase()))
			{
				var id:String = 'assets/$rel';
				if (!out.contains(id))
					out.push(id);
			}
		}
	}

	static function extensionsOf(type:openfl.utils.AssetType):Array<String>
	{
		if (type == null)
			return null;
		return switch (type)
		{
			case TEXT: ['json', 'txt', 'xml', 'frag', 'vert', 'hx', 'hxc', 'hxs', 'lua', 'csv', 'yaml', 'srt'];
			case IMAGE: ['png', 'jpg', 'jpeg', 'bmp'];
			case SOUND | MUSIC: ['ogg', 'wav', 'mp3'];
			case FONT: ['ttf', 'otf'];
			default: null;
		}
	}

	/** El archivo de verdad para una ruta de V-Slice o de Psych, o null si no existe. */
	public static function findFile(path:String):String
	{
		if (path == null || path.length == 0)
			return null;
		#if sys
		if (isFile(path))
			return path;
		var key:String = contentPath(path);
		if (key.length == 0)
			return null;
		if (key != path && isFile(key))
			return key;
		#if MODS_ALLOWED
		var found:Dynamic = FluxVSliceModules.withModFallback(function():Dynamic {
			var modPath:String = Paths.modFolders(key);
			return isFile(modPath) ? modPath : null;
		});
		if (found != null)
			return found;
		#end
		for (candidate in [Paths.getSharedPath(key), 'assets/$key'])
			if (isFile(candidate))
				return candidate;
		#end
		return null;
	}

	/**
	 * La parte de la ruta que sirve para buscar en los mods:
	 * "shared:assets/shared/images/a.png" -> "images/a.png", "assets/data/x.json" -> "data/x.json",
	 * "mods/MiMod/shaders/x.frag" -> "shaders/x.frag".
	 */
	public static function contentPath(path:String):String
	{
		var p:String = path.split('\\').join('/');
		var colon:Int = p.indexOf(':');
		var slash:Int = p.indexOf('/');
		if (colon > 1 && (slash < 0 || colon < slash))
			p = p.substr(colon + 1); // "biblioteca:ruta" de V-Slice
		while (p.startsWith('./'))
			p = p.substr(2);

		if (p.startsWith('mods/'))
		{
			p = p.substr(5);
			var cut:Int = p.indexOf('/');
			if (cut > 0 && !CONTENT_FOLDERS.contains(p.substr(0, cut).toLowerCase()))
				p = p.substr(cut + 1); // mods/<mod>/...
		}
		else if (p.startsWith('assets/'))
		{
			p = p.substr(7);
			var cut:Int = p.indexOf('/');
			if (cut > 0 && !CONTENT_FOLDERS.contains(p.substr(0, cut).toLowerCase()))
				p = p.substr(cut + 1); // assets/<biblioteca>/...
		}
		return p;
	}

	static inline function isFile(path:String):Bool
		return path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path);
}

/** CharacterType de V-Slice (en Flux son textos). */
@:keep
class VSCharacterType
{
	public static var BF(default, null):String = 'bf';
	public static var DAD(default, null):String = 'dad';
	public static var GF(default, null):String = 'gf';
	public static var OTHER(default, null):String = 'other';
}

/**
 * CharacterDataParser de V-Slice: crea personajes de Psych o de V-Slice
 * (data/characters/<id>.json), del mod actual, los globales o el del módulo.
 */
@:keep
class VSCharacterDataParser
{
	/** Un personaje nuevo (todavía no está en el escenario), o null si no existe. */
	public static function fetchCharacter(charId:String, ?debug:Bool = false):objects.Character
	{
		if (charId == null || charId.length == 0)
			return null;
		return FluxVSliceModules.withModFallback(function():Dynamic {
			return characterExists(charId) ? new objects.Character(0, 0, charId, false) : null;
		});
	}

	/** Los datos de V-Slice del personaje (o lo básico de uno de Psych), o null. */
	public static function fetchCharacterData(charId:String):Dynamic
	{
		if (charId == null || charId.length == 0)
			return null;
		return FluxVSliceModules.withModFallback(function():Dynamic {
			#if FLUX_VSLICE
			var data:Dynamic = flux.vslice.FluxVSliceCharacters.find(charId);
			if (data != null)
				return data;
			#end
			var path:String = Paths.getPath('characters/$charId.json', TEXT);
			if (!FileSystem.exists(path))
				return null;
			var json:Dynamic = haxe.Json.parse(File.getContent(path));
			return {
				name: charId,
				assetPath: json.image,
				healthIcon: {id: json.healthicon != null ? json.healthicon : charId},
				flipX: json.flip_x == true,
				scale: json.scale != null ? json.scale : 1.0,
				singTime: json.sing_duration != null ? json.sing_duration : 4.0
			};
		});
	}

	/** parseCharacterData de V-Slice (los datos del personaje). */
	public static function parseCharacterData(charId:String):Dynamic
		return fetchCharacterData(charId);

	public static function characterExists(charId:String):Bool
	{
		if (charId == null || charId.length == 0)
			return false;
		if (FileSystem.exists(Paths.getPath('characters/$charId.json', TEXT)))
			return true;
		#if FLUX_VSLICE
		return flux.vslice.FluxVSliceCharacters.find(charId) != null;
		#else
		return false;
		#end
	}

	/** Los ids de todos los personajes (de Psych y de V-Slice), también en minúsculas. */
	public static function listCharacterIds():Array<String>
	{
		var ids:Array<String> = [];
		var folders:Array<String> = [];
		for (sub in ['characters/', 'data/characters/'])
			for (dir in Mods.directoriesWithFile(Paths.getSharedPath(), sub))
				folders.push(dir);
		#if MODS_ALLOWED
		for (mod in FluxVSliceModules.enabledMods)
			for (sub in ['characters/', 'data/characters/'])
				folders.push(Paths.mods('$mod/$sub'));
		#end
		for (dir in folders)
		{
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
				continue;
			for (file in FileSystem.readDirectory(dir))
			{
				if (!file.toLowerCase().endsWith('.json'))
					continue;
				var id:String = file.substr(0, file.length - 5);
				for (name in [id, id.toLowerCase()])
					if (!ids.contains(name))
						ids.push(name);
			}
		}
		return ids;
	}
}

/** Un evento del chart como SongEventData de V-Slice (PlayState.songEvents). */
@:keep
class VSSongEventData
{
	public var time:Float;
	public var eventKind:String;
	public var value:Dynamic;

	/** Los valores como llegan a Psych (el valor de V-Slice va en JSON en value1). */
	public var value1:String = null;

	public var value2:String = null;

	/** true cuando ya se hizo el evento. */
	public var handled:Bool = false;

	public function new(time:Float, eventKind:String, value:Dynamic)
	{
		this.time = time;
		this.eventKind = eventKind;
		this.value = value;
	}

	/** Si ya pasó (V-Slice lo marca al ejecutarlo). */
	public var activated(get, set):Bool;

	function get_activated():Bool
		return handled || Conductor.songPosition >= time;

	function set_activated(value:Bool):Bool
		return handled = value;

	public function getDynamic(key:String):Dynamic
		return (value != null && Reflect.isObject(value) && !Std.isOfType(value, String)) ? Reflect.field(value, key) : null;

	public function getBool(key:String):Null<Bool>
	{
		var v:Dynamic = getDynamic(key);
		return v == null ? null : (v == true || v == 'true');
	}

	public function getInt(key:String):Null<Int>
	{
		var v:Dynamic = getDynamic(key);
		if (v == null)
			return null;
		if (Std.isOfType(v, Int))
			return v;
		if (Std.isOfType(v, Float))
			return Std.int(v);
		return Std.parseInt(Std.string(v));
	}

	public function getFloat(key:String):Null<Float>
	{
		var v:Dynamic = getDynamic(key);
		if (v == null)
			return null;
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int))
			return v;
		var parsed:Float = Std.parseFloat(Std.string(v));
		return Math.isNaN(parsed) ? null : parsed;
	}

	public function getString(key:String):String
	{
		var v:Dynamic = getDynamic(key);
		return v == null ? null : Std.string(v);
	}

	public function getArray(key:String):Array<Dynamic>
	{
		var v:Dynamic = getDynamic(key);
		return Std.isOfType(v, Array) ? v : null;
	}

	/** El valor como objeto (si era un número o texto, queda en el campo `defaultKey`). */
	public function valueAsStruct(?defaultKey:String = 'key'):Dynamic
	{
		if (value != null && Reflect.isObject(value) && !Std.isOfType(value, String) && !Std.isOfType(value, Array))
			return value;
		var result:Dynamic = {};
		Reflect.setField(result, defaultKey, value);
		return result;
	}

	public function clone():VSSongEventData
		return new VSSongEventData(time, eventKind, value);

	public function toString():String
		return 'SongEventData($time ms, $eventKind, $value)';
}

/**
 * Lugar para los tipos de V-Slice que Flux todavía no tiene. `x is ElTipo` da
 * false y crearlo o usarlo muestra un error claro (no rompe el resto del módulo).
 */
@:keep
class VSMissing
{
	public function new()
	{
		throw 'Este tipo de V-Slice todavía no existe en Flux Engine';
	}
}
#end
