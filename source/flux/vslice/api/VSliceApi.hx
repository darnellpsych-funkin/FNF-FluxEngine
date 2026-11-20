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
		return Paths.json(key);

	public static function txt(key:String, ?library:String):String
		return Paths.txt(key);

	public static function xml(key:String, ?library:String):String
		return Paths.xml(key);

	public static function file(file:String, ?library:String):String
		return Paths.getPath(file);

	public static function frag(key:String):String
		return Paths.getPath('shaders/$key.frag');

	public static function vert(key:String):String
		return Paths.getPath('shaders/$key.vert');

	public static function video(key:String):String
		return Paths.video(key);
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
