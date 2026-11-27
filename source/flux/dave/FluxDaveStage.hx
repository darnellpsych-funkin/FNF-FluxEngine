package flux.dave;

#if FLUX_DAVE_SCRIPTS
import backend.BaseStage;
import backend.StageData.StageFile;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flux.dave.api.DaveApi;
import flux.dave.api.DaveStage;
import flux.vslice.FluxVSliceAssets;
import flux.vslice.api.ScriptEvent;
import flux.vslice.modules.VSliceAdapter;
import haxe.ds.ArraySort;
import haxe.ds.ObjectMap;
import objects.Character;
import objects.Note;
import openfl.utils.AssetType;

/**
 * Escenarios de Dave Engine (VS Dave and Bambi Volume 1): data/stages/<id>.json
 * (zoom, posición, scroll, zIndex y cámara de cada personaje) + scripts/stages/<id>.hxc
 * (los props, con BGSprite y add()).
 *
 * PlayState lo usa cuando la canción pide un escenario que no es de Psych (o, en una
 * canción de Dave, cuando el de Psych es del juego base, como "stage" o "school").
 * Ordena los props con los grupos de los personajes por zIndex y les manda a los
 * scripts (del escenario y de los personajes de Dave) los eventos de la canción.
 */
class FluxDaveStage extends BaseStage
{
	/** El escenario de Dave de la canción actual (o el que solo manda eventos a los personajes de Dave). */
	public static var current(default, null):FluxDaveStage = null;

	/** PlayState.instance.gfOverride de Dave: la GF que pide el escenario (null = la del jugador). */
	public static var gfOverride:String = null;

	/** PlayState.instance.elapsedTime de Dave: segundos que corrió la canción (sin pausas). */
	public static var elapsedTime(default, null):Float = 0;

	public var id(default, null):String;

	/** El JSON de Dave (null si solo está para los personajes de Dave). */
	public var data(default, null):Dynamic;

	/** El script del escenario (null si no tiene). */
	public var script(default, null):DaveStage;

	public var stageFile(default, null):StageFile;

	/** Lo que agregó el script con add() (props y lo que sea), en orden. */
	public var props(default, null):Array<FlxBasic> = [];

	/** Los BGSprite por nombre (getProp). */
	public var namedProps(default, null):Map<String, FlxBasic> = new Map<String, FlxBasic>();

	/** Personajes que agregaron los scripts con addCharacter(). */
	public var extraCharacters(default, null):Array<Character> = [];

	/** Si los props ya están en el PlayState (build). */
	public var built(default, null):Bool = false;

	var playState:PlayState;
	var groupZ:ObjectMap<FlxBasic, Int> = new ObjectMap<FlxBasic, Int>();
	var pausedByMenu:Bool = false;

	/** El escenario de Dave con ese id (null si no hay o si gana uno de Psych). */
	public static function load(id:String):FluxDaveStage
	{
		current = null;
		gfOverride = null;
		elapsedTime = 0;
		if (id == null || id.length == 0)
			return null;
		if (!DaveCharacters.daveWins(Paths.getPath('stages/$id.json', TEXT)))
			return null;
		var data:Dynamic = readData(id);
		if (data == null)
			return null;
		trace('[Flux Dave Engine] escenario $id');
		return new FluxDaveStage(id, data);
	}

	/**
	 * Sin escenario de Dave pero con personajes de Dave en la canción: un escenario vacío
	 * que solo les manda los eventos (onBeatHit, onUpdate...).
	 */
	public static function forCharacters(game:PlayState):FluxDaveStage
	{
		if (current != null || game == null)
			return current;
		for (char in [game.gf, game.dad, game.boyfriend])
			if (char != null && char.daveScript != null)
			{
				var stage:FluxDaveStage = new FluxDaveStage(null, null);
				stage.playState = game;
				stage.placeCharacter(game.gf, 'gf');
				stage.placeCharacter(game.dad, 'dad');
				stage.placeCharacter(game.boyfriend, 'bf');
				return stage;
			}
		return null;
	}

