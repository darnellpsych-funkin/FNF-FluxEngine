package flux.dave;

#if FLUX_DAVE_SCRIPTS
import backend.Difficulty;
import backend.Paths;
import flixel.FlxG;
import flux.dave.api.DaveModule;
import flux.vslice.api.ScriptEvent;
import flux.vslice.modules.FluxVSliceModules;
import haxe.ds.ArraySort;
import states.PlayState;

/**
 * Los módulos de Dave Engine (scripts/modules/ de un mod de Dave), como su ModuleHandler
 * y su SongModuleHandler:
 *
 *  - `class X extends Module` (en un mod de Dave): un script global. Recibe los eventos de
 *    las canciones de Dave y, en todos los menús, onUpdate, onStateChange y onStateChangePost.
 *  - `class X extends SongModule` con `super('id', prioridad, 'cancion', ?'variacion')`:
 *    corre solo en esa canción. Se crea uno nuevo cada vez que empieza la canción.
 *
 * En una canción el orden es el de Dave: los módulos globales, los de la canción, el
 * escenario y los personajes (FluxDaveStage.dispatch).
 */
class DaveModules
{
	/** Los módulos globales (por prioridad). */
	public static var modules(default, null):Array<DaveModule> = [];

	/** Los SongModule de la canción que se está jugando (por prioridad). */
	public static var songModules(default, null):Array<DaveSongModule> = [];

	/** El id de la canción de los SongModule cargados (null fuera de una canción). */
	public static var currentSong(default, null):String = null;

	static var globalClasses:Array<String> = [];
	static var songClassNames:Array<String> = [];

	/** canción -> variación -> clases de SongModule. */
	static var songClasses:Map<String, Map<String, Array<String>>> = new Map<String, Map<String, Array<String>>>();

	static var signalsReady:Bool = false;

	/** La variación de Dave: '' o null es 'default'. */
	public static function validateVariation(variation:String):String
		return (variation == null || variation == '' || variation == 'default') ? 'default' : variation;

	/** Lo llama FluxVSliceModules antes de leer los .hxc de nuevo. */
	public static function clear():Void
	{
		endSong();
		if (modules.length > 0)
			dispatchGlobal('onDestroy', new ScriptEvent('destroy'));
		modules = [];
		globalClasses = [];
		songClassNames = [];
		songClasses = new Map<String, Map<String, Array<String>>>();
	}

	/** Guarda una clase de módulo (DaveScripts.register). */
	public static function addClass(name:String, songModule:Bool):Void
	{
		var list:Array<String> = songModule ? songClassNames : globalClasses;
		if (!list.contains(name))
			list.push(name);
	}

	public static inline function hasModules():Bool
		return modules.length > 0 || songModules.length > 0;

	/** Si hay algún SongModule para esa canción (en cualquier variación). */
	public static function hasSongModules(songId:String):Bool
		return songId != null && songClasses.exists(Paths.formatToSongPath(songId));

	/**
	 * Crea los módulos globales y anota a qué canción va cada SongModule (como Dave, crea
	 * cada SongModule una vez para leer su `super(...)`). Lo llama FluxVSliceModules.reload.
	 */
	public static function load():Array<String>
	{
		var loaded:Array<String> = [];
		initSignals();

		for (name in songClassNames)
		{
			var module:DaveSongModule = createSongModule(name);
			if (module == null)
				continue;
			var song:String = module.songId != null ? Paths.formatToSongPath(module.songId) : null;
			if (song == null || song.length == 0)
			{
				DaveScripts.report(module, 'el SongModule no dice su canción (super(id, prioridad, "cancion"))');
				continue;
			}
			var variations:Map<String, Array<String>> = songClasses.get(song);
			if (variations == null)
			{
				variations = new Map<String, Array<String>>();
				songClasses.set(song, variations);
			}
			var variation:String = validateVariation(module.variation);
			var list:Array<String> = variations.get(variation);
			if (list == null)
			{
				list = [];
				variations.set(variation, list);
			}
			if (!list.contains(name))
				list.push(name);
			loaded.push('$name ($song${variation != 'default' ? ' $variation' : ''})');
		}

		for (name in globalClasses)
		{
			var module:FluxScriptedDaveModule = null;
			try
			{
				module = new FluxScriptedDaveModule(name, []);
			}
			catch (e:Dynamic)
			{
				DaveScripts.reportClass(name, 'no se pudo crear: $e');
				continue;
			}
			modules.push(module);
			loaded.push('$name (global)');
		}
		sortModules(modules);
		if (modules.length > 0)
			dispatchGlobal('onCreate', new ScriptEvent('create'));
		return loaded;
	}

