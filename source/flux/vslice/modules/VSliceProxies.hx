package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
import backend.Conductor;
import backend.Paths;
import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import objects.Character;
import objects.Note;
import objects.StrumNote;
import states.PlayState;

using StringTools;

/**
 * Objetos "puente" que imitan partes de PlayState de V-Slice usando el
 * PlayState de Psych. Los módulos .hxc los reciben al pedir
 * `state.playerStrumline`, `state.currentStage`, `state.vocals`, etc.
 */

/** Strumline de V-Slice (las flechas de un jugador). */
@:keep
class VSStrumline
{
	public var game(default, null):PlayState;

	/** true = flechas del jugador, false = del oponente (no cambia). */
	public var playerSide(default, null):Bool;

	/** Como en V-Slice: si lo controla el jugador. El botplay lo pone en false mientras juega. */
	public var isPlayer:Bool;

	public var inArrowControlSchemeMode:Bool = false;
	public var noteVibrations(default, null):VSNoteVibrations = new VSNoteVibrations();

	/** En Psych los "holds" son notas normales (isSustainNote), así que aquí no hay nada. */
	public var holdNotes(default, null):VSEmptyGroup = new VSEmptyGroup();

	var heldKeys:Array<Bool> = [false, false, false, false];

	public function new(game:PlayState, playerSide:Bool)
	{
		this.game = game;
		this.playerSide = playerSide;
		this.isPlayer = playerSide;
	}

	/** Las flechas (receptores) de Psych. */
	public var strumlineNotes(get, never):FlxTypedGroup<StrumNote>;

	function get_strumlineNotes():FlxTypedGroup<StrumNote>
		return playerSide ? game.playerStrums : game.opponentStrums;

	/** Notas de este lado que están en pantalla. */
	public var notes(get, never):VSNoteList;

	function get_notes():VSNoteList
		return new VSNoteList(getNotesOnScreen());

	public var visible(get, set):Bool;

	function get_visible():Bool
	{
		var strum:StrumNote = strumAt(0);
		return strum != null ? strum.visible : false;
	}

	function set_visible(value:Bool):Bool
	{
		var group = strumlineNotes;
		if (group != null)
			for (strum in group.members)
				if (strum != null)
					strum.visible = value;
		return value;
	}

	public var alpha(get, set):Float;

	function get_alpha():Float
	{
		var strum:StrumNote = strumAt(0);
		return strum != null ? strum.alpha : 1;
	}

	function set_alpha(value:Float):Float
	{
		var group = strumlineNotes;
		if (group != null)
			for (strum in group.members)
				if (strum != null)
					strum.alpha = value;
		return value;
	}

	/**
	 * Notas que se pueden pegar ahora. Como el botplay de Psych, no incluye las
	 * que hay que ignorar (ignoreNote, notas de daño) ni las bloqueadas.
	 * Incluye las partes de los sustains (en Psych cada parte es una nota).
	 */
	public function getNotesMayHit():Array<Note>
	{
		var result:Array<Note> = [];
		if (game == null || game.notes == null)
			return result;
		for (note in game.notes.members)
			if (note != null && note.alive && note.mustPress == playerSide && note.canBeHit && !note.wasGoodHit && !note.tooLate && !note.blockHit
				&& !note.ignoreNote && !note.hitCausesMiss)
				result.push(note);
		return result;
	}

	public function getNotesOnScreen():Array<Note>
	{
		var result:Array<Note> = [];
		if (game == null || game.notes == null)
			return result;
		for (note in game.notes.members)
			if (note != null && note.alive && note.mustPress == playerSide)
				result.push(note);
		return result;
	}

	/** Pega la nota con la lógica de Psych (puntaje, vida, animaciones, splash). */
	public function hitNote(note:Dynamic, removeNote:Bool = true):Void
	{
		if (game == null || !Std.isOfType(note, Note))
			return;
		var psychNote:Note = cast note;
		if (psychNote.wasGoodHit)
			return;

		if (!playerSide)
		{
			// las notas del oponente las procesa el PlayState de Psych solo
			psychNote.wasGoodHit = true;
			return;
		}

		FluxVSliceModules.moduleNoteHit = psychNote;
		try
		{
			game.goodNoteHit(psychNote);
		}
		catch (e:Dynamic)
		{
			FluxVSliceModules.moduleNoteHit = null;
			throw e;
		}
		FluxVSliceModules.moduleNoteHit = null;

		// el receptor vuelve solo a "static", como con el botplay de Psych
		var strum:StrumNote = strumAt(psychNote.noteData);
		if (strum != null && !heldKeys[psychNote.noteData % 4])
			strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / game.playbackRate;
	}