	/** data/stages/<id>.json de Dave Engine, o null. */
	public static function readData(id:String):Dynamic
	{
		if (id == null || id.length == 0)
			return null;
		var data:Dynamic = FluxVSliceAssets.readJson(FluxVSliceAssets.findData('data/stages/$id.json'));
		return DaveData.isStage(data) ? data : null;
	}

	function new(id:String, data:Dynamic)
	{
		super();
		this.id = id;
		this.data = data;
		playState = PlayState.instance;
		current = this;
		if (data == null)
			return;
		stageFile = makeStageFile();
		var className:String = DaveScripts.stageClasses.get(id);
		if (className != null)
		{
			script = DaveScripts.createStage(className, this);
			if (script != null)
			{
				try
				{
					script.load();
				}
				catch (e:Dynamic)
				{
					DaveScripts.report(script, e);
				}
			}
		}
	}

	function makeStageFile():StageFile
	{
		var bfCam:Array<Float> = cameraOffsetsOf(DaveCharacterType.PLAYER);
		var dadCam:Array<Float> = cameraOffsetsOf(DaveCharacterType.OPPONENT);
		var gfCam:Array<Float> = cameraOffsetsOf(DaveCharacterType.GF);
		return {
			directory: '',
			defaultZoom: DaveData.num(data.zoom, 1),
			isPixelStage: false,
			stageUI: 'normal',
			boyfriend: positionOf('bf'),
			girlfriend: positionOf('gf'),
			opponent: positionOf('dad'),
			hide_girlfriend: false,
			// Psych: bf = medio - 100 - cameraPosition + esto; dad = medio + 150 + ...; gf = medio + ...
			camera_boyfriend: [bfCam[0] + 100, bfCam[1] + 100],
			camera_opponent: [dadCam[0] - 150, dadCam[1] + 100],
			camera_girlfriend: [gfCam[0], gfCam[1]],
			camera_speed: null
		};
	}

	/** Los datos del JSON de un lugar: 'bf', 'dad' o 'gf'. */
	public function roleData(role:String):Dynamic
	{
		if (data == null)
			return null;
		return switch (role)
		{
			case 'bf': data.player;
			case 'dad': data.opponent;
			case 'gf': data.gf;
			default: null;
		}
	}

	/** CharacterType de Dave (PLAYER, OPPONENT, GF) -> 'bf', 'dad', 'gf'. */
	public static function roleOfType(type:String):String
	{
		return switch (type)
		{
			case 'PLAYER': 'bf';
			case 'OPPONENT': 'dad';
			case 'GF': 'gf';
			default: null;
		}
	}

	function positionOf(role:String):Array<Dynamic>
	{
		var info:Dynamic = roleData(role);
		var pos:Array<Float> = DaveCharacters.pair(info != null ? info.position : null);
		return [pos[0], pos[1]];
	}

	/** Los cameraOffsets del escenario para un tipo de personaje. */
	public function cameraOffsetsOf(type:String):Array<Float>
	{
		var info:Dynamic = roleData(roleOfType(type));
		return DaveCharacters.pair(info != null ? info.cameraOffsets : null);
	}

	// ----- Props -----

	/** Stage.add de Dave. Antes de build() se guarda; después se agrega al juego y se ordena. */
	public function addProp(object:FlxBasic):Void
	{
		if (object == null)
			return;
		if (Std.isOfType(object, Character))
		{
			addCharacter(cast object, null, null, false);
			return;
		}
		if (!props.contains(object))
			props.push(object);
		if (Std.isOfType(object, DaveBGSprite))
		{
			var name:String = (cast object : DaveBGSprite).spriteName;
			if (name != null && name.length > 0)
			{
				namedProps.set(name, object);
				if (playState != null)
					playState.variables.set(name, object); // getProperty('bg.alpha') desde Lua/HScript
			}
		}
		if (built && playState != null)
		{
			if (playState.members.indexOf(object) < 0)
				playState.add(object);
			refresh();
		}
		dispatch('onAdd', new DaveAddPropEvent(object), false);
	}

