package flux.vslice.api;

#if FLUX_VSLICE_SCRIPTS
import flux.vslice.api.ScriptEvent;
import objects.Note;
import rulescript.scriptedClass.RuleScriptedClass;
import states.PlayState;

/**
 * Equivalente de funkin.play.notes.notekind.NoteKind (V-Slice) en Flux Engine.
 *
 * Un tipo de nota de un .hxc (`extends NoteKind` o `extends ScriptedNoteKind`):
 * recibe los eventos de las notas de su tipo (onNoteHit, onNoteMiss,
 * onNoteIncoming...) y los demás eventos de la canción (onUpdate, onBeatHit...).
 *
 *   super("Morty", "descripción", "estiloDeNota", params, noanim, sufijo);
 *
 * Con noanim = true el personaje no canta esas notas (en Psych, note.noAnimation),
 * el sufijo va a la animación (note.animSuffix) y scoreable = false hace que
 * no den puntaje (note.ratingDisabled).
 *
 * Flux crea la instancia con FluxScriptedNoteKind (ver flux.vslice.modules).
 */
@:keep
class NoteKind
{
	/** El tipo de nota del chart (en Psych, note.noteType). */
	public var noteKind:String;

	public var description:String;
	public var noteStyleId:Null<String>;
	public var noanim:Bool;
	public var suffix:String;
	public var params:Array<Dynamic>;
	public var scoreable(default, default):Bool = true;

	public function new(noteKind:String, description:String = "", ?noteStyleId:String, ?params:Array<Dynamic>, ?noanim:Bool, ?suffix:String)
	{
		this.noteKind = noteKind;
		this.description = description;
		this.noteStyleId = noteStyleId;
		this.params = params != null ? params : [];
		this.noanim = noanim == true;
		this.suffix = suffix != null ? suffix : '';
	}

	public function toString():String
		return noteKind;

	/** Las notas de este tipo que hay en pantalla. */
	function getNotes(visibleCheck:Bool = false):Array<Note>
		return notesWhere(true, visibleCheck);

	/** Las notas de otros tipos que hay en pantalla. */
	function getOtherNotes(visibleCheck:Bool = false):Array<Note>
		return notesWhere(false, visibleCheck);

	function notesWhere(sameKind:Bool, visibleCheck:Bool):Array<Note>
	{
		var result:Array<Note> = [];
		var game:PlayState = PlayState.instance;
		if (game == null || game.notes == null)
			return result;
		for (note in game.notes.members)
			if (note != null && (note.noteType == noteKind) == sameKind && (!visibleCheck || note.visible))
				result.push(note);
		return result;
	}

	// ----- Eventos (mismos nombres que en V-Slice) -----

	public function onScriptEvent(event:ScriptEvent):Void {}

	public function onCreate(event:ScriptEvent):Void {}

	public function onDestroy(event:ScriptEvent):Void {}

	public function onUpdate(event:UpdateScriptEvent):Void {}

	public function onNoteIncoming(event:NoteScriptEvent):Void {}

	public function onNoteHit(event:HitNoteScriptEvent):Void {}

	public function onNoteMiss(event:NoteScriptEvent):Void {}

	public function onNoteHoldDrop(event:HoldNoteScriptEvent):Void {}

	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent):Void {}

	public function onStepHit(event:SongTimeScriptEvent):Void {}

	public function onBeatHit(event:SongTimeScriptEvent):Void {}

	public function onSongEvent(event:SongEventScriptEvent):Void {}

	public function onSongLoaded(event:SongLoadScriptEvent):Void {}

	public function onSongStart(event:ScriptEvent):Void {}

	public function onSongEnd(event:ScriptEvent):Void {}

	public function onSongRetry(event:SongRetryEvent):Void {}

	public function onGameOver(event:ScriptEvent):Void {}

	public function onPause(event:PauseScriptEvent):Void {}

	public function onResume(event:ScriptEvent):Void {}

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
		{
			var scripted:RuleScriptedClass = cast this;
			return scripted.setVariable(name, value);
		}
		Reflect.setProperty(this, name, value);
		return value;
	}
}

/** NoteKindManager de V-Slice. */
@:keep
class VSNoteKindManager
{
	public static function getNoteKind(?noteKind:String):NoteKind
		return noteKind == null ? null : flux.vslice.modules.FluxVSliceModules.noteKinds.get(noteKind);

	public static function listNoteKinds():Array<String>
		return [for (key in flux.vslice.modules.FluxVSliceModules.noteKinds.keys()) key];

	public static function getParams(?noteKind:String):Array<Dynamic>
	{
		var kind:NoteKind = getNoteKind(noteKind);
		return kind != null ? kind.params : [];
	}

	public static function callEvent(event:ScriptEvent):Void
		flux.vslice.modules.FluxVSliceModules.callNoteKinds(event);
}
#end