	public function pressKey(dir:Int):Void
		heldKeys[dir % 4] = true;

	public function releaseKey(dir:Int):Void
	{
		heldKeys[dir % 4] = false;
		var strum:StrumNote = strumAt(dir);
		if (strum != null && strum.resetAnim <= 0)
			strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / game.playbackRate;
	}

	public function isKeyHeld(dir:Int):Bool
		return heldKeys[dir % 4] == true;

	public function playStatic(dir:Int):Void
	{
		var strum:StrumNote = strumAt(dir);
		if (strum != null)
		{
			strum.playAnim('static');
			strum.resetAnim = 0;
		}
	}

	public function playPress(dir:Int):Void
	{
		var strum:StrumNote = strumAt(dir);
		if (strum != null)
			strum.playAnim('pressed');
	}

	public function playConfirm(dir:Int):Void
	{
		var strum:StrumNote = strumAt(dir);
		if (strum != null)
			strum.playAnim('confirm', true);
	}

	/** Psych ya hace el splash al pegar un "sick"; aquí no se repite. */
	public function playNoteSplash(?dir:Int):Void {}

	public function playNoteHoldCover(?holdNote:Dynamic):Void {}

	public function strumAt(dir:Int):StrumNote
	{
		var group = strumlineNotes;
		if (group == null || dir < 0)
			return null;
		return group.members[dir % 4];
	}

	public function toString():String
		return 'Strumline(${playerSide ? 'player' : 'opponent'})';
}

/** noteVibrations de V-Slice (vibración en celulares): aquí no hace nada. */
@:keep
class VSNoteVibrations
{
	public var enabled:Bool = false;

	public function new() {}

	public function tryNoteVibration():Void {}
}

/** Grupo vacío (para strumline.holdNotes). */
@:keep
class VSEmptyGroup
{
	public var members(default, null):Array<Dynamic> = [];
	public var length(get, never):Int;

	public function new() {}

	function get_length():Int
		return 0;

	public function forEach(fn:Dynamic->Void, recursive:Bool = false):Void {}

	public function forEachAlive(fn:Dynamic->Void, recursive:Bool = false):Void {}
}

/** Lista de notas con la forma de un grupo de Flixel (members, forEachAlive...). */
@:keep
class VSNoteList
{
	public var members(default, null):Array<Note>;
	public var length(get, never):Int;

	public function new(members:Array<Note>)
		this.members = members;

	function get_length():Int
		return members.length;

	public function forEach(fn:Note->Void, recursive:Bool = false):Void
		for (note in members.copy())
			fn(note);

	public function forEachAlive(fn:Note->Void, recursive:Bool = false):Void
		for (note in members.copy())
			if (note != null && note.alive)
				fn(note);
}

/** Datos de una nota con la forma de SongNoteData de V-Slice. */
@:keep
class VSNoteData
{
	static var DIRECTION_NAMES:Array<String> = ['left', 'down', 'up', 'right'];

	public var note(default, null):Note;

	public function new(note:Note)
		this.note = note;

	public var time(get, set):Float;

	function get_time():Float
		return note.strumTime;

	function set_time(value:Float):Float
		return note.strumTime = value;

	/** Columna como en V-Slice: 0-3 jugador, 4-7 oponente. */
	public var data(get, never):Int;

	function get_data():Int
		return (note.noteData % 4) + (note.mustPress ? 0 : 4);

	public var length(get, set):Float;

	function get_length():Float
		return note.sustainLength;

	function set_length(value:Float):Float
		return note.sustainLength = value;

	public var kind(get, set):String;

	function get_kind():String
		return note.noteType;

	function set_kind(value:String):String
		return note.noteType = value;

	public function getDirection(strumlineSize:Int = 4):Int
		return note.noteData % strumlineSize;

	public function getDirectionName(strumlineSize:Int = 4):String
		return DIRECTION_NAMES[note.noteData % 4];

	public function getMustHitNote(strumlineSize:Int = 4):Bool
		return note.mustPress;

	public function getStrumlineIndex(strumlineSize:Int = 4):Int
		return note.mustPress ? 0 : 1;

	public function isHoldNote():Bool
		return note.sustainLength > 0;

	public function toString():String
		return 'SongNoteData(${note.strumTime}ms, dir ${note.noteData}, ${note.mustPress ? 'player' : 'opponent'})';
}

