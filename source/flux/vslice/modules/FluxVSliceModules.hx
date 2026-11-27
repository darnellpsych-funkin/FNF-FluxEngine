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
import flux.vslice.api.NoteKind;
import flux.vslice.api.ScriptEvent;
import flux.vslice.api.SongEvent;
import flux.vslice.api.VSliceApi.VSScoring;
import flux.vslice.api.VSliceApi.VSSongEventData;
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

	/** El primer texto del `super(...)` del constructor (Dave Engine: el id del personaje o escenario). */
	var ?superId:String;
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
 * También los tipos de nota (`extends NoteKind` / `ScriptedNoteKind`): reciben
 * los eventos de las notas de su tipo y los demás eventos de la canción.
 * Y los eventos del chart con script (`extends SongEvent` / `ScriptedSongEvent`):
 * Flux llama a su handleEvent(data) cuando la canción llega a un evento con su id.
 * Las clases de Dave Engine (`extends Character` / `extends Stage`) se guardan
 * para los personajes y escenarios de Dave (flux.dave.DaveScripts).
 * Las clases de canciones, escenarios y personajes de V-Slice (Song, SparrowCharacter...)
 * todavía se ignoran con un aviso.
 */
class FluxVSliceModules
{
	/** Módulos activos ordenados por prioridad. */
	public static var modules(default, null):Array<Module> = [];

	/** Tipos de nota de los .hxc (tipo de nota del chart -> script). */
	public static var noteKinds(default, null):Map<String, NoteKind> = new Map<String, NoteKind>();

	/** Eventos con script de los .hxc (id del evento -> script). */
	public static var songEvents(default, null):Map<String, SongEvent> = new Map<String, SongEvent>();

	/** Los eventos con script que usa la canción actual (reciben los eventos de PlayState). */
	public static var activeEvents(default, null):Array<SongEvent> = [];

	/** Clases encontradas en los .hxc (nombre -> datos). */
	public static var classes(default, null):Map<String, VSliceClassInfo> = new Map<String, VSliceClassInfo>();

	/** Mods activos cuando se cargaron los módulos. */
	public static var enabledMods(default, null):Array<String> = [];

	/** Nota que un módulo está pegando ahora mismo (para no mandar onNoteHit dos veces). */
	public static var moduleNoteHit:Note = null;

	static var classOrder:Array<String> = [];
	static var moduleInfo:ObjectMap<Module, VSliceClassInfo> = new ObjectMap<Module, VSliceClassInfo>();
	static var kindInfo:ObjectMap<NoteKind, VSliceClassInfo> = new ObjectMap<NoteKind, VSliceClassInfo>();
	static var eventInfo:ObjectMap<SongEvent, VSliceClassInfo> = new ObjectMap<SongEvent, VSliceClassInfo>();
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

	/** Si hay algo a quien mandarle eventos (módulos, tipos de nota o eventos de la canción). */
	public static inline function hasModules():Bool
		return modules.length > 0 || noteKindCount > 0 || activeEvents.length > 0;

