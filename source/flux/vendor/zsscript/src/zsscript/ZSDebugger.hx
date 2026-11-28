package zsscript;

/**
 * Flux Engine: reemplaza a debug.ZSDebugger de ZS Engine. Con `enabled` en true,
 * el transpilador muestra cada línea en la consola.
 */
class ZSDebugger
{
	public static var enabled:Bool = false;

	public static function log(text:String):Void
		if (enabled) trace('[ZS] $text');

	public static function logError(text:String):Void
		trace('[ZS] $text');

	public static function logTranspiler(text:String):Void
		if (enabled) trace('[ZS] $text');
}