	public function removeProp(object:FlxBasic):Void
	{
		if (object == null)
			return;
		props.remove(object);
		extraCharacters.remove(cast object);
		for (name => prop in namedProps)
			if (prop == object)
				namedProps.remove(name);
		if (playState != null && playState.members.indexOf(object) >= 0)
			playState.remove(object, true);
	}

	/** Stage.addCharacter de Dave (para los que agregan los scripts): en el lugar del tipo y ordenado. */
	public function addCharacter(char:Character, ?type:String, ?position:FlxPoint, reposition:Bool = true):Void
	{
		if (char == null)
			return;
		if (type == null)
			type = char.daveScript != null ? char.daveScript.characterType : DaveCharacterType.OTHER;
		var role:String = roleOfType(type);
		var info:Dynamic = roleData(role);
		if (info != null)
		{
			var pos:Array<Float> = DaveCharacters.pair(info.position);
			char.setPosition(pos[0], pos[1]);
			var scroll:Array<Float> = DaveCharacters.pair(info.scroll, [1, 1]);
			char.scrollFactor.set(scroll[0], scroll[1]);
			if (info.zIndex != null)
				groupZ.set(char, Std.int(info.zIndex));
		}
		if (position != null)
			char.setPosition(position.x, position.y);
		if (reposition)
		{
			char.x += char.positionArray[0];
			char.y += char.positionArray[1];
		}
		if (char.daveScript != null)
			char.daveScript.characterType = type;
		if (!extraCharacters.contains(char))
			extraCharacters.push(char);
		if (playState != null && playState.members.indexOf(char) < 0)
		{
			playState.add(char);
			refresh();
		}
		dispatch('onCharacterAdd', new DaveAddCharacterEvent(char), false);
	}

	/**
	 * Lo llama PlayState.startCharacterPos (también al cambiar de personaje): el tipo de
	 * personaje de Dave y el onCharacterAdd del escenario (ej. el color de noche).
	 */
	public function placeCharacter(char:Character, role:String):Void
	{
		if (char == null)
			return;
		if (char.daveScript != null)
			char.daveScript.characterType = switch (role)
			{
				case 'bf': DaveCharacterType.PLAYER;
				case 'dad': DaveCharacterType.OPPONENT;
				case 'gf': DaveCharacterType.GF;
				default: DaveCharacterType.OTHER;
			};
		dispatch('onCharacterAdd', new DaveAddCharacterEvent(char), false);
	}

	/** Agrega los props y los grupos de los personajes al PlayState ordenados por zIndex. */
	public function build(game:PlayState):Void
	{
		playState = game;
		var entries:Array<{z:Int, object:FlxBasic}> = [];
		for (prop in props)
			entries.push({z: zOf(prop), object: prop});
		for (role in ['gf', 'dad', 'bf'])
		{
			var group:FlxSpriteGroup = groupOf(role);
			if (group == null)
				continue;
			var info:Dynamic = roleData(role);
			var scroll:Array<Float> = DaveCharacters.pair(info != null ? info.scroll : null, [1, 1]);
			group.scrollFactor.set(scroll[0], scroll[1]);
			groupZ.set(group, (info != null && info.zIndex != null) ? Std.int(info.zIndex) : 0);
			entries.push({z: zOf(group), object: group});
		}
		// con el mismo zIndex: los props en el orden en que se agregaron y después los personajes
		ArraySort.sort(entries, function(a, b) return a.z - b.z);
		for (entry in entries)
			if (game.members.indexOf(entry.object) < 0)
				game.add(entry.object);
		built = true;
	}

