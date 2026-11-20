package flux.scripting;

#if HSCRIPT_PLUS_ALLOWED
import flux.vendor.hsplus.Expr;
import flux.vendor.hsplus.plus.InterpPlus;
import flux.vendor.hsplus.plus.ParserPlus;

/**
 * Soporte de hscript-plus (.hsp) para Flux Engine.
 * Librería original: https://github.com/DleanJeans/hscript-plus (MIT, 2017).
 * Va incluida dentro de Flux en source/flux/vendor/hsplus con otro nombre de
 * paquete, para que no choque con el hscript que usa RuleScript.
 *
 * hscript-plus agrega clases con herencia hechas en el mismo script:
 *
 *   class Enemigo {
 *       var vida = 100;
 *       function new() {}
 *       function golpear(n) { vida -= n; }
 *   }
 *   class Jefe extends Enemigo {
 *       function rugir() { debugPrint("ROAR"); }
 *   }
 *
 * Es una versión vieja de hscript: no tiene "() -> {}", "?." ni "??".
 * Usa "function() {}" y "game." para las cosas del PlayState.
 */
class FluxHScriptPlus extends FluxScript
{
	public var interp:InterpPlus;
	var parser:ParserPlus;

	public function new(origin:String, code:String)
	{
		super(origin, code);
		language = 'hscript-plus';

		parser = new ParserPlus();
		parser.allowTypes = true;
		parser.allowJSON = true;
		interp = new InterpPlus();
	}

	override public function execute():Bool
	{
		if (!active || code == null) return false;
		try
		{
			var expr:Expr = parser.parseString(code, origin);
			makeTopLevelGlobal(expr);
			returnValue = interp.execute(expr);
			return true;
		}
		catch (e:Dynamic)
		{
			error('Error al cargar: ' + errorText(e));
			return false;
		}
	}

	override public function exists(name:String):Bool
	{
		if (interp == null || name == null) return false;
		var v:Dynamic = interp.variables.get(name);
		return v != null && Reflect.isFunction(v);
	}

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active || interp == null) return null;
		var fn:Dynamic = interp.variables.get(name);
		if (fn == null || !Reflect.isFunction(fn)) return null;

		try
		{
			return Reflect.callMethod(null, fn, args != null ? args : []);
		}
		catch (e:Dynamic)
		{
			error('Error en $name: ' + errorText(e));
		}
		return null;
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (interp != null)
			interp.variables.set(name, value);
	}

	override public function get(name:String):Dynamic
		return interp != null ? interp.variables.get(name) : null;

	override public function destroy():Void
	{
		super.destroy();
		interp = null;
		parser = null;
	}

	function errorText(e:Dynamic):String
	{
		#if hscriptPos
		if (Std.isOfType(e, flux.vendor.hsplus.Expr.Error))
		{
			var err:flux.vendor.hsplus.Expr.Error = cast e;
			return 'línea ${err.line}: ${err.e}';
		}
		#end
		return Std.string(e);
	}

	/**
	 * Las "var" del nivel superior pasan a ser variables globales del script
	 * (como en el HScript de Psych), así get()/set() y las funciones las ven.
	 */
	static function makeTopLevelGlobal(e:Expr):Void
	{
		if (e == null) return;
		#if hscriptPos
		switch (e.e)
		{
			case EBlock(list):
				for (i in 0...list.length)
					switch (list[i].e)
					{
						case EVar(n, _, v, _):
							var item = list[i];
							var value:Expr = v != null ? v : {e: EIdent('null'), pmin: item.pmin, pmax: item.pmax, origin: item.origin, line: item.line};
							var ident:Expr = {e: EIdent(n), pmin: item.pmin, pmax: item.pmax, origin: item.origin, line: item.line};
							item.e = EBinop('=', ident, value);
						default:
					}
			default:
		}
		#else
		switch (e)
		{
			case EBlock(list):
				for (i in 0...list.length)
					switch (list[i])
					{
						case EVar(n, _, v, _):
							list[i] = EBinop('=', EIdent(n), v != null ? v : EIdent('null'));
						default:
					}
			default:
		}
		#end
	}
}
#end