	static function createSongModule(name:String):DaveSongModule
	{
		try
		{
			return new FluxScriptedDaveSongModule(name, []);
		}
		catch (e:Dynamic)
		{
			DaveScripts.reportClass(name, 'no se pudo crear: $e');
		}
		return null;
	}

	// ----- La canción -----

	/** La variación de Dave de la dificultad actual ('default' para la normal). */
	public static function currentVariation():String
	{
		var diff:String = Paths.formatToSongPath(Difficulty.getString(PlayState.storyDifficulty, false));
		if (diff == null || diff.length == 0 || diff == 'normal' || diff == Paths.formatToSongPath(Difficulty.getDefault()))
			return 'default';
		return diff;
	}

	/**
	 * Crea los SongModule de la canción (antes de los personajes, como Dave): initalize()
	 * y onCreate. Lo llama PlayState.create en las canciones de Dave.
	 */
	public static function startSong(songId:String, ?variation:String):Int
	{
		endSong();
		DavePreloader.reset();
		if (songId == null)
			return 0;
		var id:String = Paths.formatToSongPath(songId);
		currentSong = id;
		var variations:Map<String, Array<String>> = songClasses.get(id);
		if (variations == null)
			return 0;
		var names:Array<String> = variations.get(validateVariation(variation != null ? variation : currentVariation()));
		if (names == null)
			return 0;
		for (name in names)
		{
			var module:DaveSongModule = createSongModule(name);
			if (module != null)
				songModules.push(module);
		}
		sortModules(songModules);
		for (module in songModules.copy())
		{
			try
			{
				module.initalize();
			}
			catch (e:Dynamic)
			{
				DaveScripts.report(module, e);
			}
		}
		dispatchSong('onCreate', new ScriptEvent('create'));
		return songModules.length;
	}

	/** Borra los SongModule de la canción (con su onDestroy, si `notify`). */
	public static function endSong(notify:Bool = true):Void
	{
		if (notify && songModules.length > 0)
			dispatchSong('onDestroy', new ScriptEvent('destroy'));
		songModules = [];
		currentSong = null;
	}

	// ----- Eventos -----

	/** Un evento de la canción: los módulos globales y después los de la canción. */
	public static function dispatch(method:String, event:Dynamic, includeGlobal:Bool = true):Void
	{
		if (includeGlobal)
			dispatchGlobal(method, event);
		dispatchSong(method, event);
	}

	public static function dispatchGlobal(method:String, event:Dynamic):Void
	{
		for (module in modules.copy())
			if (module != null && module.enabled)
				DaveScripts.dispatch(module, method, event);
	}

	public static function dispatchSong(method:String, event:Dynamic):Void
	{
		for (module in songModules.copy())
			if (module != null && module.enabled)
				DaveScripts.dispatch(module, method, event);
	}

	static function initSignals():Void
	{
		if (signalsReady)
			return;
		signalsReady = true;
		// en una canción de Dave, onUpdate llega por el escenario (FluxDaveStage)
		FlxG.signals.postUpdate.add(function() {
			if (modules.length > 0)
				dispatchGlobal('onUpdate', new UpdateScriptEvent(FlxG.elapsed));
		});
		FlxG.signals.preStateSwitch.add(function() {
			if (modules.length > 0)
				dispatchGlobal('onStateChange', new DaveStateChangeEvent('state_change', FlxG.state, true));
		});
		FlxG.signals.postStateSwitch.add(function() {
			if (modules.length > 0)
				dispatchGlobal('onStateChangePost', new DaveStateChangeEvent('state_change_post', FlxG.state, true));
		});
	}

	// ----- SongModuleHandler / ModuleHandler de Dave -----

	/** Un SongModule de la canción por su id. */
	public static function getSongModule(id:String):DaveSongModule
	{
		for (module in songModules)
			if (module.moduleId == id)
				return module;
		return null;
	}

	/** Un módulo global por su id. */
	public static function getModule(id:String):DaveModule
	{
		for (module in modules)
			if (module.moduleId == id)
				return module;
		return null;
	}

	/** Vuelve a ordenar por prioridad (cuando un SongModule cambia su priority). */
	public static function reorder():Void
	{
		sortModules(songModules);
		sortModules(modules);
	}

