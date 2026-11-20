package flux.vslice.api;

#if FLUX_VSLICE_SCRIPTS
import flux.vslice.api.ScriptEvent;
import rulescript.scriptedClass.RuleScriptedClass;

/**
 * Equivalente de funkin.modding.module.Module (V-Slice) en Flux Engine.
 *
 * Un módulo es una clase de un .hxc que hace `extends Module`: está activo
 * siempre (en cualquier menú o canción) y recibe todos los eventos del juego.
 * Las funciones de abajo no hacen nada; el script las reemplaza con las suyas
 * (con o sin `override`) y puede llamar `super.onUpdate(event)` etc.
 *
 * Flux crea la instancia con FluxScriptedModule (ver flux.vslice.modules).
 */
@:keep
class Module
{
	/** Si es false el módulo no recibe eventos. */
	public var active(default, set):Bool = true;

	public var moduleId(default, null):String = 'UNKNOWN';

	/** Orden en que reciben los eventos: 1 va antes que 1000. */
	public var priority(default, set):Int = 1000;

	public function new(moduleId:String, priority:Int = 1000)
	{
		this.moduleId = moduleId;
		this.priority = priority;
	}

	function set_active(value:Bool):Bool
		return active = value;

	function set_priority(value:Int):Int
	{
		priority = value;
		flux.vslice.modules.FluxVSliceModules.reorder();
		return value;
	}

	public function toString():String
		return 'Module($moduleId)';

	// ----- Eventos (mismos nombres que en V-Slice) -----

	/** Se llama con TODOS los eventos, antes de la función específica. */
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

	public function onStateChangeBegin(event:StateChangeScriptEvent):Void {}

	public function onStateChangeEnd(event:StateChangeScriptEvent):Void {}

	public function onSubStateOpenBegin(event:SubStateScriptEvent):Void {}

	public function onSubStateOpenEnd(event:SubStateScriptEvent):Void {}

	public function onSubStateCloseBegin(event:SubStateScriptEvent):Void {}

	public function onSubStateCloseEnd(event:SubStateScriptEvent):Void {}

	public function onFocusLost(event:FocusScriptEvent):Void {}

	public function onFocusGained(event:FocusScriptEvent):Void {}

	// ----- Acceso al script (como en Polymod) -----

	/** Llama una función del script: `ModuleHandler.getModule('X').scriptCall('hola', [1, 2])`. */
	public final function scriptCall(name:String, ?args:Array<Dynamic>):Dynamic
	{
		var fn:Dynamic = scriptGet(name);
		if (fn == null || !Reflect.isFunction(fn))
			return null;
		return Reflect.callMethod(null, fn, args == null ? [] : args);
	}

	/** Lee una variable o función del script. */
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

	/** Cambia una variable del script. */
	public final function scriptSet(name:String, value:Dynamic):Dynamic
	{
		if (Std.isOfType(this, RuleScriptedClass))
		{
			var scripted:RuleScriptedClass = cast this;
			return scripted.setVariable(name, value);
		}
		Reflect.setProperty(this, name, value);
		return value;
	}
}
#end
