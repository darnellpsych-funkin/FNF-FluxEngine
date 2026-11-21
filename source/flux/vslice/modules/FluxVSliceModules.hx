package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
import backend.Conductor;
import backend.Difficulty;
import backend.Mods;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.util.FlxColor;
import flux.vslice.api.Module;
import flux.vslice.api.ScriptEvent;
import flux.vslice.api.VSliceApi.VSScoring;
import flux.vslice.modules.HxcLoader;
import haxe.ds.ObjectMap;
import objects.Note;
import rulescript.RuleScript;
import rulescript.scriptedClass.RuleScriptedClassUtil;
import states.PlayState;
import sys.FileSystem;
import sys.io.File;

using StringTools;

typedef VSliceClassInfo =
{
	var name:String;
	var superName:String;
	var mod:String;
	var file:String;
}

/**
 * Módulos de V-Slice (.hxc) en Flux Engine.
 *
 * Al empezar el juego (y cada vez que cambia la lista de mods activos) busca
 * los .hxc de todos los mods activos, crea una instancia de cada clase que
 * hace `extends Module` y le manda los eventos del juego, igual que el
 * ModuleHandler de V-Slice:
 *
 *   - onUpdate (cada frame, en cualquier menú), onStateChangeBegin/End,
 *     onSubStateOpenEnd/CloseEnd, onFocusLost/Gained, onCreate/onDestroy.
 *   - En PlayState: onSongLoaded, onCountdownStart/Step/End, onSongStart,
 *     onSongEnd, onNoteIncoming, onNoteHit, onNoteMiss, onNoteGhostMiss,
 *     onSongEvent, onBeatHit, onStepHit, onPause, onResume, onGameOver.
 *     Los que se pueden cancelar (event.cancel()) frenan lo que haría Psych.
 *
 * Por ahora solo se usan las clases que extienden Module; las de canciones,
 * escenarios y personajes (Song, Stage, Character...) se ignoran con un aviso.
 */
class FluxVSliceModules
{
	/** Módulos activos ordenados por prioridad. */
	public static var modules(default, null):Array<Module> = [];

	/** Clases encontradas en los .hxc (nombre -> datos). */
	public static var classes(default, null):Map<String, VSliceClassInfo> = new Map<String, VSliceClassInfo>();

	/** Mods activos cuando se cargaron los módulos. */
	public static var enabledMods(default, null):Array<String> = [];

	/** Nota que un módulo está pegando ahora mismo (para no mandar onNoteHit dos veces). */
	public static var moduleNoteHit:Note = null;

	static var classOrder:Array<String> = [];
	static var moduleInfo:ObjectMap<Module, VSliceClassInfo> = new ObjectMap<Module, VSliceClassInfo>();
	static var initialized:Bool = false;
	static var loadedSignature:String = null;
	static var hookedState:FlxState = null;
	static var currentMod:String = null;
	static var errorCounts:Map<String, Int> = new Map<String, Int>();
	static var missingReported:Map<String, Bool> = new Map<String, Bool>();

	/** Carpetas de un mod donde nunca hay .hxc (para buscar más rápido). */
	static var SKIP_FOLDERS:Array<String> = ['images', 'music', 'sounds', 'songs', 'videos', 'fonts', 'shaders'];

	public static function init():Void
	{
		if (initialized)
			return;
		initialized = true;

		#if FLUX_SCRIPTS_ALLOWED
		flux.scripting.FluxScriptHandler.init();
		#end
		RuleScriptedClassUtil.buildBridge = buildRuleScript;

		FlxG.signals.preStateCreate.add(onPreStateCreate);
		FlxG.signals.postStateSwitch.add(onPostStateSwitch);
		FlxG.signals.postUpdate.add(onPostUpdate);
		FlxG.signals.focusLost.add(function() if (hasModules()) callEvent(new FocusScriptEvent(ScriptEventType.FOCUS_LOST)));
		FlxG.signals.focusGained.add(function() if (hasModules()) callEvent(new FocusScriptEvent(ScriptEventType.FOCUS_GAINED)));
	}

	public static inline function hasModules():Bool
		return modules.length > 0;

	// ----- Carga -----