	static function sortModules<T:Dynamic>(list:Array<T>):Void
	{
		ArraySort.sort(list, function(a:T, b:T):Int {
			if (a == null || b == null)
				return 0;
			var pa:Int = Reflect.getProperty(a, 'priority');
			var pb:Int = Reflect.getProperty(b, 'priority');
			if (pa != pb)
				return pa - pb;
			var ia:String = Reflect.getProperty(a, 'moduleId');
			var ib:String = Reflect.getProperty(b, 'moduleId');
			return ia < ib ? -1 : (ia > ib ? 1 : 0);
		});
	}
}

/** SongModuleHandler de Dave Engine (para los scripts). */
@:keep
class DaveSongModuleHandler
{
	public static function getModule(id:String):DaveSongModule
		return DaveModules.getSongModule(id);

	public static function enableModule(id:String, ?songId:String, ?variation:String):Void
	{
		var module:DaveSongModule = DaveModules.getSongModule(id);
		if (module != null)
			module.activate();
	}

	public static function disableModule(id:String, ?songId:String, ?variation:String):Void
	{
		var module:DaveSongModule = DaveModules.getSongModule(id);
		if (module != null)
			module.deactivate();
	}

	public static function reorderModules():Void
		DaveModules.reorder();

	public static function callOnModules(event:Dynamic):Void
	{
		var method:String = FluxDaveStage.methodOf(event);
		if (method != null)
			DaveModules.dispatchSong(method, event);
	}
}

/** ModuleHandler de Dave Engine (para los scripts). */
@:keep
class DaveModuleHandler
{
	public static function getModule(id:String):DaveModule
		return DaveModules.getModule(id);

	public static function callEvent(event:Dynamic):Void
	{
		var method:String = FluxDaveStage.methodOf(event);
		if (method != null)
			DaveModules.dispatchGlobal(method, event);
	}
}

/**
 * Preloader de Dave Engine. cacheCharacter deja listo el personaje para un
 * switchDad/switchBF/switchGF (en Psych: addCharacterToList). Si todavía no hay
 * personajes (en onCreate), se hace apenas existan.
 */
@:keep
class DavePreloader
{
	public static var trackedCharacters(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	static var pending:Array<{id:String, type:String}> = [];

	public static function reset():Void
	{
		pending = [];
		trackedCharacters = new Map<String, Dynamic>();
	}

	public static function cacheCharacter(id:String, ?type:Dynamic):Void
	{
		if (id == null || id.length == 0)
			return;
		var kind:String = type != null ? Std.string(type) : 'OPPONENT';
		var game:PlayState = PlayState.instance;
		if (game != null && game.dad != null && game.boyfriendGroup != null)
			precache(game, id, kind);
		else
			pending.push({id: id, type: kind});
	}

	/** Lo que se pidió antes de que existieran los personajes (lo llama PlayState). */
	public static function flush(game:PlayState):Void
	{
		var list = pending;
		pending = [];
		if (game != null)
			for (entry in list)
				precache(game, entry.id, entry.type);
	}

	static function precache(game:PlayState, id:String, kind:String):Void
	{
		var type:Int = switch (kind)
		{
			case 'PLAYER': 0;
			case 'GF': 2;
			case 'OPPONENT': 1;
			default: -1;
		}
		if (type < 0)
			return; // OTHER: Psych no tiene dónde guardarlo
		// queda oculto en el mapa del PlayState; el onCharacterAdd del escenario va cuando se use (switchDad)
		FluxDaveStage.quiet = true;
		try
		{
			game.addCharacterToList(id, type);
			var map:Map<String, objects.Character> = type == 0 ? game.boyfriendMap : (type == 2 ? game.gfMap : game.dadMap);
			if (map.exists(id))
				trackedCharacters.set(id, map.get(id));
		}
		catch (e:Dynamic)
		{
			FluxVSliceModules.reportError('Preloader.cacheCharacter($id)', Std.string(e));
		}
		FluxDaveStage.quiet = false;
	}

	public static function cacheImage(key:Dynamic):Dynamic
		return Std.isOfType(key, String) ? flux.dave.api.DaveApi.DavePaths.image(key) : key;

	public static function cacheSound(key:String):Dynamic
		return flux.dave.api.DaveApi.DavePaths.sound(key);

	public static function cacheShader(shader:Dynamic):Void {}

	public static function cacheNoteStyle(style:Dynamic):Void {}

	public static function removeCachedCharacter(id:String):Void
		trackedCharacters.remove(id);
}
#end