/** currentStage de V-Slice: personajes y props del escenario de Psych. */
@:keep
class VSStage
{
	public var game(default, null):PlayState;

	public function new(game:PlayState)
		this.game = game;

	public function getBoyfriend(?pop:Bool):Character
		return game.boyfriend;

	public function getPlayer():Character
		return game.boyfriend;

	public function getGirlfriend(?pop:Bool):Character
		return game.gf;

	public function getDad(?pop:Bool):Character
		return game.dad;

	public function getOpponent():Character
		return game.dad;

	public function getCharacter(id:String):Character
	{
		switch (id)
		{
			case 'bf' | 'boyfriend' | 'player':
				return game.boyfriend;
			case 'gf' | 'girlfriend':
				return game.gf;
			case 'dad' | 'opponent':
				return game.dad;
		}
		if (extraCharacters.exists(id))
			return extraCharacters.get(id);
		for (character in [game.boyfriend, game.dad, game.gf])
			if (character != null && character.curCharacter == id)
				return character;
		for (character in extraCharacters)
			if (character != null && character.curCharacter.toLowerCase() == id.toLowerCase())
				return character;
		return null;
	}

	/** Personajes que agregaron los scripts con addCharacter(..., OTHER), por id. */
	public var extraCharacters(default, null):Map<String, Character> = new Map<String, Character>();

	/**
	 * Stage.addCharacter de V-Slice. Con BF, DAD o GF el personaje pasa a ser el de
	 * Psych (canta las notas, la cámara lo sigue, cambia el ícono) en el lugar del
	 * escenario. Con OTHER (o nada) queda como un personaje más que baila con la canción.
	 */
	public function addCharacter(character:Character, ?type:Dynamic):Void
	{
		if (character == null)
			return;
		var role:String = roleOf(type);
		if (role == null)
		{
			extraCharacters.set(character.curCharacter, character);
			if (!game.members.contains(character))
				game.add(character);
			#if FLUX_VSLICE
			// para que refresh() lo ordene por zIndex junto con el escenario
			if (flux.vslice.FluxVSliceStage.current != null)
				flux.vslice.FluxVSliceStage.current.setZIndex(character, VSliceAdapter.getZIndex(character));
			#end
			character.dance();
			return;
		}

		// el lado del jugador mira hacia el otro lado
		var player:Bool = role == 'bf';
		if (character.isPlayer != player)
		{
			character.isPlayer = player;
			character.flipX = !character.flipX;
		}

		var group:FlxSpriteGroup = switch (role)
		{
			case 'bf': game.boyfriendGroup;
			case 'dad': game.dadGroup;
			default: game.gfGroup;
		}
		if (group != null && !group.members.contains(character))
			group.add(character);

		// el lugar del escenario para ese personaje (como en V-Slice)
		#if FLUX_VSLICE
		if (flux.vslice.FluxVSliceStage.current != null)
			flux.vslice.FluxVSliceStage.current.placeCharacter(character, role);
		else
		#end
		@:privateAccess game.startCharacterPos(character, role == 'dad');

		switch (role)
		{
			case 'bf':
				game.boyfriend = character;
				game.boyfriendMap.set(character.curCharacter, character);
				if (game.iconP1 != null)
					game.iconP1.changeIcon(character.healthIcon);
				game.setOnScripts('boyfriendName', character.curCharacter);
			case 'dad':
				game.dad = character;
				game.dadMap.set(character.curCharacter, character);
				if (game.iconP2 != null)
					game.iconP2.changeIcon(character.healthIcon);
				game.setOnScripts('dadName', character.curCharacter);
			default:
				game.gf = character;
				game.gfMap.set(character.curCharacter, character);
				game.setOnScripts('gfName', character.curCharacter);
		}
		game.reloadHealthBarColors();
		character.dance();
	}

	static function roleOf(type:Dynamic):String
	{
		if (type == null)
			return null;
		return switch (Std.string(type).toLowerCase())
		{
			case 'bf' | 'boyfriend' | 'player': 'bf';
			case 'dad' | 'opponent': 'dad';
			case 'gf' | 'girlfriend': 'gf';
			default: null;
		}
	}

	/** Los personajes agregados bailan en los beats, como bf, dad y gf en Psych. */
	public function beatHit(beat:Int):Void
	{
		for (character in extraCharacters)
		{
			if (character == null || !character.exists || character.stunned)
				continue;
			var anim:String = character.getAnimationName();
			if (anim != null && anim.startsWith('sing'))
				continue;
			if (character.danceEveryNumBeats <= 0 || beat % character.danceEveryNumBeats == 0)
				character.dance();
		}
	}

