package flux.scripting;

/**
 * Base común para los lenguajes extra de Flux Engine (NXScript, RuleScript...).
 *
 * Flujo de vida:
 *   1. `new FluxXScript(path, code)`  -> crea el intérprete, NO ejecuta todavía
 *   2. `set(...)`                      -> el handler mete el preset (game, FlxG, etc.)
 *   3. `execute()`                     -> corre el cuerpo del script
 *   4. `call("onCreate")`, `call("onUpdate", [elapsed])`...
 *   5. `destroy()`
 *
 * Esta clase no depende de Flixel a propósito, así se puede probar sola.
 */
class FluxScript
{
	/** Se llama cuando un script falla. El handler lo conecta al texto de debug de PlayState. */
	public static var onError:(script:FluxScript, message:String) -> Void = function(script, message) {
		trace('[${script.language}] ${script.origin}: $message');
	};

	/** Ruta del archivo (se usa para exclusiones, igual que HScript.origin) */
	public var origin:String;

	/** Carpeta del mod si el script está dentro de mods/<Mod>/ */
	public var modFolder:String;

	/** "NXScript", "RuleScript"... */
	public var language(default, null):String = 'FluxScript';

	/** Código fuente original */
	public var code(default, null):String;

	/** false después de destroy() o si el script pidió cerrarse */
	public var active:Bool = true;

	/** Lo que devolvió el cuerpo del script al ejecutarse */
	public var returnValue:Dynamic = null;

	public function new(origin:String, code:String)
	{
		this.origin = origin;
		this.code = code;
	}

	/** Ejecuta el cuerpo del script. Devuelve false si hubo error. */
	public function execute():Bool
		return false;

	/** ¿Existe una función con ese nombre en el script? */
	public function exists(name:String):Bool
		return false;

	/** Llama una función del script. Devuelve null si no existe o falla. */
	public function call(name:String, ?args:Array<Dynamic>):Dynamic
		return null;

	/** Define una variable global dentro del script */
	public function set(name:String, value:Dynamic):Void {}

	/** Lee una variable global del script */
	public function get(name:String):Dynamic
		return null;

	public function destroy():Void
	{
		active = false;
		code = null;
	}

	function error(message:String):Void
	{
		if (onError != null)
			onError(this, message);
	}
}
