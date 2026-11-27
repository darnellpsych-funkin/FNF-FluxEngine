package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
import backend.Conductor;
import backend.Mods;
import backend.Paths;
import flixel.FlxBasic;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flux.vslice.api.VSliceApi.VSSongEventData;
import sys.FileSystem;
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
		if (strum != null && !heldKeys[flux.keys.FluxKeys.dir4(psychNote.noteData)])
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
		return flux.keys.FluxKeys.dir4(note.noteData) + (note.mustPress ? 0 : 4); // con multi-keys: la dirección del carril

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
		return strumlineSize == 4 ? flux.keys.FluxKeys.dir4(note.noteData) : note.noteData % strumlineSize;

	public function getDirectionName(strumlineSize:Int = 4):String
		return DIRECTION_NAMES[flux.keys.FluxKeys.dir4(note.noteData)];

	public function getMustHitNote(strumlineSize:Int = 4):Bool
		return note.mustPress;

	public function getStrumlineIndex(strumlineSize:Int = 4):Int
		return note.mustPress ? 0 : 1;

	public function isHoldNote():Bool
		return note.sustainLength > 0;

	public function toString():String
		return 'SongNoteData(${note.strumTime}ms, dir ${note.noteData}, ${note.mustPress ? 'player' : 'opponent'})';
}

/**
 * Stage de V-Slice. PlayState.currentStage es el escenario con el que empezó la
 * canción (sus personajes son los de Psych). StageRegistry.fetchEntry(id) arma
 * otro escenario de V-Slice (data/stages/<id>.json) para cambiarlo a mitad de la
 * canción, como hace V-Slice:
 *
 *   PlayState.instance.remove(PlayState.instance.currentStage);
 *   PlayState.instance.currentStage = StageRegistry.instance.fetchEntry('otro');
 *   PlayState.instance.currentStage.buildStage();
 *   PlayState.instance.add(PlayState.instance.currentStage);
 *   PlayState.instance.currentStage.addCharacter(bf, CharacterType.BF);
 */
@:keep
class VSStage
{
	public var id(default, null):String;

	/** El PlayState actual. */
	public var game(get, never):PlayState;

	inline function get_game():PlayState
		return PlayState.instance;

	#if FLUX_VSLICE
	/** Los props y el JSON de V-Slice (null si es un escenario de Psych). */
	public var vslice(get, never):flux.vslice.FluxVSliceStage;

	var _vslice:flux.vslice.FluxVSliceStage = null;

	function get_vslice():flux.vslice.FluxVSliceStage
	{
		// el escenario de la canción: el de V-Slice que armó el PlayState
		if (_vslice == null && initial && game != null && isCurrent())
			_vslice = game.vsliceStage;
		return _vslice;
	}
	#end

	/** true: el escenario con el que empezó la canción (sus personajes son bf, dad y gf de Psych). */
	public var initial(default, null):Bool = false;

	/** Personajes que se agregaron con addCharacter (rol -> personaje). */
	var roles:Map<String, Character> = new Map<String, Character>();

	public var alive(default, null):Bool = true;
	public var exists:Bool = true;
	public var active:Bool = true;

	/** Personajes que agregaron los scripts con addCharacter(..., OTHER), por id. */
	public var extraCharacters(default, null):Map<String, Character> = new Map<String, Character>();

	public function new(id:String)
	{
		this.id = id;
		#if FLUX_VSLICE
		if (id != null)
			_vslice = flux.vslice.FluxVSliceStage.fromId(id);
		#end
		_camZoom = #if FLUX_VSLICE vslice != null ? vslice.cameraZoom : #end 1.0;
	}

	/** El escenario con el que empezó la canción. */
	public static function forGame(game:PlayState):VSStage
	{
		var stage:VSStage = new VSStage(null);
		stage.id = PlayState.curStage;
		stage.initial = true;
		#if FLUX_VSLICE
		stage._vslice = game != null ? game.vsliceStage : null;
		#end
		stage._camZoom = game != null ? game.defaultCamZoom : 1.0;
		return stage;
	}

	/** Si es el PlayState.currentStage ahora. */
	public function isCurrent():Bool
		return game != null && VSliceAdapter.currentStageOf(game) == this;