	/** Stage.refresh de Dave: ordena por zIndex lo del escenario sin mover lo demás del PlayState. */
	public function refresh():Void
	{
		if (playState == null || !built)
			return;
		var members:Array<FlxBasic> = playState.members;
		var slots:Array<Int> = [];
		var objects:Array<FlxBasic> = [];
		for (i in 0...members.length)
		{
			var member:FlxBasic = members[i];
			if (member != null && isStageObject(member))
			{
				slots.push(i);
				objects.push(member);
			}
		}
		ArraySort.sort(objects, function(a, b) return zOf(a) - zOf(b));
		for (i in 0...slots.length)
			members[slots[i]] = objects[i];
	}

	function isStageObject(object:FlxBasic):Bool
		return props.contains(object) || groupZ.exists(object);

	public function zOf(object:FlxBasic):Int
		return groupZ.exists(object) ? groupZ.get(object) : VSliceAdapter.getZIndex(object);

	function groupOf(role:String):FlxSpriteGroup
	{
		if (playState == null)
			return null;
		return switch (role)
		{
			case 'bf': playState.boyfriendGroup;
			case 'dad': playState.dadGroup;
			case 'gf': playState.gfGroup;
			default: null;
		}
	}

	/** Un personaje del juego por su lugar ('bf', 'dad', 'gf') o por su id ('dave'). */
	public function getCharacter(id:String):Character
	{
		if (playState == null || id == null)
			return null;
		switch (id)
		{
			case 'bf' | 'boyfriend' | 'player':
				return playState.boyfriend;
			case 'dad' | 'opponent':
				return playState.dad;
			case 'gf' | 'girlfriend':
				return playState.gf;
			default:
		}
		for (char in characters())
			if (char.curCharacter == id)
				return char;
		return null;
	}

	/** Los personajes del juego con script de Dave (para mandarles los eventos). */
	public function characters():Array<Character>
	{
		var list:Array<Character> = [];
		if (playState == null)
			return list;
		for (char in [playState.gf, playState.dad, playState.boyfriend])
			if (char != null && !list.contains(char))
				list.push(char);
		for (char in extraCharacters)
			if (char != null && char.exists && !list.contains(char))
				list.push(char);
		return list;
	}

	/** El alpha del grupo de Dave: los props y los personajes cambian en proporción. */
	public function scaleAlpha(from:Float, to:Float):Void
	{
		var objects:Array<FlxBasic> = props.copy();
		for (role in ['gf', 'dad', 'bf'])
			if (groupOf(role) != null)
				objects.push(groupOf(role));
		for (object in objects)
		{
			if (!Std.isOfType(object, FlxSprite))
				continue;
			var sprite:FlxSprite = cast object;
			sprite.alpha = from > 0 ? sprite.alpha * (to / from) : to;
		}
	}

	public function setVisible(value:Bool):Void
	{
		for (prop in props)
			if (prop != null)
				prop.visible = value;
		for (role in ['gf', 'dad', 'bf'])
			if (groupOf(role) != null)
				groupOf(role).visible = value;
	}

	// ----- Eventos -----

	/** Manda un evento de Dave al escenario y a los personajes de Dave (como el dispatchEvent de su PlayState). */
	public function dispatch(method:String, event:Dynamic, toCharacters:Bool = true):Void
	{
		if (script != null)
			DaveScripts.dispatch(script, method, event);
		if (toCharacters)
			for (char in characters())
				if (char.daveScript != null)
					DaveScripts.dispatch(char.daveScript, method, event);
	}

	public function dispatchToCharacters(event:Dynamic):Void
	{
		var method:String = Std.isOfType(event, ScriptEvent) ? methodOf((cast event : ScriptEvent).type) : null;
		if (method == null)
			return;
		for (char in characters())
			if (char.daveScript != null)
				DaveScripts.dispatch(char.daveScript, method, event);
	}