	static var noteKindCount:Int = 0;

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
		var loadedKinds:Array<String> = [];
		var loadedEvents:Array<String> = [];
		var loadedDave:Array<String> = [];
		var ignored:Array<String> = [];
		for (name in classOrder)
		{
			var info:VSliceClassInfo = classes.get(name);
			if (info.superName == 'SongEvent' || info.superName == 'ScriptedSongEvent')
			{
				var songEvent:SongEvent = null;
				try
				{
					songEvent = new FluxScriptedSongEvent(info.name, [info.name]);
				}
				catch (e:Dynamic)
				{
					reportError('${info.name} (${info.file})', 'no se pudo crear: ' + errorText(e));
					continue;
				}
				if (songEvent.id == null || songEvent.id.length == 0)
					songEvent.id = info.name;
				eventInfo.set(songEvent, info);
				songEvents.set(songEvent.id, songEvent);
				loadedEvents.push('${songEvent.id} (${info.name}) [${info.mod}]');
				continue;
			}
			if (info.superName == 'NoteKind' || info.superName == 'ScriptedNoteKind')
			{
				var kind:NoteKind = null;
				try
				{
					kind = new FluxScriptedNoteKind(info.name, [info.name]);
				}
				catch (e:Dynamic)
				{
					reportError('${info.name} (${info.file})', 'no se pudo crear: ' + errorText(e));
					continue;
				}
				if (kind.noteKind == null || kind.noteKind.length == 0)
					kind.noteKind = info.name;
				kindInfo.set(kind, info);
				noteKinds.set(kind.noteKind, kind);
				loadedKinds.push('${kind.noteKind} (${info.name}) [${info.mod}]');
				continue;
			}
			#if FLUX_DAVE_SCRIPTS
			// personajes y escenarios de Dave Engine: se crean cuando la canción los usa
			if (flux.dave.DaveScripts.register(info.name, info.superName, info.superId, info.file))
			{
				loadedDave.push('${info.superId != null ? info.superId : info.name} (${info.name}) [${info.mod}]');
				continue;
			}
			#end
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

		noteKindCount = Lambda.count(noteKinds);
		if (loaded.length > 0)
			log('Módulos de V-Slice cargados: ' + loaded.join(', '));
		if (loadedKinds.length > 0)
			log('Tipos de nota de V-Slice cargados: ' + loadedKinds.join(', '));
		if (loadedEvents.length > 0)
			log('Eventos de V-Slice cargados: ' + loadedEvents.join(', '));
		if (loadedDave.length > 0)
			log('Personajes y escenarios de Dave Engine: ' + loadedDave.join(', '));
		if (ignored.length > 0)
			log('Clases que Flux todavía no usa (por ahora módulos, tipos de nota, eventos y lo de Dave Engine): ' + ignored.join(', '));

		callEvent(new ScriptEvent(ScriptEventType.CREATE));
	}