	/** El JSON de V-Slice (data/stages/<id>.json); en uno de Psych, lo básico. */
	public var _data(get, never):Dynamic;

	function get__data():Dynamic
	{
		#if FLUX_VSLICE
		if (vslice != null)
			return vslice.data;
		#end
		return {name: id, directory: 'shared', cameraZoom: camZoom, props: [], characters: {}};
	}

	public var stageName(get, never):String;

	function get_stageName():String
	{
		var data:Dynamic = _data;
		return (data != null && data.name != null) ? Std.string(data.name) : id;
	}

	// ----- personajes -----

	static var ROLE_NAMES:Array<String> = ['bf', 'dad', 'gf'];

	function gameRole(role:String):Character
	{
		if (game == null)
			return null;
		return switch (role)
		{
			case 'bf': game.boyfriend;
			case 'dad': game.dad;
			default: game.gf;
		}
	}

	/** El personaje de ese rol (bf, dad o gf) en este escenario. */
	function roleCharacter(role:String):Character
	{
		if (initial || roles.exists(role))
			return isCurrent() ? gameRole(role) : roles.get(role);
		return null;
	}

	public function getBoyfriend(?pop:Bool):Character
		return popped(roleCharacter('bf'), pop);

	public function getPlayer(?pop:Bool):Character
		return getBoyfriend(pop);

	public function getGirlfriend(?pop:Bool):Character
		return popped(roleCharacter('gf'), pop);

	public function getDad(?pop:Bool):Character
		return popped(roleCharacter('dad'), pop);

	public function getOpponent(?pop:Bool):Character
		return getDad(pop);

	/** getBoyfriend(true) de V-Slice: lo saca del escenario. */
	function popped(character:Character, pop:Null<Bool>):Character
	{
		if (pop == true && character != null)
			remove(character, true);
		return character;
	}

	public function getCharacter(id:String):Character
	{
		if (id == null)
			return null;
		switch (id)
		{
			case 'bf' | 'boyfriend' | 'player':
				return roleCharacter('bf');
			case 'gf' | 'girlfriend':
				return roleCharacter('gf');
			case 'dad' | 'opponent':
				return roleCharacter('dad');
		}
		if (extraCharacters.exists(id))
			return extraCharacters.get(id);
		for (role in ROLE_NAMES)
		{
			var character:Character = roleCharacter(role);
			if (character != null && character.curCharacter == id)
				return character;
		}
		var lower:String = id.toLowerCase();
		for (character in extraCharacters)
			if (character != null && character.curCharacter.toLowerCase() == lower)
				return character;
		return null;
	}

	/** Donde van parados los personajes según el escenario (el centro de abajo). */
	public function getBoyfriendPosition():FlxPoint
		return rolePosition('bf');

	public function getGirlfriendPosition():FlxPoint
		return rolePosition('gf');

	public function getDadPosition():FlxPoint
		return rolePosition('dad');

	function rolePosition(role:String):FlxPoint
	{
		#if FLUX_VSLICE
		if (vslice != null)
		{
			var position:Array<Float> = vslice.rolePosition(role);
			return new FlxPoint(position[0], position[1]);
		}
		#end
		// escenario de Psych: la esquina de su grupo (BF_X, BF_Y...)
		if (game != null)
			return switch (role)
			{
				case 'bf': new FlxPoint(game.BF_X, game.BF_Y);
				case 'dad': new FlxPoint(game.DAD_X, game.DAD_Y);
				default: new FlxPoint(game.GF_X, game.GF_Y);
			}
		return new FlxPoint();
	}

	/**
	 * Stage.addCharacter de V-Slice. Con BF, DAD o GF el personaje pasa a ser el de
	 * Psych (canta las notas, la cámara lo sigue, cambia el ícono) en el lugar del
	 * escenario. Con OTHER (o nada) queda como un personaje más que baila con la canción.
	 */
	public function addCharacter(character:Character, ?type:Dynamic):Void
	{
		if (character == null || game == null)
			return;
		var role:String = roleOf(type);
		if (role == null)
		{
			extraCharacters.set(character.curCharacter, character);
			if (!game.members.contains(character))
				game.add(character);
			#if FLUX_VSLICE
			// para que refresh() lo ordene por zIndex junto con el escenario
			if (vslice != null)
				vslice.addExtra(character);
			if (flux.vslice.FluxVSliceStage.current != null)
				flux.vslice.FluxVSliceStage.current.setZIndex(character, VSliceAdapter.getZIndex(character));
			#end
			character.dance();
			return;
		}

		roles.set(role, character);
		if (!isCurrent() && !initial)
			return; // se agrega al juego cuando el escenario pase a ser el actual

		placeInGame(character, role);
	}

