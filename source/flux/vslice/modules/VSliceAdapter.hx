package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
import backend.Conductor;
import backend.Difficulty;
import backend.Paths;
import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flux.vslice.api.VSliceApi;
import flux.vslice.modules.VSliceProxies;
import haxe.ds.ObjectMap;
import objects.Character;
import objects.Note;
import states.PlayState;

using StringTools;

/**
 * Traduce nombres de V-Slice a Psych cuando un módulo .hxc lee o escribe un
 * campo. Ej: `state.playerStrumline`, `note.hasBeenHit`, `note.kind`,
 * `sprite.zIndex`, `character.playAnimation(...)`.
 *
 * Solo lo usa el intérprete de los .hxc (FluxVSliceInterp); los scripts de
 * Psych (.lua, .hx, .rhx...) no se ven afectados.
 */
@:keep
class VSliceAdapter
{
	/** Valor especial: "no lo manejo, usá el campo normal". */
	public static var UNHANDLED(default, null):Dynamic = new VSliceUnhandled();

	static var zIndexes:ObjectMap<FlxBasic, Int> = new ObjectMap<FlxBasic, Int>();

	static var cachedGame:PlayState;
	static var playerStrumline:VSStrumline;
	static var opponentStrumline:VSStrumline;
	static var stage:VSStage;
	static var voices:VSVoices;
	static var song:VSSong;

	public static function getField(o:Dynamic, f:String):Dynamic
	{
		if (o == null)
			return UNHANDLED;

		switch (f)
		{
			case 'zIndex':
				if (Std.isOfType(o, FlxBasic))
					return getZIndex(cast o);
			case 'refresh':
				if (Std.isOfType(o, FlxTypedGroup) && Reflect.getProperty(o, 'refresh') == null)
					return function() sortByZIndex(o);
			default:
		}

		if (Std.isOfType(o, PlayState))
			return playStateGet(cast o, f);
		if (Std.isOfType(o, Note))
			return noteGet(cast o, f);
		if (Std.isOfType(o, Character))
			return characterGet(cast o, f);
		if (Std.isOfType(o, VSTallies))
			return (o : VSTallies).getValue(f);
		return UNHANDLED;
	}

	/** Devuelve true si escribió el valor. */
	public static function setField(o:Dynamic, f:String, value:Dynamic):Bool
	{
		if (o == null)
			return false;

		if (f == 'zIndex' && Std.isOfType(o, FlxBasic))
		{
			zIndexes.set(cast o, Std.int(value));
			if (flux.vslice.FluxVSliceStage.current != null) // escenario de V-Slice: también para su refresh()
				flux.vslice.FluxVSliceStage.current.setZIndex(cast o, Std.int(value));
			return true;
		}
		if (Std.isOfType(o, PlayState))
			return playStateSet(cast o, f, value);
		if (Std.isOfType(o, Note))
			return noteSet(cast o, f, value);
		if (Std.isOfType(o, Character))
			return characterSet(cast o, f, value);
		if (Std.isOfType(o, VSTallies))
		{
			(o : VSTallies).setValue(f, value);
			return true;
		}
		return false;
	}

	// ----- PlayState -----

	static function checkGame(game:PlayState):Void
	{
		if (cachedGame == game)
			return;
		cachedGame = game;
		playerStrumline = new VSStrumline(game, true);
		opponentStrumline = new VSStrumline(game, false);
		stage = new VSStage(game);
		voices = new VSVoices(game);
		song = new VSSong(game);
	}

	static function playStateGet(game:PlayState, f:String):Dynamic
	{
		switch (f)
		{
			case 'playerStrumline':
				checkGame(game);
				return playerStrumline;
			case 'opponentStrumline':
				checkGame(game);
				return opponentStrumline;
			case 'currentStage':
				checkGame(game);
				return stage;
			case 'vocals':
				checkGame(game);
				return voices;
			case 'currentSong':
				checkGame(game);
				return song;
			case 'isGamePaused':
				return game.paused;
			case 'isInCutscene':
				return game.inCutscene;
			case 'isBotPlayMode':
				return game.cpuControlled || !game.fluxValidScore;
			case 'isPracticeMode':
				return game.practiceMode;
			case 'isPlayerDying':
				return game.isDead;
			case 'isInCountdown':
				return game.startingSong;
			case 'isMinimalMode' | 'needsReset' | 'disableKeys':
				return false;
			case 'currentDifficulty':
				return Paths.formatToSongPath(Difficulty.getString());
			case 'currentVariation':
				return 'default';
			case 'camCutscene':
				return game.camOther;
			case 'dispatchEvent':
				return function(event:Dynamic) FluxVSliceModules.callEvent(event);
			case 'applyScore':
				// Psych ya sumó el puntaje cuando se pegó la nota
				return Reflect.makeVarArgs(function(args:Array<Dynamic>) return null);
			case 'popUpScore':
				return Reflect.makeVarArgs(function(args:Array<Dynamic>) {
					if (args.length > 0 && Std.isOfType(args[0], Note))
						@:privateAccess game.popUpScore(args[0]);
					return null;
				});
			default:
		}
		return UNHANDLED;
	}

	static function playStateSet(game:PlayState, f:String, value:Dynamic):Bool
	{
		switch (f)
		{
			case 'isBotPlayMode':
				// en V-Slice esto evita que se guarde el puntaje
				if (value == true)
					game.fluxValidScore = false;
				return true;
			case 'isPracticeMode':
				game.practiceMode = value == true;
				return true;
			case 'isInCutscene':
				game.inCutscene = value == true;
				return true;
			case 'isGamePaused':
				game.paused = value == true;
				return true;
			case 'isMinimalMode' | 'needsReset' | 'disableKeys' | 'isInCountdown':
				return true;
			default:
		}
		return false;
	}