	/** El nombre de la función de un tipo de evento de Dave ('beat_hit' -> 'onBeatHit'). */
	static function methodOf(type:String):String
	{
		if (type == null || type.length == 0)
			return null;
		var name:String = 'on';
		for (part in type.split('_'))
			if (part.length > 0)
				name += part.charAt(0).toUpperCase() + part.substr(1).toLowerCase();
		return name;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		elapsedTime += elapsed;
		if (script != null)
		{
			try
			{
				script.update(elapsed);
			}
			catch (e:Dynamic)
			{
				DaveScripts.report(script, e);
			}
		}
		dispatch('onUpdate', new UpdateScriptEvent(elapsed));
	}

	override function createPost():Void
	{
		dispatch('onCreatePost', new ScriptEvent('create_post'));
		dispatch('onCreateUI', new ScriptEvent('create_ui'));
	}

	override function stepHit():Void
		dispatch('onStepHit', new DaveConductorEvent('step_hit', curStep, curBeat, curSection));

	override function beatHit():Void
		dispatch('onBeatHit', new DaveConductorEvent('beat_hit', curStep, curBeat, curSection));

	override function sectionHit():Void
		dispatch('onMeasureHit', new DaveConductorEvent('measure_hit', curStep, curBeat, curSection));

	override function countdownTick(count:Countdown, num:Int):Void
	{
		if (num == 0)
			dispatch('onCountdownStart', new DaveCountdownEvent('countdown_start', DaveCountdownStep.START));
		var steps:Array<String> = [DaveCountdownStep.THREE, DaveCountdownStep.TWO, DaveCountdownStep.ONE, DaveCountdownStep.GO];
		if (num >= 0 && num < steps.length)
		{
			var event:DaveCountdownEvent = new DaveCountdownEvent('countdown_tick', steps[num]);
			dispatch('onCountdownTick', event);
			dispatch('onCountdownTickPost', event);
		}
		else
			dispatch('onCountdownFinish', new DaveCountdownEvent('countdown_end', DaveCountdownStep.FINISH));
	}

	override function startSong():Void
		dispatch('onSongStart', new ScriptEvent('song_start'));

	override function goodNoteHit(note:Note):Void
	{
		var char:Character = (note.gfNote && playState.gf != null) ? playState.gf : playState.boyfriend;
		dispatch('onPlayerNoteHit', new DaveNoteEvent('player_note_hit', note, char, note.hitHealth, playState.combo));
	}

	override function opponentNoteHit(note:Note):Void
	{
		var char:Character = (note.gfNote && playState.gf != null) ? playState.gf : playState.dad;
		dispatch('onOpponentNoteHit', new DaveNoteEvent('opponent_note_hit', note, char, 0, playState.combo));
	}

	override function noteMiss(note:Note):Void
	{
		var char:Character = (note.gfNote && playState.gf != null) ? playState.gf : playState.boyfriend;
		if (note.isSustainNote)
			dispatch('onHoldNoteDrop', new DaveHoldNoteEvent('note_hold_drop', note, char, -note.missHealth, playState.combo));
		else
			dispatch('onNoteMiss', new DaveNoteEvent('note_miss', note, char, -note.missHealth, playState.combo));
	}

	override function noteMissPress(direction:Int):Void
		dispatch('onGhostNoteMiss', new DaveGhostNoteEvent(direction, playState.boyfriend, -playState.pressMissDamage, playState.combo));

	override function openSubState(SubState:FlxSubState):Void
	{
		if (Std.isOfType(SubState, substates.GameOverSubstate))
			dispatch('onGameOver', new ScriptEvent('game_over'));
		else if (Std.isOfType(SubState, substates.PauseSubState))
		{
			pausedByMenu = true;
			dispatch('onPause', new ScriptEvent('pause'));
		}
	}

	override function closeSubState():Void
	{
		if (pausedByMenu)
		{
			pausedByMenu = false;
			dispatch('onResume', new ScriptEvent('resume'));
		}
	}

	override function destroy():Void
	{
		dispatch('onDestroy', new ScriptEvent('destroy'));
		if (current == this)
			current = null;
		gfOverride = null;
		super.destroy();
	}
}
#end