	/** Pone al personaje como bf, dad o gf de Psych en este escenario. */
	function placeInGame(character:Character, role:String):Void
	{
		var game:PlayState = this.game;

		// el lado del jugador mira hacia el otro lado
		var player:Bool = role == 'bf';
		if (character.isPlayer != player)
		{
			character.isPlayer = player;
			character.flipX = !character.flipX;
		}
		if (!character.alive)
			character.revive();

		var group:FlxSpriteGroup = switch (role)
		{
			case 'bf': game.boyfriendGroup;
			case 'dad': game.dadGroup;
			default: game.gfGroup;
		}
		if (group != null)
		{
			// el anterior de ese lugar, si se destruyó, se saca del grupo
			var previous:Character = gameRole(role);
			if (previous != null && previous != character && previous.frames == null)
			{
				group.remove(previous, true);
				var map:Map<String, Character> = role == 'bf' ? game.boyfriendMap : (role == 'dad' ? game.dadMap : game.gfMap);
				if (map != null && map.get(previous.curCharacter) == previous)
					map.remove(previous.curCharacter);
			}
			if (!group.members.contains(character))
				group.add(character);
		}

		// el lugar del escenario para ese personaje (como en V-Slice)
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.placeCharacter(character, role);
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
		VSliceAdapter.setCharacterRole(character, role);
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
			case 'gf' | 'girlfriend' | 'spectator': 'gf';
			default: null;
		}
	}

	/** Los personajes agregados bailan en los beats, como bf, dad y gf en Psych. */
	public function beatHit(beat:Int):Void
	{
		for (character in extraCharacters)
		{
			if (character == null || !character.exists || !character.alive || character.stunned)
				continue;
			var anim:String = character.getAnimationName();
			if (anim != null && anim.startsWith('sing'))
				continue;
			if (character.danceEveryNumBeats <= 0 || beat % character.danceEveryNumBeats == 0)
				character.dance();
		}
	}

	// ----- props -----

	/** Props con nombre del escenario; si no hay, las variables del PlayState (las de Lua/HScript). */
	public function getNamedProp(name:String):Dynamic
	{
		#if FLUX_VSLICE
		if (vslice != null)
		{
			var prop:Dynamic = vslice.getNamedProp(name);
			if (prop != null)
				return prop;
		}
		#end
		return game != null ? game.variables.get(name) : null;
	}

	/** Agrega algo al escenario: se ordena por zIndex con los props (refresh) y se va con el escenario. */
	public function add(object:FlxBasic):FlxBasic
	{
		if (object == null)
			return null;
		#if FLUX_VSLICE
		if (vslice != null)
		{
			vslice.addExtra(object);
			if (!vslice.attached && game != null && !game.members.contains(object) && isCurrent())
				game.add(object);
			return object;
		}
		#end
		if (game != null)
			game.add(object);
		return object;
	}

	public function remove(object:FlxBasic, splice:Bool = false):FlxBasic
	{
		if (object == null || game == null)
			return object;
		for (id => character in extraCharacters)
			if (character == object)
				extraCharacters.remove(id);
		for (role => character in roles)
			if (character == object)
				roles.remove(role);
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.removeExtra(object);
		#end
		if (game.members.contains(object))
			game.remove(object, splice);
		else
			for (group in [game.boyfriendGroup, game.dadGroup, game.gfGroup])
				if (group != null && group.members.contains(cast object))
					group.remove(cast object, splice);
		return object;
	}

	/** Lo que hay en el escenario (en Flux, todo el PlayState). */
	public var members(get, never):Array<FlxBasic>;

	function get_members():Array<FlxBasic>
		return game != null ? game.members : [];

	public function refresh():Void
	{
		#if FLUX_VSLICE
		if (vslice != null && vslice.attached)
		{
			vslice.refresh();
			return;
		}
		#end
		if (game != null)
			VSliceAdapter.sortByZIndex(game);
	}

	/** Zoom de cámara del escenario (PlayState.resetCameraZoom lo usa). */
	public var camZoom(get, set):Float;

	var _camZoom:Float = 1.0;

	function get_camZoom():Float
		return (isCurrent() && game != null && initial) ? game.defaultCamZoom : _camZoom;

	function set_camZoom(value:Float):Float
	{
		_camZoom = value;
		if (isCurrent() && game != null)
			game.defaultCamZoom = value;
		return value;
	}

	// ----- armar, quitar y reiniciar -----

	/** Stage.buildStage de V-Slice: crea los props (se ven al agregar el escenario al PlayState). */
	public function buildStage():Void
	{
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.buildProps();
		#end
	}

	/** Stage.resetStage de V-Slice: los personajes y los props con nombre vuelven a su lugar. */
	public function resetStage():Void
	{
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.resetProps();
		#end
		for (role in ROLE_NAMES)
		{
			var character:Character = roleCharacter(role);
			if (character == null)
				continue;
			#if FLUX_VSLICE
			if (vslice != null)
				vslice.placeCharacter(character, role);
			#end
			character.dance();
		}
	}

	/** El PlayState pasa a usar este escenario (PlayState.currentStage = esto). */
	public function makeCurrent(game:PlayState):Void
	{
		if (game == null)
			return;
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.applyTo(game, false);
		else
		#end
		PlayState.curStage = id;
		// los personajes que se agregaron antes de que fuera el actual
		for (role in ROLE_NAMES)
			if (roles.exists(role) && roles.get(role) != gameRole(role))
				placeInGame(roles.get(role), role);
	}

	/** PlayState.add(currentStage): los props y los personajes entran al juego. */
	public function attachTo(game:PlayState, index:Int):Void
	{
		if (game == null)
			return;
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.attach(game, index);
		#end
	}

	/** PlayState.remove(currentStage): los props salen del juego. Devuelve dónde estaban. */
	public function detachFrom(game:PlayState):Int
	{
		// guarda sus personajes (V-Slice los guarda en el escenario)
		if (initial)
			for (role in ROLE_NAMES)
				if (!roles.exists(role) && gameRole(role) != null)
					roles.set(role, gameRole(role));
		#if FLUX_VSLICE
		if (vslice != null)
			return vslice.detach();
		#end
		return -1;
	}

	/** Stage.kill de V-Slice: el escenario y sus personajes dejan de verse. */
	public function kill():Void
	{
		alive = false;
		exists = false;
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.killProps();
		#end
		for (role in ROLE_NAMES)
		{
			var character:Character = roles.exists(role) ? roles.get(role) : (initial ? gameRole(role) : null);
			if (character != null)
				character.kill();
		}
		for (character in extraCharacters)
			if (character != null)
				character.kill();
	}

	public function revive():Void
	{
		alive = true;
		exists = true;
		#if FLUX_VSLICE
		if (vslice != null)
			vslice.reviveProps();
		#end
	}

	public function destroy():Void
	{
		kill();
		if (game != null)
			detachFrom(game);
	}

	public var visible(get, set):Bool;

	var _visible:Bool = true;

	function get_visible():Bool
		return _visible;

	function set_visible(value:Bool):Bool
	{
		_visible = value;
		#if FLUX_VSLICE
		if (vslice != null)
			for (prop in vslice.props)
				prop.visible = value;
		#end
		return value;
	}

	public function dispatchToCharacters(event:Dynamic):Void {}

	public function toString():String
		return 'Stage($id)';
}

