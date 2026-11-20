package flux.scripting;

#if HSCRIPT_IMPROVED_ALLOWED
import flux.vendor.hsimproved.Expr;
import flux.vendor.hsimproved.Interp;
import flux.vendor.hsimproved.Parser;
import flux.vendor.hsimproved.Printer;

using StringTools;

/**
 * HScript expandido (.hxs) con hscript-improved de Codename Engine.
 * Librería: https://github.com/CodenameCrew/hscript-improved (incluida en
 * source/flux/vendor/hsimproved con otro nombre de paquete, porque la de
 * haxelib usa el mismo paquete "hscript" que RuleScript).
 *
 * Además de todo lo de HScript tiene:
 *  - clases propias en el script (`class Enemigo { ... }`), herencia entre
 *    ellas, `static`, propiedades `(get, set)` y `is` con herencia;
 *  - `enum` con argumentos y `switch` sobre ellos;
 *  - `import`, `import ... as Alias`, `using StringTools;`, `final`, regex `~/.../`;
 *  - `static var` compartidas entre todos los .hxs (duran toda la partida).
 *
 * El estado actual (PlayState u otro) es el "scriptObject": sus campos
 * (boyfriend, health, camHUD...) se usan directo, sin `game.`.
 * Las clases y funciones extra que trae cada .hxs están en FluxHxsPreset.
 */
class FluxHScriptImproved extends FluxScript
{
	/** `static var` de todos los .hxs (las comparten y no se borran al cambiar de canción). */
	public static var staticVariables(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	public var interp(default, null):Interp;
	public var parser(default, null):Parser;

	public function new(origin:String, code:String, ?parentInstance:Dynamic)
	{
		super(origin, code);
		language = 'HScript Improved';

		parser = new Parser();
		parser.allowJSON = true;
		parser.allowTypes = true;
		parser.allowMetadata = true;
		parser.allowRegex = true;
		for (define in ['FLUX_ENGINE', 'PSYCH', #if desktop 'desktop', #end #if windows 'windows', #end #if linux 'linux', #end #if mac 'mac', #end
			#if mobile 'mobile', #end #if debug 'debug', #end #if LUA_ALLOWED 'LUA_ALLOWED', #end #if VIDEOS_ALLOWED 'VIDEOS_ALLOWED', #end])
			parser.preprocessorValues.set(define, true);

		interp = new Interp();
		interp.allowStaticVariables = true;
		interp.staticVariables = staticVariables;
		interp.errorHandler = function(e:Error) error(Printer.errorToString(e));
		interp.warnHandler = function(e:Error) FluxScript.onWarning(this, Printer.errorToString(e));
		interp.importFailedCallback = onImportFailed;
		if (parentInstance != null)
			interp.scriptObject = parentInstance;
	}

	override public function execute():Bool
	{
		if (!active || code == null)
			return false;
		try
		{
			var expr:Expr = parser.parseString(code, origin);
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
		return getFunction(name) != null;

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active || interp == null)
			return null;
		var fn:Dynamic = getFunction(name);
		if (fn == null)
			return null;
		try
		{
			return Reflect.callMethod(null, fn, args == null ? [] : args);
		}
		catch (e:Dynamic)
		{
			error('Error en $name: ' + errorText(e));
		}
		return null;
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (interp == null)
			return;
		interp.variables.set(name, value);
		@:privateAccess interp.varLocationCache.remove(name); // que la próxima lectura vea este valor
	}

	override public function get(name:String):Dynamic
	{
		if (interp == null)
			return null;
		if (interp.variables.exists(name))
			return interp.variables.get(name);
		return interp.publicVariables.get(name);
	}

	override public function setParentInstance(parent:Dynamic):Void
	{
		if (interp != null)
			interp.scriptObject = parent;
	}

	override public function destroy():Void
	{
		super.destroy();
		if (interp != null)
			interp.scriptObject = null;
		interp = null;
		parser = null;
	}

	function getFunction(name:String):Dynamic
	{
		if (interp == null || name == null)
			return null;
		var fn:Dynamic = interp.variables.get(name);
		if (fn == null)
			fn = interp.publicVariables.get(name);
		return (fn != null && Reflect.isFunction(fn)) ? fn : null;
	}

	/**
	 * `import` de algo que no existe: en vez de cortar el script, avisa y
	 * deja la variable en null. Algunas clases de Codename Engine tienen su
	 * equivalente en Psych (ver FluxHxsPreset.IMPORT_ALIASES).
	 */
	function onImportFailed(path:Array<String>, alias:Null<String>):Bool
	{
		var full:String = path.join('.');
		var name:String = alias != null ? alias : path[path.length - 1];
		var replacement:Dynamic = FluxHxsPreset.resolveImport(full);
		if (replacement != null)
		{
			interp.variables.set(name, replacement);
			return true;
		}
		FluxScript.onWarning(this, 'import: no existe "$full" (queda en null)');
		interp.variables.set(name, null);
		return true;
	}

	static function errorText(e:Dynamic):String
	{
		if (Std.isOfType(e, Error))
			return Printer.errorToString(e);
		return Std.string(e);
	}
}
#end
