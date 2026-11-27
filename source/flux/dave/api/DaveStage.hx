package flux.dave.api;

#if FLUX_DAVE_SCRIPTS
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flux.dave.FluxDaveStage;
import flux.dave.api.DaveApi;
import objects.Character;

/**
 * El `Stage` de Dave Engine para los scripts de escenarios
 * (scripts/stages/<id>.hxc: `class X extends Stage`, con `super('house')`).
 *
 * En Dave el escenario es un grupo con los props y los personajes ordenados por
 * zIndex. En Flux los props van al PlayState y FluxDaveStage los ordena con los
 * grupos de los personajes. Los scripts usan add(), getProp(), load(), onBeatHit()...
 */
@:keep
class DaveStage
{
	/** El color de los escenarios de noche (Stage.nightColor). */
	public static var nightColor(default, null):FlxColor = 0xFF51557A;

	/** El color de los escenarios al atardecer (Stage.sunsetColor). */
	public static var sunsetColor(default, null):FlxColor = 0xFFFF8FB2;

	/** El escenario del juego del script que se está creando (lo pone FluxDaveStage). */
	public static var pendingRuntime:FluxDaveStage = null;

	public var id(default, null):String;

	/** El JSON de Dave (data/stages/<id>.json). */
	public var _data:Dynamic;

	/** El escenario en el juego (props, personajes, eventos). */
	public var runtime(default, null):FluxDaveStage;

	/** La clase del .hxc (para los mensajes de error). */
	public var scriptClass:String = null;

	/** El intérprete del script (ver DaveCharacter.unsuper). */
	public var scriptInterp:rulescript.RuleScriptInterp = null;

	public var name(get, never):String;
	public var stageZoom(get, never):Float;
	public var members(get, never):Array<FlxBasic>;
	public var alpha(default, set):Float = 1;
	public var visible(default, set):Bool = true;

	public function new(id:String)
	{
		this.id = id;
		runtime = pendingRuntime;
		_data = runtime != null ? runtime.data : FluxDaveStage.readData(id);
	}

	inline function unsuper():Void
	{
		if (scriptInterp != null)
			scriptInterp.isSuperCall = false;
	}

	/** El script crea acá los props con add(). */
	public function load():Void {}

	/** Cada cuadro (como el update del grupo en Dave). */
	public function update(elapsed:Float):Void {}

	/** Agrega un prop (o lo que sea) al escenario; se ordena por zIndex con los personajes. */
	public function add(object:FlxBasic):FlxBasic
	{
		unsuper();
		if (runtime != null)
			runtime.addProp(object);
		return object;
	}

	public function insert(position:Int, object:FlxBasic):FlxBasic
		return add(object);

	public function remove(object:FlxBasic, splice:Bool = false):FlxBasic
	{
		if (runtime != null)
			runtime.removeProp(object);
		return object;
	}

	/** Un BGSprite del escenario por su nombre. */
	public function getProp(name:String):Dynamic
		return runtime != null ? runtime.namedProps.get(name) : null;

	/** Un personaje del escenario: por su id ('dave') o su lugar ('bf', 'dad', 'gf'). */
	public function getCharacter(id:String):Character
		return runtime != null ? runtime.getCharacter(id) : null;

	public function forEachProp(func:Dynamic->Void):Void
	{
		if (runtime == null || func == null)
			return;
		for (prop in runtime.props.copy())
			if (prop != null && !Std.isOfType(prop, Character))
				func(prop);
	}

	/** Ordena por zIndex. */
	public function refresh():Void
		if (runtime != null) runtime.refresh();

	/** Los datos del JSON para un tipo de personaje (PLAYER, OPPONENT o GF). */
	public function getCharacterStageData(type:String):Dynamic
		return runtime != null ? runtime.roleData(FluxDaveStage.roleOfType(type)) : null;

	/** Agrega un personaje del juego al escenario, en su lugar (y con sus globalOffset si reposition). */
	public function addCharacter(character:Character, ?type:String, ?id:String, ?position:FlxPoint, reposition:Bool = true):Void
	{
		unsuper();
		if (runtime != null)
			runtime.addCharacter(character, type, position, reposition);
	}

	public function dispatchToCharacters(event:Dynamic):Void
	{
		if (runtime != null && event != null)
			runtime.dispatchToCharacters(event);
	}

	function get_name():String
		return (_data != null && _data.name != null) ? Std.string(_data.name) : 'Unknown';

	function get_stageZoom():Float
		return _data != null ? DaveData.num(_data.zoom, 1) : 1;

	function get_members():Array<FlxBasic>
		return runtime != null ? runtime.props : [];

	/** Como el alpha de un FlxSpriteGroup: cambia a todos los props y personajes en proporción. */
	function set_alpha(value:Float):Float
	{
		value = Math.max(0, Math.min(1, value));
		if (runtime != null)
			runtime.scaleAlpha(alpha, value);
		return alpha = value;
	}

	function set_visible(value:Bool):Bool
	{
		if (runtime != null)
			runtime.setVisible(value);
		return visible = value;
	}

	public function toString():String
		return 'Stage(id = $id, name = $name)';

	// ----- Eventos (el script cambia los que usa) -----

	public function onAdd(event:Dynamic):Void {}

	public function onCharacterAdd(event:Dynamic):Void {}

	public function onScriptEvent(event:Dynamic):Void {}

	public function onScriptEventPost(event:Dynamic):Void {}

	public function onCreate(event:Dynamic):Void {}

	public function onUpdate(event:Dynamic):Void {}

	public function onDestroy(event:Dynamic):Void {}

	public function onPreferenceChanged(event:Dynamic):Void {}

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

	public function onNoteSpawn(event:Dynamic):Void {}

	public function onOpponentNoteHit(event:Dynamic):Void {}

	public function onPlayerNoteHit(event:Dynamic):Void {}

	public function onNoteMiss(event:Dynamic):Void {}

	public function onHoldNoteDrop(event:Dynamic):Void {}
}

/** Escenario de Dave cuyo código viene de un .hxc (ver FluxScriptedDaveCharacter). */
@:keep
class FluxScriptedDaveStage extends DaveStage implements rulescript.scriptedClass.RuleScriptedClass {}
#end
