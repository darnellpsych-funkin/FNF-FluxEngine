package flux.vslice.api;

#if FLUX_VSLICE_SCRIPTS
import flux.vslice.api.ScriptEvent;
import flux.vslice.api.VSliceApi.VSSongEventData;
import flux.vslice.modules.FluxVSliceModules;
import rulescript.scriptedClass.RuleScriptedClass;

/**
 * Equivalente de funkin.play.event.SongEvent (V-Slice) en Flux Engine.
 *
 * Un evento con script es una clase de un .hxc que hace `extends SongEvent`
 * (o `ScriptedSongEvent`) y llama `super('IdDelEvento')`. Cuando la canción
 * llega a un evento del chart con ese id, Flux llama a su `handleEvent(data)`.
 * Mientras la canción tiene eventos de ese tipo, también recibe los eventos de
 * PlayState (onUpdate, onBeatHit, onNoteHit...), como en V-Slice.
 *
 * Flux crea la instancia con FluxScriptedSongEvent (ver flux.vslice.modules).
 */
@:keep
class SongEvent
{
	public static var DEFAULT_EASE(default, null):String = 'linear';
	public static var DEFAULT_EASE_DIR(default, null):String = 'In';

	/** El id del evento en el chart (el `e` de los eventos de V-Slice). */
	public var id:String;

	/** Si es true el evento se hace aunque la canción ya lo haya pasado (al empezar a mitad). */
	public var processOldEvents:Bool = false;

	public function new(id:String, ?params:Dynamic)
	{
		this.id = id;
		if (params != null && Reflect.field(params, 'processOldEvents') == true)
			processOldEvents = true;
	}

	/** Lo que hace el evento. `data` es un SongEventData (data.getFloat('duration'), data.value...). */
	public function handleEvent(data:Dynamic):Void {}

	/** Para el editor de charts de V-Slice (Flux no lo usa). */
	public function getEventSchema():Dynamic
		return null;

	public function getIconPath():String
		return 'ui/chart-editor/events/default';

	public function getTitle():String
		return id;

	public function toString():String
		return 'SongEvent($id)';

	// ----- Eventos de PlayState (mismos nombres que en V-Slice) -----

	public function onScriptEvent(event:ScriptEvent):Void {}

	public function onCreate(event:ScriptEvent):Void {}

	public function onDestroy(event:ScriptEvent):Void {}

	public function onUpdate(event:UpdateScriptEvent):Void {}

	public function onPause(event:PauseScriptEvent):Void {}

	public function onResume(event:ScriptEvent):Void {}

	public function onSongLoaded(event:SongLoadScriptEvent):Void {}

	public function onSongStart(event:ScriptEvent):Void {}

	public function onSongEnd(event:ScriptEvent):Void {}

	public function onSongRetry(event:SongRetryEvent):Void {}

	public function onGameOver(event:ScriptEvent):Void {}

	public function onNoteIncoming(event:NoteScriptEvent):Void {}

	public function onNoteHit(event:HitNoteScriptEvent):Void {}

	public function onNoteMiss(event:NoteScriptEvent):Void {}

	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void {}

	public function onNoteHoldDrop(event:HoldNoteScriptEvent):Void {}

	public function onStepHit(event:SongTimeScriptEvent):Void {}

	public function onBeatHit(event:SongTimeScriptEvent):Void {}

	public function onSongEvent(event:SongEventScriptEvent):Void {}

	public function onCountdownStart(event:CountdownScriptEvent):Void {}

	public function onCountdownStep(event:CountdownScriptEvent):Void {}

	public function onCountdownEnd(event:CountdownScriptEvent):Void {}

	// ----- Acceso al script (como en Polymod) -----

	public final function scriptCall(name:String, ?args:Array<Dynamic>):Dynamic
	{
		var fn:Dynamic = scriptGet(name);
		if (fn == null || !Reflect.isFunction(fn))
			return null;
		return Reflect.callMethod(null, fn, args == null ? [] : args);
	}

	public final function scriptGet(name:String):Dynamic
	{
		if (Std.isOfType(this, RuleScriptedClass))
		{
			var scripted:RuleScriptedClass = cast this;
			if (scripted.variableExists(name))
				return scripted.getVariable(name);
		}
		return Reflect.getProperty(this, name);
	}

	public final function scriptSet(name:String, value:Dynamic):Dynamic
	{
		if (Std.isOfType(this, RuleScriptedClass))
			return (cast this : RuleScriptedClass).setVariable(name, value);
		Reflect.setProperty(this, name, value);
		return value;
	}
}

/** SongEventRegistry de V-Slice: los eventos con script de los mods activos. */
@:keep
class VSSongEventRegistry
{
	public static function getEvent(id:String):SongEvent
		return FluxVSliceModules.songEvents.get(id);

	public static function listEventIds():Array<String>
		return [for (id in FluxVSliceModules.songEvents.keys()) id];

	public static function listEvents():Array<SongEvent>
		return [for (event in FluxVSliceModules.songEvents) event];

	public static function getEventSchema(id:String):Dynamic
	{
		var event:SongEvent = getEvent(id);
		return event != null ? event.getEventSchema() : null;
	}

	/** Hace el evento ahora (como si la canción hubiera llegado a él). */
	public static function handleEvent(data:Dynamic):Void
	{
		if (data == null)
			return;
		var kind:String = Reflect.field(data, 'eventKind');
		FluxVSliceModules.runEventHandler(kind, Std.isOfType(data, VSSongEventData) ? data : new VSSongEventData(0, kind, Reflect.field(data, 'value')));
	}

	public static function handleEvents(events:Array<Dynamic>):Void
	{
		if (events != null)
			for (event in events)
				handleEvent(event);
	}

	/** Vuelve a leer los .hxc (eventos, módulos y tipos de nota). */
	public static function loadEventCache():Void
		FluxVSliceModules.reload(true);
}
#end