	// ----- Notas -----

	static function noteGet(note:Note, f:String):Dynamic
	{
		switch (f)
		{
			case 'noteData':
				return new VSNoteData(note);
			case 'hasBeenHit':
				return note.wasGoodHit;
			case 'hasMissed' | 'handledMiss':
				return note.tooLate || note.missed;
			case 'mayHit':
				return note.canBeHit;
			case 'tooEarly':
				return !note.canBeHit && note.strumTime > Conductor.songPosition;
			case 'kind' | 'noteKind':
				return note.noteType;
			case 'scoreable':
				return !note.ignoreNote && !note.hitCausesMiss;
			case 'holdNoteSprite':
				return null;
			case 'isHoldNote':
				return note.isSustainNote;
			case 'direction':
				return note.noteData % 4;
			case 'length':
				return note.sustainLength;
			case 'lowPriority':
				return false;
			default:
		}
		return UNHANDLED;
	}

	static function noteSet(note:Note, f:String, value:Dynamic):Bool
	{
		switch (f)
		{
			case 'hasBeenHit':
				note.wasGoodHit = value == true;
				return true;
			case 'hasMissed' | 'handledMiss':
				note.tooLate = value == true;
				return true;
			case 'mayHit':
				note.canBeHit = value == true;
				return true;
			case 'kind' | 'noteKind':
				note.noteType = value;
				return true;
			case 'scoreable':
				note.ignoreNote = value != true;
				return true;
			case 'holdNoteSprite' | 'lowPriority' | 'tooEarly':
				return true;
			default:
		}
		return false;
	}

	// ----- Personajes -----

	static var SING_ANIMS:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	static function characterGet(character:Character, f:String):Dynamic
	{
		switch (f)
		{
			case 'characterId' | 'characterName':
				return character.curCharacter;
			case 'singTimeSteps':
				return character.singDuration;
			case 'isSinging':
				return function() return isSinging(character);
			case 'getCurrentAnimation':
				return function() return character.getAnimationName();
			case 'playAnimation':
				return Reflect.makeVarArgs(function(args:Array<Dynamic>) {
					if (args.length > 0 && args[0] != null)
						character.playAnim(Std.string(args[0]), args.length > 1 && args[1] == true, args.length > 3 && args[3] == true);
					return null;
				});
			case 'playSingAnimation':
				return Reflect.makeVarArgs(function(args:Array<Dynamic>) {
					var dir:Int = args.length > 0 ? Std.int(args[0]) % 4 : 0;
					var miss:Bool = args.length > 1 && args[1] == true;
					var suffix:String = args.length > 2 && args[2] != null ? Std.string(args[2]) : '';
					character.playAnim(SING_ANIMS[dir] + (miss ? 'miss' : '') + suffix, true);
					character.holdTimer = 0;
					return null;
				});
			case 'playComboAnimation':
				return function(combo:Int) {
					var anim:String = 'combo$combo';
					if (character.hasAnimation(anim))
					{
						character.playAnim(anim, true);
						character.specialAnim = true;
					}
				};
			case 'playComboDropAnimation':
				return function(combo:Int) {
					if (character.hasAnimation('sad'))
					{
						character.playAnim('sad', true);
						character.specialAnim = true;
					}
				};
			case 'isAnimationFinished':
				return function() return character.isAnimationFinished();
			default:
		}
		return UNHANDLED;
	}

	static function characterSet(character:Character, f:String, value:Dynamic):Bool
	{
		switch (f)
		{
			case 'singTimeSteps':
				character.singDuration = value;
				return true;
			default:
		}
		return false;
	}

	static function isSinging(character:Character):Bool
	{
		var anim:String = character.getAnimationName();
		return anim != null && anim.startsWith('sing') && !anim.endsWith('miss');
	}

	// ----- zIndex -----

	public static function getZIndex(object:FlxBasic):Int
	{
		var stage = flux.vslice.FluxVSliceStage.current;
		if (stage != null && stage.hasZIndex(object))
			return stage.zIndexOf(object);
		return zIndexes.exists(object) ? zIndexes.get(object) : 0;
	}

	/** V-Slice ordena los objetos por zIndex con refresh(); el orden entre iguales se mantiene. */
	public static function sortByZIndex(group:Dynamic):Void
	{
		if (group == null || !Std.isOfType(group, FlxTypedGroup))
			return;
		var stage = flux.vslice.FluxVSliceStage.current;
		if (stage != null && group == stage.game)
		{
			stage.refresh(); // ordena solo el escenario; el HUD y lo de Lua quedan donde estaban
			return;
		}
		var typed:FlxTypedGroup<FlxBasic> = cast group;
		// sort() de Flixel ordena el arreglo real (y es estable)
		typed.sort(function(order:Int, a:FlxBasic, b:FlxBasic):Int {
			var za:Int = a != null ? getZIndex(a) : 0;
			var zb:Int = b != null ? getZIndex(b) : 0;
			return za - zb;
		});
	}

	/** Se llama al cambiar de estado para no guardar objetos viejos. */
	public static function clear():Void
	{
		zIndexes = new ObjectMap<FlxBasic, Int>();
		cachedGame = null;
		playerStrumline = opponentStrumline = null;
		stage = null;
		voices = null;
		song = null;
	}

	/** Nombre legible de un valor para los mensajes de error. */
	public static function describe(o:Dynamic):String
	{
		if (o == null)
			return 'null';
		var cls = Type.getClass(o);
		if (cls != null)
			return Type.getClassName(cls);
		if (Std.isOfType(o, Class))
			return Type.getClassName(cast o);
		return Std.string(Type.typeof(o));
	}
}

private class VSliceUnhandled
{
	public function new() {}
}
#end
