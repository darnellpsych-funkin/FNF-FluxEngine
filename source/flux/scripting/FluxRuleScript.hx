package flux.scripting;

#if RULESCRIPT_ALLOWED
import rulescript.RuleScript;
import rulescript.parsers.HxParser;
import hscript.Expr;

/**
 * Soporte de RuleScript (.rhx) para Flux Engine.
 * Librería: https://github.com/Kriptel/RuleScript
 *
 * RuleScript es HScript con extras: import con alias, using, propiedades
 * (get/set), interpolación de strings, `??` / `??=`, ...rest y clases en script.
 *
 * Ejemplo (mods/MiMod/scripts/hola.rhx):
 *
 *   import flixel.FlxSprite;
 *   import flixel.tweens.FlxTween as Tw;
 *
 *   var bg:FlxSprite;
 *   function onCreatePost() {
 *       bg = new FlxSprite().makeGraphic(200, 200, FlxColor.RED);
 *       add(bg);                      // "add" es de PlayState, no hace falta game.add
 *       Tw.tween(bg, {alpha: 0}, 2);
 *       trace('Canción: ${PlayState.SONG.song}');
 *   }
 *
 * El estado actual (PlayState) es el "superInstance" del script, así que sus
 * campos (boyfriend, dad, camGame, health...) se pueden usar directo.
 */
class FluxRuleScript extends FluxScript
{
	public var script:RuleScript;

	public function new(origin:String, code:String, ?parentInstance:Dynamic)
	{
		super(origin, code);
		language = 'RuleScript';

		script = new RuleScript();
		script.scriptName = origin;
		script.getParser(HxParser).allowAll();
		if (parentInstance != null)
			script.superInstance = parentInstance;
	}

	override public function execute():Bool
	{
		if (!active || code == null) return false;
		try
		{
			var expr:Expr = script.parser.parse(code);
			makeTopLevelGlobal(expr);
			returnValue = script.execute(expr);
			return true;
		}
		catch (e:haxe.Exception)
		{
			error('Error al cargar: ${e.message}');
			return false;
		}
		catch (e:Dynamic)
		{
			error('Error al cargar: $e');
			return false;
		}
	}

	override public function exists(name:String):Bool
	{
		if (script == null || name == null) return false;
		var v:Dynamic = script.variables.get(name);
		return v != null && Reflect.isFunction(v);
	}

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active || script == null) return null;
		var fn:Dynamic = script.variables.get(name);
		if (fn == null || !Reflect.isFunction(fn)) return null;

		try
		{
			return Reflect.callMethod(null, fn, args ?? []);
		}
		catch (e:haxe.Exception)
		{
			error('Error en $name: ${e.message}');
		}
		catch (e:Dynamic)
		{
			error('Error en $name: $e');
		}
		return null;
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (script != null)
			script.variables.set(name, value);
	}

	override public function get(name:String):Dynamic
		return script != null ? script.variables.get(name) : null;

	/**
	 * Las `var` del nivel superior quedan como variables globales del script
	 * (igual que en HScript de Psych), así get()/set() y otros scripts las ven.
	 */
	static function makeTopLevelGlobal(e:Expr):Void
	{
		if (e == null) return;
		#if hscriptPos
		switch (e.e)
		{
			case EBlock(list):
				for (item in list) makeTopLevelGlobal(item);
			case EVar(n, t, v, _):
				e.e = EVar(n, t, v, true);
			case EProp(n, g, s, t, v, _):
				e.e = EProp(n, g, s, t, v, true);
			default:
		}
		#else
		switch (e)
		{
			case EBlock(list):
				for (i in 0...list.length)
					switch (list[i])
					{
						case EVar(n, t, v, _): list[i] = EVar(n, t, v, true);
						case EProp(n, g, s, t, v, _): list[i] = EProp(n, g, s, t, v, true);
						default:
					}
			default:
		}
		#end
	}

	override public function destroy():Void
	{
		super.destroy();
		if (script != null)
			script.superInstance = null;
		script = null;
	}
}
#end
