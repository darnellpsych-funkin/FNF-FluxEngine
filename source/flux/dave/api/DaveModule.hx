package flux.dave.api;

#if FLUX_DAVE_SCRIPTS
import flixel.FlxG;
import flixel.FlxState;
import flux.vslice.api.ScriptEvent;
import states.PlayState;

/**
 * Module de Dave Engine (scripting.module.Module): un script global de un mod de Dave.
 * Recibe los eventos de las canciones de Dave (onCreatePost, onBeatHit...) y, en todos
 * los menús, onUpdate, onStateChange y onStateChangePost.
 */
@:keep
class DaveModule
{
	public var moduleId(default, null):String;

	/** Los de menor prioridad se llaman primero. */
	public var priority:Int;

	/** false = no recibe eventos (deactivate()). */
	public var enabled(default, null):Bool = true;

	public function new(id:String, priority:Int = 0)
	{
		this.moduleId = id;
		this.priority = priority;
	}

	public function deactivate():Void
		enabled = false;

	public function activate():Void
		enabled = true;

	public function toString():String
		return 'Module(id=$moduleId, priority=$priority)';

	public function onScriptEvent(event:Dynamic):Void {}

	public function onScriptEventPost(event:Dynamic):Void {}

	public function onCreate(event:Dynamic):Void {}

	public function onUpdate(event:Dynamic):Void {}

	public function onDestroy(event:Dynamic):Void {}

	public function onPreferenceChanged(event:Dynamic):Void {}

	public function onNoteSpawn(event:Dynamic):Void {}

	public function onOpponentNoteHit(event:Dynamic):Void {}

	public function onPlayerNoteHit(event:Dynamic):Void {}

	public function onNoteMiss(event:Dynamic):Void {}

	public function onHoldNoteDrop(event:Dynamic):Void {}

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

	public function onGhostNoteMiss(event:Dynamic):Void {}

	public function onStateChange(event:Dynamic):Void {}

	public function onStateChangePost(event:Dynamic):Void {}

	public function onSubStateOpen(event:Dynamic):Void {}

	public function onSubStateOpenPost(event:Dynamic):Void {}

	public function onSubStateClose(event:Dynamic):Void {}

	public function onSubStateClosePost(event:Dynamic):Void {}

	public function onDialogueStart(event:Dynamic):Void {}

	public function onDialogueLine(event:Dynamic):Void {}

	public function onDialogueLineComplete(event:Dynamic):Void {}

	public function onDialogueEnd(event:Dynamic):Void {}

	public function onDialogueSkip(event:Dynamic):Void {}
}

/**
 * SongModule de Dave Engine (play.song.SongModule): un script que corre en una canción
 * (y una variación). `super('miModulo', prioridad, 'cancion')` en el constructor dice cuál.
 * `game` es el PlayState (con los nombres de Dave: switchDad, healthBar, camHUD...).
 */
@:keep
class DaveSongModule
{
	public var moduleId(default, null):String;
	public var songId(default, null):String;
	public var variation(default, null):String;

	/** Los de menor prioridad se llaman primero. */
	public var priority(default, set):Int;

	/** false = no recibe eventos (deactivate()). */
	public var enabled(default, null):Bool = true;

	var game:PlayState;

	public function new(moduleId:String, priority:Int, songId:String, ?variationId:String)
	{
		this.moduleId = moduleId;
		this.songId = songId;
		this.variation = flux.dave.DaveModules.validateVariation(variationId);
		this.priority = priority;
	}

	function set_priority(value:Int):Int
	{
		priority = value;
		flux.dave.DaveModules.reorder();
		return value;
	}

	/** Lo llama Flux antes de onCreate: `game` es el PlayState. */
	public function initalize():Void
	{
		if (PlayState.instance != null)
			game = PlayState.instance;
	}

	public function deactivate():Void
		enabled = false;

	public function activate():Void
		enabled = true;

	public function toString():String
		return 'SongModule(song=(id=$songId, variation=$variation), id=$moduleId, priority=$priority)';

	public function onScriptEvent(event:Dynamic):Void {}

	public function onScriptEventPost(event:Dynamic):Void {}

	public function onCreate(event:Dynamic):Void {}

	public function onUpdate(event:Dynamic):Void {}

	public function onDestroy(event:Dynamic):Void {}

	public function onPreferenceChanged(event:Dynamic):Void {}

	public function onNoteSpawn(event:Dynamic):Void {}

	public function onOpponentNoteHit(event:Dynamic):Void {}

	public function onPlayerNoteHit(event:Dynamic):Void {}

	public function onNoteMiss(event:Dynamic):Void {}

	public function onHoldNoteDrop(event:Dynamic):Void {}

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

	public function onGhostNoteMiss(event:Dynamic):Void {}

	public function onDialogueStart(event:Dynamic):Void {}

	public function onDialogueLine(event:Dynamic):Void {}

	public function onDialogueLineComplete(event:Dynamic):Void {}

	public function onDialogueEnd(event:Dynamic):Void {}

	public function onDialogueSkip(event:Dynamic):Void {}
}

/** onStateChange / onStateChangePost / onSubStateOpen... (`targetState`: el estado). */
@:keep
class DaveStateChangeEvent extends ScriptEvent
{
	public var targetState(default, null):FlxState;

	public function new(type:String, targetState:FlxState, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.targetState = targetState;
	}
}

/** onPreferenceChanged: `preference` y su `value` nuevo. */
@:keep
class DavePreferenceEvent extends ScriptEvent
{
	public var preference(default, null):String;
	public var value(default, null):Dynamic;

	public function new(preference:String, value:Dynamic)
	{
		super('preference_changed', false);
		this.preference = preference;
		this.value = value;
	}
}

/** Module de Dave cuyo código viene de un .hxc (ver FluxScriptedDaveCharacter). */
@:keep
class FluxScriptedDaveModule extends DaveModule implements rulescript.scriptedClass.RuleScriptedClass {}

/** SongModule de Dave cuyo código viene de un .hxc. */
@:keep
class FluxScriptedDaveSongModule extends DaveSongModule implements rulescript.scriptedClass.RuleScriptedClass {}
#end