	static function unloadAll():Void
	{
		if (hasModules())
			callEvent(new ScriptEvent(ScriptEventType.DESTROY));
		for (name in classOrder)
			RuleScriptedClassUtil.types.remove(name);
		#if FLUX_DAVE_SCRIPTS
		flux.dave.DaveScripts.clear();
		#end
		modules = [];
		moduleInfo = new ObjectMap<Module, VSliceClassInfo>();
		noteKinds = new Map<String, NoteKind>();
		kindInfo = new ObjectMap<NoteKind, VSliceClassInfo>();
		noteKindCount = 0;
		songEvents = new Map<String, SongEvent>();
		eventInfo = new ObjectMap<SongEvent, VSliceClassInfo>();
		activeEvents = [];
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
				file: file,
				superId: c.superId
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
		#if FLUX_DAVE_SCRIPTS
		if (flux.dave.DaveScripts.isDaveClass(typeName))
			interp.enableDave(); // los imports por defecto de Dave Engine (PlayState, BGSprite, Paths...)
		#end
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

	/**
	 * Manda el evento a todos los módulos activos (por prioridad) y, en una
	 * canción, a los eventos con script que usa y a los tipos de nota
	 * (el orden del PlayState de V-Slice: módulos, eventos, tipos de nota).
	 */
	public static function callEvent(event:ScriptEvent):Void
	{
		if (event == null)
			return;
		for (module in modules.copy())
		{
			if (module == null || !module.active)
				continue;
			dispatchTo(module, event);
			if (!event.shouldPropagate)
				return;
		}
		if (PlayState.instance == null || FlxG.state != PlayState.instance)
			return;
		for (songEvent in activeEvents.copy())
		{
			dispatchTo(songEvent, event);
			if (!event.shouldPropagate)
				return;
		}
		if (noteKindCount > 0)
			callNoteKinds(event);
	}

	/**
	 * NoteKindManager.callEvent de V-Slice: un evento de una nota va solo al tipo
	 * de esa nota; los demás eventos van a todos los tipos de nota.
	 */
	public static function callNoteKinds(event:ScriptEvent):Void
	{
		if (event == null || noteKindCount == 0)
			return;
		if (Std.isOfType(event, NoteScriptEvent))
		{
			var note:Dynamic = (cast event : NoteScriptEvent).note;
			var kind:NoteKind = (note != null && Std.isOfType(note, Note)) ? noteKinds.get((cast note : Note).noteType) : null;
			if (kind != null)
				dispatchTo(kind, event);
			return;
		}
		for (kind in noteKinds)
		{
			dispatchTo(kind, event);
			if (!event.shouldPropagate)
				break;
		}
	}

	/** Lo que el tipo de nota de V-Slice cambia en la nota de Psych (noanim, sufijo, scoreable). */
	public static function applyNoteKind(note:Note):Void
	{
		if (note == null || noteKindCount == 0)
			return;
		var kind:NoteKind = noteKinds.get(note.noteType);
		if (kind == null)
			return;
		if (kind.noanim)
			note.noAnimation = true;
		if (kind.suffix != null && kind.suffix.length > 0)
			note.animSuffix = kind.suffix;
		if (!kind.scoreable)
			note.ratingDisabled = true;
	}

	/** Llama a onScriptEvent y a la función del evento (onUpdate, onNoteHit...) del objeto. */
	public static function dispatchTo(target:Dynamic, event:ScriptEvent):Void
	{
		if (target == null || event == null)
			return;

		var info:VSliceClassInfo = infoOf(target);
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

	/** De qué clase y archivo viene un objeto con script (para los errores y el mod). */
	static function infoOf(target:Dynamic):VSliceClassInfo
	{
		if (Std.isOfType(target, Module))
			return moduleInfo.get(cast target);
		if (Std.isOfType(target, NoteKind))
			return kindInfo.get(cast target);
		if (Std.isOfType(target, SongEvent))
			return eventInfo.get(cast target);
		return null;
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
		activeEvents = [];
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
		// los eventos con script que usa esta canción (como SongEventRegistry.resetEvents)
		activeEvents = [];
		var events:Array<VSSongEventData> = VSliceAdapter.getField(game, 'songEvents');
		if (events != null)
			for (event in events)
			{
				var handler:SongEvent = songEvents.get(event.eventKind);
				if (handler != null && !activeEvents.contains(handler))
					activeEvents.push(handler);
			}

		if (!hasModules())
			return;
		var id:String = PlayState.SONG != null ? Paths.formatToSongPath(PlayState.SONG.song) : '';
		var notes:Array<Dynamic> = [];
		for (note in game.unspawnNotes)
			if (note != null && !note.isSustainNote)
				notes.push(new flux.vslice.modules.VSliceProxies.VSNoteData(note));
		callEvent(new SongLoadScriptEvent(id, Paths.formatToSongPath(Difficulty.getString()), notes, events != null ? events.copy() : []));
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
		applyNoteKind(note);
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

	/**
	 * Un evento del chart. Primero lo reciben los módulos (onSongEvent) y, si nadie
	 * lo canceló, lo hace su script (`extends SongEvent`) si tiene uno.
	 * Devuelve false si se canceló (Psych no lo procesa, los scripts sí lo reciben).
	 */
	public static function onSongEvent(game:PlayState, name:String, value1:String, value2:String, time:Float):Bool
	{
		var handler:SongEvent = songEvents.get(name);
		if (!hasModules() && handler == null)
			return true;
		var data:VSSongEventData = new VSSongEventData(time, name, eventValue(value1, value2));
		data.value1 = value1;
		data.value2 = value2;
		var event:SongEventScriptEvent = new SongEventScriptEvent(data);
		if (hasModules())
			callEvent(event);
		if (event.eventCanceled)
			return false;
		#if FLUX_VSLICE
		if (flux.vslice.FluxVSliceEvents.handles(name)) // ese lo hace Flux (ZoomCamera, Subtitles...)
			return true;
		#end
		runEventHandler(name, data);
		return true;
	}

	/** Si hay un evento con script con ese id. */
	public static inline function hasEventHandler(kind:String):Bool
		return kind != null && songEvents.exists(kind);

	/** Llama al handleEvent del evento con script (si hay uno para ese id). */
	public static function runEventHandler(kind:String, data:VSSongEventData):Void
	{
		var handler:SongEvent = kind != null ? songEvents.get(kind) : null;
		if (handler == null)
			return;
		var info:VSliceClassInfo = eventInfo.get(handler);
		var previousMod:String = currentMod;
		if (info != null)
			currentMod = info.mod;
		try
		{
			handler.handleEvent(data);
		}
		catch (e:Dynamic)
		{
			reportError(info != null ? '${info.name} (${info.file})' : 'evento $kind', errorText(e));
		}
		currentMod = previousMod;
		data.handled = true;
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