/** StageRegistry de V-Slice: los escenarios de data/stages/ (de los mods y del juego). */
@:keep
class VSStageRegistry
{
	public static var instance(get, never):VSStageRegistry;

	static var _instance:VSStageRegistry;

	static function get_instance():VSStageRegistry
	{
		if (_instance == null)
			_instance = new VSStageRegistry();
		return _instance;
	}

	public function new() {}

	/** Un escenario nuevo (sin armar). Null si no hay uno de V-Slice con ese id. */
	public function fetchEntry(id:String):VSStage
	{
		var stage:VSStage = new VSStage(id);
		#if FLUX_VSLICE
		if (stage.vslice == null)
		{
			trace('[V-Slice] StageRegistry: no hay un escenario de V-Slice "$id" (data/stages/$id.json)');
			return null;
		}
		#end
		return stage;
	}

	public function hasEntry(id:String):Bool
		return readData(id) != null;

	public function listEntryIds():Array<String>
		return VSDataFiles.listIds('data/stages/');

	public function fetchEntryVersion(id:String):String
	{
		var data:Dynamic = readData(id);
		return (data != null && data.version != null) ? Std.string(data.version) : '1.0.0';
	}

	public function parseEntryData(id:String):Dynamic
		return readData(id);

	public function parseEntryDataWithMigration(id:String, ?version:Dynamic):Dynamic
		return readData(id);

