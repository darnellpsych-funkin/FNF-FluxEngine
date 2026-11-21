package flux.scripting.luau;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;

/**
 * Le agrega a FluxLuau el `@:buildXml` que compila Luau dentro del juego.
 *
 * hxcpp necesita la ruta absoluta de `source/flux/vendor/luau/`, así que se
 * calcula acá (igual que hacen las librerías linc) y se le pasa a `luau.xml`
 * con la variable FLUX_LUAU_PATH.
 */
class LuauBuild
{
	public static function inject():Array<Field>
	{
		var xmlFile:String = Context.resolvePath('flux/vendor/luau/luau.xml');
		var dir:String = Path.addTrailingSlash(Path.normalize(Path.directory(sys.FileSystem.fullPath(xmlFile))));
		var xml:String = "<set name=\"FLUX_LUAU_PATH\" value=\"" + dir + "\" />\n<include name=\"$" + "{FLUX_LUAU_PATH}luau.xml\" />";

		var cls = Context.getLocalClass().get();
		cls.meta.add(':buildXml', [macro $v{xml}], cls.pos);
		return null;
	}
}
#end