	/** Carga los módulos de nuevo si cambió la lista de mods (o siempre si force es true). */
	public static function reload(force:Bool = false):Void
	{
		var mods:Array<String> = getEnabledMods();
		var signature:String = mods.join('|');
		if (!force && signature == loadedSignature)
			return;
		loadedSignature = signature;
		enabledMods = mods;

		unloadAll();

		for (mod in mods)
		{
			var files:Array<String> = [];
			collectFiles(Paths.mods(mod), 0, files);
			for (file in files)
				registerFile(mod, file);
		}

		var loaded:Array<String> = [];
		var ignored:Array<String> = [];
		for (name in classOrder)
		{
			var info:VSliceClassInfo = classes.get(name);
			if (info.superName != 'Module' && info.superName != 'ScriptedModule')
			{
				ignored.push('${info.name} (extends ${info.superName})');
				continue;
			}

			var module:Module = null;
			try
			{
				module = new FluxScriptedModule(info.name, [info.name]);
			}
			catch (e:Dynamic)
			{
				reportError('${info.name} (${info.file})', 'no se pudo crear: ' + errorText(e));
				continue;
			}
			moduleInfo.set(module, info);
			modules.push(module);
			loaded.push('${info.name} [${info.mod}]');
		}
		reorder();

		if (loaded.length > 0)
			log('Módulos de V-Slice cargados: ' + loaded.join(', '));
		if (ignored.length > 0)
			log('Clases de V-Slice que Flux todavía no usa (por ahora solo módulos): ' + ignored.join(', '));

		callEvent(new ScriptEvent(ScriptEventType.CREATE));
	}

	static function unloadAll():Void
	{
		if (hasModules())
			callEvent(new ScriptEvent(ScriptEventType.DESTROY));
		for (name in classOrder)
			RuleScriptedClassUtil.types.remove(name);
		modules = [];
		moduleInfo = new ObjectMap<Module, VSliceClassInfo>();
		classes = new Map<String, VSliceClassInfo>();
		classOrder = [];
		errorCounts = new Map<String, Int>();
		missingReported = new Map<String, Bool>();
	}

	static function getEnabledMods():Array<String>
	{
		var list:Array<String> = [];
		#if MODS_ALLOWED
		try
		{
			for (mod in Mods.parseList().enabled)
				if (mod != null && mod.length > 0 && FileSystem.isDirectory(Paths.mods(mod)))
					list.push(mod);
		}
		catch (e:Dynamic)
		{
			log('No se pudo leer modsList.txt: $e');
		}
		#end
		return list;
	}

