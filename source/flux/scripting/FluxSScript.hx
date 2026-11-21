package flux.scripting;

#if SSCRIPT_ALLOWED
import hscript.SScript;

/**
 * Scripts `.ss`: SScript (SuperlativeScript) 24, fork de HScript
 * (incluido en source/flux/vendor/sscript, licencia Apache 2.0).
 *
 * En C++ SScript corre los scripts en su propia máquina virtual (SSVM) cuando
 * puede; si el script usa algo que la VM no soporta, usa el intérprete normal.
 * Los campos del estado (boyfriend, camHUD, add...) se usan directo.
 */
class FluxSScript extends FluxScript
{
	public var script(default, null):SScript;

	var ranOnce:Bool = false;

	public function new(origin:String, code:String, ?parent:Dynamic)
	{
		super(origin, code);
		language = 'SScript';

		script = new SScript(null, true, false);
		script.customOrigin = origin;
		script.defaultFunc = null; // Flux llama onCreate, no main()
		script.traceError = function(error:String, funcCalled:String, ?args:Array<Dynamic>) {
			FluxScript.onWarning(this, error);
		};
		setParentInstance(parent);
	}

	override public function execute():Bool
	{
		if (!active || script == null)
			return false;

		ranOnce = true;
		script.doString(code, origin);
		// un error en una función llamada desde Haxe (onUpdate, un tween, un timer...) se avisa, no cierra el juego
		@:privateAccess {
			if (script.vmBackend != null)
				script.vmBackend.onCallbackError = function(message:String) error(message);
			if (script.interp != null)
				script.interp.onCallbackError = function(message:String) error(message);
		}
		if (script.parsingException != null)
		{
			error(messageOf(script.parsingException));
			return false;
		}
		returnValue = script.returnValue;
		shareTopLevelVars();
		return true;
	}

	/** Las `var` de arriba de todo quedan como variables del script (para el código que se agregue después). */
	function shareTopLevelVars():Void
	{
		@:privateAccess {
			var interp = script.interp;
			if (interp == null || interp.locals == null)
				return;
			for (name => value in interp.locals)
				interp.variables.set(name, value);
		}
	}

	/**
	 * Más código en el mismo script (importScript, runSScript desde Lua...).
	 * doString de SScript borra la VM anterior y con ella las funciones que ya
	 * tenía el script, así que el código nuevo corre en el intérprete.
	 */
	override public function executeCode(newCode:String):Bool
	{
		if (!active || script == null || newCode == null)
			return false;
		if (!ranOnce)
		{
			code = newCode;
			return execute();
		}
		try
		{
			@:privateAccess {
				var expr = script.parser.parseString(newCode, origin);
				returnValue = script.interp.execute(expr);
			}
			shareTopLevelVars();
			return true;
		}
		catch (e:Dynamic)
		{
			error(messageOf(e));
			return false;
		}
	}

	override public function exists(name:String):Bool
	{
		if (!active || script == null || !script.exists(name))
			return false;
		return Reflect.isFunction(script.get(name));
	}

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!exists(name))
			return null;
		var result = script.call(name, args != null ? args : []);
		if (result == null)
			return null;
		if (!result.succeeded)
		{
			if (result.exceptions != null && result.exceptions.length > 0)
				error('$name: ' + messageOf(result.exceptions[0]));
			return null;
		}
		return result.returnValue;
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (script != null && active)
			script.set(name, value);
	}

	override public function get(name:String):Dynamic
	{
		if (script == null || !active)
			return null;
		return script.get(name);
	}

	override public function setParentInstance(parent:Dynamic):Void
	{
		if (script == null || !active)
			return;
		if (parent == null)
			script.removeSpecialObject();
		else
			script.setSpecialObject(parent, true);
	}

	override public function destroy():Void
	{
		if (script != null)
			script.destroy();
		script = null;
		super.destroy();
	}

	static function messageOf(e:Dynamic):String
	{
		if (e == null)
			return 'error';
		if (Std.isOfType(e, haxe.Exception))
			return (e : haxe.Exception).message;
		return Std.string(e);
	}
}
#end
