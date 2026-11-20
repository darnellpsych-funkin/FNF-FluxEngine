package flux.vslice.api;

#if FLUX_VSLICE_SCRIPTS
/**
 * Eventos de V-Slice (funkin.modding.events.*) para los módulos .hxc.
 * Tienen los mismos nombres, campos y constructores que en V-Slice 0.8,
 * así un script puede hacer `new HitNoteScriptEvent(...)` igual que allá.
 */
@:keep
class ScriptEvent
{
	public var type(default, null):String;
	public var cancelable(default, null):Bool;
	public var eventCanceled(default, null):Bool = false;
	public var shouldPropagate(default, null):Bool = true;

	public function new(type:String, cancelable:Bool = false)
	{
		this.type = type;
		this.cancelable = cancelable;
	}

	/** Cancela el evento (solo si es cancelable). */
	public function cancelEvent():Void
	{
		if (cancelable)
			eventCanceled = true;
	}

	public function cancel():Void
		cancelEvent();

	/** Los módulos que siguen ya no reciben este evento. */
	public function stopPropagation():Void
		shouldPropagate = false;

	public function toString():String
		return 'ScriptEvent(type=$type, cancelable=$cancelable)';
}

/** Tipos de evento (V-Slice: funkin.modding.events.ScriptEventType). */
@:keep
class ScriptEventType
{
	public static var CREATE:String = 'CREATE';
	public static var DESTROY:String = 'DESTROY';
	public static var ADDED:String = 'ADDED';
	public static var UPDATE:String = 'UPDATE';
	public static var PAUSE:String = 'PAUSE';
	public static var RESUME:String = 'RESUME';
	public static var SONG_BEAT_HIT:String = 'BEAT_HIT';
	public static var SONG_STEP_HIT:String = 'STEP_HIT';
	public static var SONG_START:String = 'SONG_START';
	public static var SONG_END:String = 'SONG_END';
	public static var SONG_RETRY:String = 'SONG_RETRY';
	public static var SONG_LOADED:String = 'SONG_LOADED';
	public static var SONG_EVENT:String = 'SONG_EVENT';
	public static var GAME_OVER:String = 'GAME_OVER';
	public static var NOTE_INCOMING:String = 'NOTE_INCOMING';
	public static var NOTE_HIT:String = 'NOTE_HIT';
	public static var NOTE_MISS:String = 'NOTE_MISS';
	public static var NOTE_GHOST_MISS:String = 'NOTE_GHOST_MISS';
	public static var NOTE_HOLD_DROP:String = 'NOTE_HOLD_DROP';
	public static var COUNTDOWN_START:String = 'COUNTDOWN_START';
	public static var COUNTDOWN_STEP:String = 'COUNTDOWN_STEP';
	public static var COUNTDOWN_END:String = 'COUNTDOWN_END';
	public static var STATE_CHANGE_BEGIN:String = 'STATE_CHANGE_BEGIN';
	public static var STATE_CHANGE_END:String = 'STATE_CHANGE_END';
	public static var SUBSTATE_OPEN_BEGIN:String = 'SUBSTATE_OPEN_BEGIN';
	public static var SUBSTATE_OPEN_END:String = 'SUBSTATE_OPEN_END';
	public static var SUBSTATE_CLOSE_BEGIN:String = 'SUBSTATE_CLOSE_BEGIN';
	public static var SUBSTATE_CLOSE_END:String = 'SUBSTATE_CLOSE_END';
	public static var FOCUS_LOST:String = 'FOCUS_LOST';
	public static var FOCUS_GAINED:String = 'FOCUS_GAINED';

	/** Función del módulo que recibe cada tipo de evento. */
	public static var methods(get, never):Map<String, String>;
	static var _methods:Map<String, String>;

	static function get_methods():Map<String, String>
	{
		if (_methods == null)
			_methods = [
				CREATE => 'onCreate', DESTROY => 'onDestroy', UPDATE => 'onUpdate', PAUSE => 'onPause', RESUME => 'onResume',
				SONG_BEAT_HIT => 'onBeatHit', SONG_STEP_HIT => 'onStepHit', SONG_START => 'onSongStart', SONG_END => 'onSongEnd',
				SONG_RETRY => 'onSongRetry', SONG_LOADED => 'onSongLoaded', SONG_EVENT => 'onSongEvent', GAME_OVER => 'onGameOver',
				NOTE_INCOMING => 'onNoteIncoming', NOTE_HIT => 'onNoteHit', NOTE_MISS => 'onNoteMiss', NOTE_GHOST_MISS => 'onNoteGhostMiss',
				NOTE_HOLD_DROP => 'onNoteHoldDrop', COUNTDOWN_START => 'onCountdownStart', COUNTDOWN_STEP => 'onCountdownStep',
				COUNTDOWN_END => 'onCountdownEnd', STATE_CHANGE_BEGIN => 'onStateChangeBegin', STATE_CHANGE_END => 'onStateChangeEnd',
				SUBSTATE_OPEN_BEGIN => 'onSubStateOpenBegin', SUBSTATE_OPEN_END => 'onSubStateOpenEnd',
				SUBSTATE_CLOSE_BEGIN => 'onSubStateCloseBegin', SUBSTATE_CLOSE_END => 'onSubStateCloseEnd',
				FOCUS_LOST => 'onFocusLost', FOCUS_GAINED => 'onFocusGained'
			];
		return _methods;
	}
}