	/** Props con nombre: en Psych son las variables del PlayState (las de Lua/HScript). */
	public function getNamedProp(name:String):Dynamic
		return game.variables.get(name);

	public function add(object:FlxBasic):Void
		game.add(object);

	public function remove(object:FlxBasic, splice:Bool = false):Void
	{
		if (object == null)
			return;
		for (id => character in extraCharacters)
			if (character == object)
				extraCharacters.remove(id);
		if (game.members.contains(object))
			game.remove(object, splice);
		else
			for (group in [game.boyfriendGroup, game.dadGroup, game.gfGroup])
				if (group != null && group.members.contains(cast object))
					group.remove(cast object, splice);
	}

	/** Lo que hay en el escenario (en Flux, todo el PlayState). */
	public var members(get, never):Array<FlxBasic>;

	function get_members():Array<FlxBasic>
		return game.members;

	public function refresh():Void
		VSliceAdapter.sortByZIndex(game);

	public var camZoom(get, set):Float;

	function get_camZoom():Float
		return game.defaultCamZoom;

	function set_camZoom(value:Float):Float
		return game.defaultCamZoom = value;

	public var id(get, never):String;

	function get_id():String
		return PlayState.curStage;

	public var stageName(get, never):String;

	function get_stageName():String
		return PlayState.curStage;

	public function dispatchToCharacters(event:Dynamic):Void {}

	public function toString():String
		return 'Stage(${PlayState.curStage})';
}

/** Voces de V-Slice (playerVolume / opponentVolume) sobre las dos pistas de Psych. */
@:keep
class VSVoices
{
	var game:PlayState;

	public function new(game:PlayState)
		this.game = game;

	public var playerVolume(get, set):Float;

	function get_playerVolume():Float
		return game.vocals != null ? game.vocals.volume : 0;

	function set_playerVolume(value:Float):Float
	{
		if (game.vocals != null)
			game.vocals.volume = value;
		return value;
	}

	public var opponentVolume(get, set):Float;

	function get_opponentVolume():Float
		return game.opponentVocals != null ? game.opponentVocals.volume : 0;

	function set_opponentVolume(value:Float):Float
	{
		if (game.opponentVocals != null)
			game.opponentVocals.volume = value;
		return value;
	}

	public var volume(get, set):Float;

	function get_volume():Float
		return playerVolume;

	function set_volume(value:Float):Float
	{
		playerVolume = value;
		opponentVolume = value;
		return value;
	}

	public var time(get, set):Float;

	function get_time():Float
		return game.vocals != null ? game.vocals.time : 0;

	function set_time(value:Float):Float
	{
		if (game.vocals != null)
			game.vocals.time = value;
		if (game.opponentVocals != null)
			game.opponentVocals.time = value;
		return value;
	}

	public function play():Void
	{
		if (game.vocals != null)
			game.vocals.play();
		if (game.opponentVocals != null)
			game.opponentVocals.play();
	}

	public function pause():Void
	{
		if (game.vocals != null)
			game.vocals.pause();
		if (game.opponentVocals != null)
			game.opponentVocals.pause();
	}

	public function resume():Void
	{
		if (game.vocals != null)
			game.vocals.resume();
		if (game.opponentVocals != null)
			game.opponentVocals.resume();
	}

	public function stop():Void
	{
		if (game.vocals != null)
			game.vocals.stop();
		if (game.opponentVocals != null)
			game.opponentVocals.stop();
	}
}

/** currentSong de V-Slice. validScore = false hace que no se guarde el puntaje. */
@:keep
class VSSong
{
	var game:PlayState;

	public function new(game:PlayState)
		this.game = game;

	public var validScore(get, set):Bool;

	function get_validScore():Bool
		return game.fluxValidScore;

	function set_validScore(value:Bool):Bool
		return game.fluxValidScore = value;

	public var id(get, never):String;

	function get_id():String
		return PlayState.SONG != null ? Paths.formatToSongPath(PlayState.SONG.song) : '';

	public var songName(get, never):String;

	function get_songName():String
		return PlayState.SONG != null ? PlayState.SONG.song : '';

	public var variation(get, never):String;

	function get_variation():String
		return 'default';

	public function toString():String
		return 'Song($songName)';
}
#end
