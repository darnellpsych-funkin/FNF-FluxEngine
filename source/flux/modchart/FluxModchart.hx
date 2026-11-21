package flux.modchart;

#if MODCHARTS_ALLOWED
import modchart.Config;
import modchart.Manager;
import modchart.engine.events.Event;
import states.PlayState;

/**
 * Modcharts con FunkinModchart 1.2.5 (TheoDevelops, licencia Apache 2.0,
 * incluido en source/flux/vendor/funkinmodchart): efectos estilo NotITG en las
 * flechas (drunk, tipsy, rotate, reverse...), con eventos por beat.
 *
 * Desde los scripts de Flux (.hxs, .luau, .ss...): `startModchart()` devuelve el
 * Manager de FunkinModchart (`modchart.Manager`) y se usa directo.
 * Desde Lua: las funciones de `implement` (ver la tabla del README).
 */
class FluxModchart
{
	/** El modchart de la canción actual, o null si todavía no se creó. */
	public static function current():Manager
	{
		var game:PlayState = PlayState.instance;
		var manager:Manager = Manager.instance;
		if (game == null || manager == null || !game.members.contains(manager))
			return null;
		return manager;
	}

	/** Crea el modchart de la canción (una sola vez), en la capa de las notas. */
	public static function start():Manager
	{
		var manager:Manager = current();
		if (manager != null)
			return manager;
		var game:PlayState = PlayState.instance;
		if (game == null)
			throw 'los modcharts solo funcionan en una canción';
		// FunkinModchart necesita las flechas: se crean al empezar la cuenta regresiva
		if (game.strumLineNotes == null || game.strumLineNotes.length == 0)
			throw 'las flechas todavía no existen: usa el modchart en onCreatePost (o en onCountdownStarted si la canción empieza con un diálogo)';
		manager = new Manager();
		var index:Int = game.noteGroup != null ? game.members.indexOf(game.noteGroup) : -1;
		if (index >= 0) game.insert(index + 1, manager); // justo arriba de las notas, debajo de lo que agreguen los scripts
		else game.add(manager);
		return manager;
	}

	/** Cambia una opción de modchart.Config (por ejemplo RENDER_ARROW_PATHS o HOLDS_BEHIND_STRUM). */
	public static function setConfig(name:String, value:Dynamic):Void
	{
		if (!Reflect.hasField(Config, name) && Reflect.getProperty(Config, name) == null)
			throw 'no existe la opción de modchart "$name"';
		Reflect.setProperty(Config, name, value);
	}

	#if LUA_ALLOWED
	/** Funciones de Lua (las llama FunkinLua al crear cada script). */
	public static function implement(funk:psychlua.FunkinLua):Void
	{
		funk.addLocalCallback('startModchart', function() {
			start();
			return true;
		});
		funk.addLocalCallback('addModifier', function(name:String, ?field:Int = -1) {
			start().addModifier(name, field);
		});
		funk.addLocalCallback('setPercent', function(name:String, value:Float, ?player:Int = -1, ?field:Int = -1) {
			start().setPercent(name, value, player, field);
		});
		funk.addLocalCallback('getPercent', function(name:String, ?player:Int = 0, ?field:Int = 0) {
			return start().getPercent(name, player, field);
		});
		funk.addLocalCallback('setModifier', function(name:String, beat:Float, value:Float, ?player:Int = -1, ?field:Int = -1) {
			start().set(name, beat, value, player, field);
		});
		funk.addLocalCallback('easeModifier', function(name:String, beat:Float, length:Float, value:Float, ?ease:String = 'linear', ?player:Int = -1, ?field:Int = -1) {
			start().ease(name, beat, length, value, psychlua.LuaUtils.getTweenEaseByString(ease), player, field);
		});
		funk.addLocalCallback('addEaseModifier', function(name:String, beat:Float, length:Float, value:Float, ?ease:String = 'linear', ?player:Int = -1, ?field:Int = -1) {
			start().add(name, beat, length, value, psychlua.LuaUtils.getTweenEaseByString(ease), player, field);
		});
		funk.addLocalCallback('setAddModifier', function(name:String, beat:Float, value:Float, ?player:Int = -1, ?field:Int = -1) {
			start().setAdd(name, beat, value, player, field);
		});
		// funciones de Lua por nombre, como los callbacks de los tweens de Psych
		funk.addLocalCallback('modchartCallback', function(beat:Float, funcName:String, ?field:Int = -1) {
			start().callback(beat, function(event:Event) callLua(funk, funcName, event), field);
		});
		funk.addLocalCallback('modchartRepeater', function(beat:Float, length:Float, funcName:String, ?field:Int = -1) {
			start().repeater(beat, length, function(event:Event) callLua(funk, funcName, event), field);
		});
		funk.addLocalCallback('aliasModifier', function(name:String, alias:String, ?field:Int = -1) {
			start().alias(name, alias, field);
		});
		funk.addLocalCallback('addPlayfield', function() {
			start().addPlayfield();
			return start().playfields.length - 1;
		});
		funk.addLocalCallback('setModchartConfig', function(name:String, value:Dynamic) {
			setConfig(name, value);
		});
	}

	static function callLua(funk:psychlua.FunkinLua, funcName:String, event:Event):Void
	{
		if (funk == null || funk.closed)
			return;
		var game:PlayState = PlayState.instance;
		@:privateAccess funk.call(funcName, [game != null ? game.curDecBeat : event.beat]);
	}
	#end
}
#end