/** Pasos de la cuenta regresiva (V-Slice: CountdownStep). */
@:keep
class CountdownStep
{
	public static var BEFORE:String = 'BEFORE';
	public static var THREE:String = 'THREE';
	public static var TWO:String = 'TWO';
	public static var ONE:String = 'ONE';
	public static var GO:String = 'GO';
	public static var AFTER:String = 'AFTER';
}

@:keep
class UpdateScriptEvent extends ScriptEvent
{
	public var elapsed(default, null):Float;

	public function new(elapsed:Float)
	{
		super(ScriptEventType.UPDATE, false);
		this.elapsed = elapsed;
	}
}

@:keep
class NoteScriptEvent extends ScriptEvent
{
	/** En Flux es la nota de Psych (objects.Note); los .hxc la usan con los nombres de V-Slice. */
	public var note(default, null):Dynamic;
	public var comboCount(default, null):Int;
	public var playSound(default, default):Bool = true;
	public var healthChange(default, default):Float;

	public function new(type:String, note:Dynamic, healthChange:Float, comboCount:Int = 0, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.note = note;
		this.healthChange = healthChange;
		this.comboCount = comboCount;
	}
}

@:keep
class HitNoteScriptEvent extends NoteScriptEvent
{
	public var judgement:String;
	public var score:Int;
	public var isComboBreak:Bool = false;
	public var hitDiff:Float = 0;
	public var doesNotesplash:Bool = false;

	public function new(note:Dynamic, healthChange:Float, score:Int, judgement:String, isComboBreak:Bool, comboCount:Int = 0, hitDiff:Float = 0,
			doesNotesplash:Bool = false)
	{
		super(ScriptEventType.NOTE_HIT, note, healthChange, comboCount, true);
		this.score = score;
		this.judgement = judgement;
		this.isComboBreak = isComboBreak;
		this.hitDiff = hitDiff;
		this.doesNotesplash = doesNotesplash;
	}
}

@:keep
class HoldNoteScriptEvent extends NoteScriptEvent
{
	public var holdNote(default, null):Dynamic;
	public var score:Int;
	public var isComboBreak:Bool = false;

	public function new(type:String, holdNote:Dynamic, healthChange:Float, score:Int, isComboBreak:Bool, cancelable:Bool = true)
	{
		super(type, null, healthChange, 0, cancelable);
		this.holdNote = holdNote;
		this.score = score;
		this.isComboBreak = isComboBreak;
	}
}

@:keep
class GhostMissNoteScriptEvent extends ScriptEvent
{
	public var dir(default, null):Int;
	public var hasPossibleNotes(default, null):Bool;
	public var healthChange(default, default):Float;
	public var scoreChange(default, default):Int;
	public var playSound(default, default):Bool = true;
	public var playAnim(default, default):Bool = true;

	public function new(dir:Int, hasPossibleNotes:Bool, healthChange:Float, scoreChange:Int)
	{
		super(ScriptEventType.NOTE_GHOST_MISS, true);
		this.dir = dir;
		this.hasPossibleNotes = hasPossibleNotes;
		this.healthChange = healthChange;
		this.scoreChange = scoreChange;
	}
}

@:keep
class SongEventScriptEvent extends ScriptEvent
{
	/** {time, eventKind, value} como en V-Slice (+ value1/value2 del evento de Psych). */
	public var eventData(default, null):Dynamic;

	public function new(eventData:Dynamic)
	{
		super(ScriptEventType.SONG_EVENT, true);
		this.eventData = eventData;
	}
}

@:keep
class SongTimeScriptEvent extends ScriptEvent
{
	public var beat(default, null):Int;
	public var step(default, null):Int;

	public function new(type:String, beat:Int, step:Int)
	{
		super(type, true);
		this.beat = beat;
		this.step = step;
	}
}

@:keep
class CountdownScriptEvent extends ScriptEvent
{
	public var step(default, null):String;

	public function new(type:String, step:String, cancelable:Bool = true)
	{
		super(type, cancelable);
		this.step = step;
	}
}

@:keep
class SongLoadScriptEvent extends ScriptEvent
{
	public var id(default, null):String;
	public var difficulty(default, null):String;
	public var notes(default, default):Array<Dynamic>;
	public var events(default, default):Array<Dynamic>;

	public function new(id:String, difficulty:String, notes:Array<Dynamic>, ?events:Array<Dynamic>)
	{
		super(ScriptEventType.SONG_LOADED, false);
		this.id = id;
		this.difficulty = difficulty;
		this.notes = notes;
		this.events = events == null ? [] : events;
	}
}

@:keep
class StateChangeScriptEvent extends ScriptEvent
{
	public var targetState(default, null):Dynamic;

	public function new(type:String, targetState:Dynamic, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.targetState = targetState;
	}
}

@:keep
class SubStateScriptEvent extends ScriptEvent
{
	public var targetState(default, null):Dynamic;

	public function new(type:String, targetState:Dynamic, cancelable:Bool = false)
	{
		super(type, cancelable);
		this.targetState = targetState;
	}
}

@:keep
class FocusScriptEvent extends ScriptEvent
{
	public function new(type:String)
	{
		super(type, false);
	}
}

@:keep
class PauseScriptEvent extends ScriptEvent
{
	public var gitaroo(default, default):Bool;

	public function new(gitaroo:Bool = false)
	{
		super(ScriptEventType.PAUSE, true);
		this.gitaroo = gitaroo;
	}
}

@:keep
class SongRetryEvent extends ScriptEvent
{
	public var difficulty(default, null):String;
	public var variation(default, null):String;

	public function new(difficulty:String, variation:String)
	{
		super(ScriptEventType.SONG_RETRY, false);
		this.difficulty = difficulty;
		this.variation = variation;
	}
}
#end