	static function collectFiles(dir:String, depth:Int, out:Array<String>):Void
	{
		if (depth > 8 || !FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
			return;
		var entries:Array<String> = FileSystem.readDirectory(dir);
		entries.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));
		for (entry in entries)
		{
			var path:String = dir + '/' + entry;
			if (FileSystem.isDirectory(path))
			{
				if (depth == 0 && SKIP_FOLDERS.contains(entry.toLowerCase()))
					continue;
				collectFiles(path, depth + 1, out);
			}
			else if (entry.toLowerCase().endsWith('.hxc'))
				out.push(path);
		}
	}

	static function registerFile(mod:String, file:String):Void
	{
		var parsed:Array<HxcClass>;
		try
		{
			parsed = HxcLoader.parse(File.getContent(file), file);
		}
		catch (e:Dynamic)
		{
			reportError(file, 'no se pudo leer: ' + errorText(e));
			return;
		}

		for (c in parsed)
		{
			if (classes.exists(c.name))
			{
				log('La clase ${c.name} está repetida (${classes.get(c.name).file} y $file); se usa la de $file.');
				classOrder.remove(c.name);
			}
			classes.set(c.name, {
				name: c.name,
				superName: c.superName,
				mod: mod,
				file: file
			});
			classOrder.push(c.name);
			RuleScriptedClassUtil.registerRuleScriptedClass(c.name, c.expr);
		}
	}

	/** RuleScript llama esto al crear cada FluxScriptedModule. */
	static function buildRuleScript(typeName:String, superInstance:Dynamic):RuleScript
	{
		var info:VSliceClassInfo = classes.get(typeName);
		var where:String = info != null ? '${info.name} (${info.file})' : typeName;

		var interp:FluxVSliceInterp = new FluxVSliceInterp();
		var script:RuleScript = new RuleScript(interp);
		script.scriptName = info != null ? info.file : typeName;
		script.superInstance = superInstance;
		script.errorHandler = function(e:haxe.Exception):Dynamic {
			reportError(where, errorText(e));
			return null;
		};
		interp.skipNextRestore = true;
		script.execute(RuleScriptedClassUtil.types.get(typeName));

		if (interp.missingTypes.length > 0)
		{
			// una vez por archivo (las clases del mismo .hxc comparten los imports)
			var key:String = (info != null ? info.file : typeName) + '|' + interp.missingTypes.join(',');
			if (!missingReported.exists(key))
			{
				missingReported.set(key, true);
				log('${info != null ? info.file : typeName} usa cosas de V-Slice que Flux todavía no tiene: ${interp.missingTypes.join(', ')} (esas partes no van a funcionar).');
			}
		}
		return script;
	}

	// ----- Eventos -----

	/** Manda el evento a todos los módulos activos (por prioridad). */
	public static function callEvent(event:ScriptEvent):Void
	{
		if (event == null || modules.length == 0)
			return;
		for (module in modules.copy())
		{
			if (module == null || !module.active)
				continue;
			dispatchTo(module, event);
			if (!event.shouldPropagate)
				break;
		}
	}

	/** Llama a onScriptEvent y a la función del evento (onUpdate, onNoteHit...) del objeto. */
	public static function dispatchTo(target:Dynamic, event:ScriptEvent):Void
	{
		if (target == null || event == null)
			return;

		var info:VSliceClassInfo = Std.isOfType(target, Module) ? moduleInfo.get(cast target) : null;
		var previousMod:String = currentMod;
		if (info != null)
			currentMod = info.mod;
		try
		{
			callMethod(target, 'onScriptEvent', event);
			if (event.shouldPropagate)
			{
				var method:String = ScriptEventType.methods.get(event.type);
				if (method != null)
					callMethod(target, method, event);
			}
		}
		catch (e:Dynamic)
		{
			reportError(info != null ? '${info.name} (${info.file})' : VSliceAdapter.describe(target), errorText(e));
		}
		currentMod = previousMod;
	}

	static function callMethod(target:Dynamic, name:String, event:ScriptEvent):Void
	{
		var fn:Dynamic = Reflect.getProperty(target, name);
		if (fn != null && Reflect.isFunction(fn))
			Reflect.callMethod(target, fn, [event]);
	}

	public static function getModule(moduleId:String):Module
	{
		for (module in modules)
			if (module.moduleId == moduleId)
				return module;
		for (module in modules)
		{
			var info:VSliceClassInfo = moduleInfo.get(module);
			if (info != null && info.name == moduleId)
				return module;
		}
		return null;
	}

	public static function reorder():Void
	{
		if (modules.length > 1)
			haxe.ds.ArraySort.sort(modules, function(a:Module, b:Module):Int return a.priority - b.priority);
	}

	/**
	 * Para VSPaths: si no se encuentra un archivo en el mod actual de Psych,
	 * lo busca en el mod del módulo que está recibiendo el evento.
	 */
	public static function withModFallback(load:Void->Dynamic):Dynamic
	{
		var result:Dynamic = null;
		try
		{
			result = load();
		}
		catch (e:Dynamic)
		{
			result = null;
		}
		#if MODS_ALLOWED
		if (result == null && currentMod != null && Mods.currentModDirectory != currentMod)
		{
			var old:String = Mods.currentModDirectory;
			Mods.currentModDirectory = currentMod;
			try
			{
				result = load();
			}
			catch (e:Dynamic)
			{
				result = null;
			}
			Mods.currentModDirectory = old;
		}
		#end
		return result;
	}

	// ----- Señales de Flixel -----

	static function onPreStateCreate(state:FlxState):Void
	{
		reload();
		VSliceAdapter.clear();
		if (hasModules())
			callEvent(new StateChangeScriptEvent(ScriptEventType.STATE_CHANGE_BEGIN, state, true));
	}

	static function onPostStateSwitch():Void
	{
		var state:FlxState = FlxG.state;
		if (state != null && state != hookedState)
		{
			hookedState = state;
			state.subStateOpened.add(function(sub:FlxSubState) {
				if (hasModules())
					callEvent(new SubStateScriptEvent(ScriptEventType.SUBSTATE_OPEN_END, sub, true));
			});
			state.subStateClosed.add(function(sub:FlxSubState) {
				if (hasModules())
					callEvent(new SubStateScriptEvent(ScriptEventType.SUBSTATE_CLOSE_END, sub, true));
			});
		}
		if (hasModules())
			callEvent(new StateChangeScriptEvent(ScriptEventType.STATE_CHANGE_END, state, true));
	}

	static function onPostUpdate():Void
	{
		if (hasModules())
			callEvent(new UpdateScriptEvent(FlxG.elapsed));
	}

	// ----- Eventos de PlayState (los llama PlayState.hx) -----

	public static function onSongLoaded(game:PlayState):Void
	{
		if (!hasModules())
			return;
		var id:String = PlayState.SONG != null ? Paths.formatToSongPath(PlayState.SONG.song) : '';
		callEvent(new SongLoadScriptEvent(id, Paths.formatToSongPath(Difficulty.getString()), [], []));
	}

	/** Devuelve false si un módulo canceló la cuenta regresiva. */
	public static function onCountdownStart(game:PlayState):Bool
	{
		if (!hasModules())
			return true;
		var event:CountdownScriptEvent = new CountdownScriptEvent(ScriptEventType.COUNTDOWN_START, CountdownStep.BEFORE, true);
		callEvent(event);
		return !event.eventCanceled;
	}

	public static function onCountdownStep(game:PlayState, counter:Int):Void
	{
		if (!hasModules())
			return;
		var steps:Array<String> = [CountdownStep.THREE, CountdownStep.TWO, CountdownStep.ONE, CountdownStep.GO, CountdownStep.AFTER];
		var step:String = (counter >= 0 && counter < steps.length) ? steps[counter] : CountdownStep.AFTER;
		callEvent(new CountdownScriptEvent(ScriptEventType.COUNTDOWN_STEP, step, false));
		if (step == CountdownStep.AFTER)
			callEvent(new CountdownScriptEvent(ScriptEventType.COUNTDOWN_END, step, false));
	}

	public static function onSongStart(game:PlayState):Void
	{
		if (hasModules())
			callEvent(new ScriptEvent(ScriptEventType.SONG_START));
	}

	/** Devuelve false si un módulo canceló el final de la canción. */
	public static function onSongEnd(game:PlayState):Bool
	{
		if (!hasModules())
			return true;
		var event:ScriptEvent = new ScriptEvent(ScriptEventType.SONG_END, true);
		callEvent(event);
		return !event.eventCanceled;
	}

	public static function onNoteIncoming(game:PlayState, note:Note):Void
	{
		if (hasModules() && note != null)
			callEvent(new NoteScriptEvent(ScriptEventType.NOTE_INCOMING, note, 0, game.combo, false));
	}

	/** Devuelve false si un módulo canceló el golpe (la nota no cuenta). */
	public static function onNoteHit(game:PlayState, note:Note):Bool
	{
		if (!hasModules() || note == null || note == moduleNoteHit)
			return true;

		var hitDiff:Float = note.mustPress ? note.strumTime - Conductor.songPosition : 0;
		var judgement:String = note.isSustainNote ? 'sick' : VSScoring.judgeNote(hitDiff);
		var score:Int = note.isSustainNote ? 0 : VSScoring.scoreNote(hitDiff);
		var event:HitNoteScriptEvent = new HitNoteScriptEvent(note, note.hitHealth, score, judgement, false, game.combo, hitDiff,
			judgement == 'sick' && !note.isSustainNote);
		callEvent(event);
		return !event.eventCanceled;
	}

	/** Devuelve false si un módulo canceló el fallo. */
	public static function onNoteMiss(game:PlayState, note:Note):Bool
	{
		if (!hasModules() || note == null)
			return true;
		var event:NoteScriptEvent = new NoteScriptEvent(ScriptEventType.NOTE_MISS, note, -note.missHealth, game.combo, true);
		callEvent(event);
		return !event.eventCanceled;
	}

	/** Devuelve false si un módulo canceló el fallo por tocar sin nota. */
	public static function onGhostMiss(game:PlayState, direction:Int):Bool
	{
		if (!hasModules())
			return true;
		var event:GhostMissNoteScriptEvent = new GhostMissNoteScriptEvent(direction, false, -game.pressMissDamage, -10);
		callEvent(event);
		return !event.eventCanceled;
	}

	/** Devuelve false si un módulo canceló el evento (Psych no lo procesa, los scripts sí lo reciben). */
	public static function onSongEvent(game:PlayState, name:String, value1:String, value2:String, time:Float):Bool
	{
		if (!hasModules())
			return true;
		var data:Dynamic = {
			time: time,
			eventKind: name,
			value: eventValue(value1, value2),
			value1: value1,
			value2: value2
		};
		var event:SongEventScriptEvent = new SongEventScriptEvent(data);
		callEvent(event);
		return !event.eventCanceled;
	}

	/** El valor de un evento convertido de V-Slice viene como JSON en value1. */
	public static function eventValue(value1:String, value2:String):Dynamic
	{
		var v1:String = value1 != null ? value1.trim() : '';
		var v2:String = value2 != null ? value2.trim() : '';
		if (v2.length == 0 && v1.length > 0)
		{
			var first:String = v1.charAt(0);
			if (first == '{' || first == '[' || first == '"')
			{
				var parsed:Dynamic = null;
				try
				{
					parsed = haxe.Json.parse(v1);
				}
				catch (e:Dynamic)
				{
					parsed = null;
				}
				if (parsed != null)
					return parsed;
			}
			var number:Float = Std.parseFloat(v1);
			if (!Math.isNaN(number))
				return number;
			return value1;
		}
		return {value1: value1, value2: value2};
	}

	public static function onBeatHit(game:PlayState, beat:Int, step:Int):Void
	{
		VSliceAdapter.beatHit(game, beat); // los personajes que agregaron los scripts bailan
		if (hasModules())
			callEvent(new SongTimeScriptEvent(ScriptEventType.SONG_BEAT_HIT, beat, step));
	}

	public static function onStepHit(game:PlayState, beat:Int, step:Int):Void
	{
		if (hasModules())
			callEvent(new SongTimeScriptEvent(ScriptEventType.SONG_STEP_HIT, beat, step));
	}

	/** Devuelve false si un módulo canceló la pausa. */
	public static function onPause(game:PlayState):Bool
	{
		if (!hasModules())
			return true;
		var event:PauseScriptEvent = new PauseScriptEvent(false);
		callEvent(event);
		return !event.eventCanceled;
	}

	public static function onResume(game:PlayState):Void
	{
		if (hasModules())
			callEvent(new ScriptEvent(ScriptEventType.RESUME));
	}

	/** Devuelve false si un módulo canceló la muerte. */
	public static function onGameOver(game:PlayState):Bool
	{
		if (!hasModules())
			return true;
		var event:ScriptEvent = new ScriptEvent(ScriptEventType.GAME_OVER, true);
		callEvent(event);
		return !event.eventCanceled;
	}

	// ----- Mensajes -----

	static function log(text:String):Void
		trace('[V-Slice] $text');

	static function errorText(e:Dynamic):String
	{
		if (Std.isOfType(e, haxe.Exception))
			return (cast e : haxe.Exception).message;
		return Std.string(e);
	}

	/** Muestra un error de un módulo (en la consola y, si estás jugando, en pantalla). */
	public static function reportError(where:String, message:String):Void
	{
		var text:String = '[V-Slice] $where: $message';
		var count:Int = errorCounts.exists(text) ? errorCounts.get(text) + 1 : 1;
		errorCounts.set(text, count);
		if (count > 3)
			return;
		if (count == 3)
			text += ' (se repite, no se muestra más)';

		trace(text);
		#if (LUA_ALLOWED || HSCRIPT_ALLOWED || FLUX_SCRIPTS_ALLOWED)
		if (PlayState.instance != null && FlxG.state == PlayState.instance)
			PlayState.instance.addTextToDebug(text, FlxColor.RED);
		#end
	}
}
#end