	public function parseEntryDataRaw(contents:String, ?fileName:String):Dynamic
	{
		try
		{
			return haxe.Json.parse(contents);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	public function loadEntries():Void {}

	function readData(id:String):Dynamic
	{
		#if FLUX_VSLICE
		return FluxVSliceModules.withModFallback(() -> flux.vslice.FluxVSliceStage.readData(id));
		#else
		return null;
		#end
	}
}

/** Busca archivos .json de una carpeta de datos (data/stages/, data/songs/...) en los mods y el juego. */
@:keep
class VSDataFiles
{
	public static function listIds(sub:String):Array<String>
	{
		var ids:Array<String> = [];
		var folders:Array<String> = [];
		for (dir in Mods.directoriesWithFile(Paths.getSharedPath(), sub))
			folders.push(dir);
		#if MODS_ALLOWED
		for (mod in FluxVSliceModules.enabledMods)
			folders.push(Paths.mods('$mod/$sub'));
		#end
		for (dir in folders)
		{
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
				continue;
			for (file in FileSystem.readDirectory(dir))
			{
				if (!file.toLowerCase().endsWith('.json'))
					continue;
				var id:String = file.substr(0, file.length - 5);
				if (!ids.contains(id))
					ids.push(id);
			}
		}
		return ids;
	}
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

	public function set_playerVolume(value:Float):Float
	{
		if (game.vocals != null)
			game.vocals.volume = value;
		return value;
	}

	public var opponentVolume(get, set):Float;

	function get_opponentVolume():Float
		return game.opponentVocals != null ? game.opponentVocals.volume : 0;

	public function set_opponentVolume(value:Float):Float
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

	/** La pista de voces del jugador (en Psych hay una por lado). */
	public function getPlayerVoice(index:Int = 0):flixel.sound.FlxSound
		return index == 0 ? game.vocals : null;

	public function getOpponentVoice(index:Int = 0):flixel.sound.FlxSound
		return index == 0 ? game.opponentVocals : null;

	public function getPlayerVoiceLength():Float
		return game.vocals != null ? game.vocals.length : 0;

	public function getOpponentVoiceLength():Float
		return game.opponentVocals != null ? game.opponentVocals.length : 0;

	public var muted(get, set):Bool;

	function get_muted():Bool
		return game.vocals != null && game.vocals.volume == 0;

	function set_muted(value:Bool):Bool
	{
		volume = value ? 0 : 1;
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

/**
 * Song de V-Slice (PlayState.currentSong). validScore = false hace que no se
 * guarde el puntaje. Los datos vienen del chart de V-Slice (o del de Psych).
 */
@:keep
class VSSong
{
	public var id(default, null):String;

	public function new(id:String)
		this.id = id;

	/** La canción que se está jugando. */
	public static function forGame(game:PlayState):VSSong
	{
		var info:Dynamic = vsliceInfo();
		var id:String = (info != null && info.id != null) ? Std.string(info.id) : (PlayState.SONG != null ? Paths.formatToSongPath(PlayState.SONG.song) : '');
		return new VSSong(id);
	}

	/** Lo que guardó FluxVSlice del chart de V-Slice (null si la canción es de Psych). */
	public static function vsliceInfo():Dynamic
	{
		#if FLUX_VSLICE
		return flux.vslice.FluxVSlice.info(PlayState.SONG);
		#else
		return null;
		#end
	}

	var game(get, never):PlayState;

	inline function get_game():PlayState
		return PlayState.instance;

	public var validScore(get, set):Bool;

	function get_validScore():Bool
		return game != null ? game.fluxValidScore : true;

	function set_validScore(value:Bool):Bool
	{
		if (game != null)
			game.fluxValidScore = value;
		return value;
	}

	public var songName(get, never):String;

	function get_songName():String
	{
		var info:Dynamic = vsliceInfo();
		if (info != null && info.songName != null)
			return Std.string(info.songName);
		return PlayState.SONG != null ? PlayState.SONG.song : id;
	}

	public var songArtist(get, never):String;

	function get_songArtist():String
	{
		var info:Dynamic = vsliceInfo();
		return (info != null && info.artist != null) ? Std.string(info.artist) : 'Unknown';
	}

	public var charter(get, never):String;

	function get_charter():String
	{
		var info:Dynamic = vsliceInfo();
		return (info != null && info.charter != null) ? Std.string(info.charter) : 'Unknown';
	}

	public var variation(get, never):String;

	function get_variation():String
	{
		var info:Dynamic = vsliceInfo();
		return (info != null && info.variation != null) ? Std.string(info.variation) : 'default';
	}

	/**
	 * Las dificultades por variación: difficulties.get(variación).get(dificultad).
	 * Flux solo tiene cargada la que se está jugando, así que se devuelve esa
	 * aunque el script pida otro nombre (ej. "Normal" en vez de "normal").
	 */
	public var difficulties(get, never):VSLenientMap;

	var _difficulties:VSLenientMap;
	var _current:VSSongDifficulty;

	function get_difficulties():VSLenientMap
	{
		if (_difficulties == null)
		{
			var current:VSSongDifficulty = getDifficulty();
			var byDifficulty:VSLenientMap = new VSLenientMap();
			byDifficulty.set(current.difficulty, current);
			_difficulties = new VSLenientMap();
			_difficulties.set(current.variation, byDifficulty);
		}
		return _difficulties;
	}

	/** La dificultad que se está jugando (Flux solo tiene cargada esa). */
	public function getDifficulty(?diffId:String, ?variation:String, ?variations:Array<String>):VSSongDifficulty
	{
		if (_current == null)
			_current = new VSSongDifficulty(this);
		return _current;
	}

	public function hasDifficulty(diffId:String, ?variation:String, ?variations:Array<String>):Bool
		return listDifficulties().contains(diffId);

	public function listDifficulties(?variation:String, ?variations:Array<String>, ?showLocked:Bool, ?showHidden:Bool):Array<String>
	{
		var info:Dynamic = vsliceInfo();
		if (info != null && Std.isOfType(info.difficulties, Array))
			return [for (d in (info.difficulties : Array<Dynamic>)) Std.string(d)];
		return [getDifficulty().difficulty];
	}

	public function listVariations():Array<String>
		return [variation];

	public function getFirstValidVariation(?diffId:String, ?possibleVariations:Array<String>):String
		return variation;

	public function toString():String
		return 'Song($id)';
}

/**
 * Un Map de texto -> valor que, si no tiene la clave pedida y tiene un solo valor,
 * devuelve ese (para currentSong.difficulties de V-Slice).
 */
@:keep
class VSLenientMap implements haxe.Constraints.IMap<String, Dynamic>
{
	var map:Map<String, Dynamic> = new Map<String, Dynamic>();

	public function new() {}

	public function get(key:String):Dynamic
	{
		if (map.exists(key))
			return map.get(key);
		var only:Dynamic = null;
		var count:Int = 0;
		for (value in map)
		{
			only = value;
			count++;
		}
		return count == 1 ? only : null;
	}

	public function set(key:String, value:Dynamic):Void
		map.set(key, value);

	public function exists(key:String):Bool
		return map.exists(key);

	public function remove(key:String):Bool
		return map.remove(key);

	public function keys():Iterator<String>
		return map.keys();

	public function iterator():Iterator<Dynamic>
		return map.iterator();

	public function keyValueIterator():KeyValueIterator<String, Dynamic>
		return map.keyValueIterator();

	public function copy():haxe.Constraints.IMap<String, Dynamic>
	{
		var result:VSLenientMap = new VSLenientMap();
		for (key => value in map)
			result.set(key, value);
		return result;
	}

	public function toString():String
		return map.toString();

	public function clear():Void
		map.clear();
}

/** SongDifficulty de V-Slice (PlayState.currentChart): los datos del chart que se está jugando. */
@:keep
class VSSongDifficulty
{
	public var song(default, null):VSSong;
	public var difficulty(default, null):String;
	public var variation(default, null):String;
	public var songName(default, null):String;
	public var songArtist(default, null):String;
	public var charter(default, null):String;
	public var album(default, null):String;
	public var stage(default, null):String;
	public var noteStyle(default, null):String;
	public var generatedBy(default, null):String;
	public var looped(default, null):Bool = false;

	/** {player, girlfriend, opponent, instrumental, altInstrumentals, playerVocals, opponentVocals} */
	public var characters(default, null):Dynamic;

	public var scrollSpeed(default, null):Float;
	public var timeChanges(default, null):Array<Dynamic>;

	public function new(song:VSSong)
	{
		this.song = song;
		var swag = PlayState.SONG;
		var info:Dynamic = VSSong.vsliceInfo();
		difficulty = (info != null && info.difficulty != null) ? Std.string(info.difficulty) : Paths.formatToSongPath(backend.Difficulty.getString());
		variation = song.variation;
		songName = song.songName;
		songArtist = song.songArtist;
		charter = song.charter;
		album = (info != null && info.album != null) ? Std.string(info.album) : null;
		stage = swag != null ? swag.stage : null;
		noteStyle = (info != null && info.noteStyle != null) ? Std.string(info.noteStyle) : 'funkin';
		generatedBy = (info != null && info.generatedBy != null) ? Std.string(info.generatedBy) : 'Psych Engine';
		scrollSpeed = swag != null ? swag.speed : 1.0;

		var player:String = swag != null ? swag.player1 : 'bf';
		var opponent:String = swag != null ? swag.player2 : 'dad';
		var girlfriend:String = swag != null ? swag.gfVersion : 'gf';
		characters = {
			player: player,
			girlfriend: girlfriend,
			opponent: opponent,
			instrumental: (info != null && info.instrumental != null) ? Std.string(info.instrumental) : '',
			altInstrumentals: [],
			playerVocals: (info != null && info.playerVocals != null) ? info.playerVocals : [player],
			opponentVocals: (info != null && info.opponentVocals != null) ? info.opponentVocals : [opponent]
		};

		if (info != null && Std.isOfType(info.timeChanges, Array))
			timeChanges = info.timeChanges;
		else
			timeChanges = [{t: 0, bpm: swag != null ? swag.bpm : 100}];
	}

	public function getStartingBPM():Float
	{
		if (timeChanges != null && timeChanges.length > 0 && timeChanges[0].bpm != null)
			return timeChanges[0].bpm;
		return PlayState.SONG != null ? PlayState.SONG.bpm : 100;
	}

	public function getScrollSpeed():Float
		return scrollSpeed;

	/** Los eventos del chart (los mismos que PlayState.songEvents). */
	public var events(get, never):Array<VSSongEventData>;

	function get_events():Array<VSSongEventData>
	{
		var game:PlayState = PlayState.instance;
		var list:Dynamic = game != null ? VSliceAdapter.getField(game, 'songEvents') : null;
		return Std.isOfType(list, Array) ? list : [];
	}

	public function getEvents():Array<VSSongEventData>
		return events;

	/** Las notas del chart (como SongNoteData). */
	public var notes(get, never):Array<Dynamic>;

	function get_notes():Array<Dynamic>
	{
		var game:PlayState = PlayState.instance;
		if (game == null)
			return [];
		return [for (note in game.unspawnNotes) if (note != null && !note.isSustainNote) new VSNoteData(note)];
	}

	public function getNotes(?variation:String):Array<Dynamic>
		return notes;

	public function toString():String
		return 'SongDifficulty(${song.id} $variation $difficulty)';
}
#end
