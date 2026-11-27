package flux.codename;

#if FLUX_CODENAME
import haxe.xml.Access;

/**
 * Flux Engine: compatibilidad con mods de Codename Engine.
 *
 * Fase 1 (datos): personajes (data/characters/*.xml), escenarios (data/stages/*.xml),
 * semanas (data/weeks/weeks/*.xml) y los eventos de los charts (también songs/<canción>/events.json).
 * Los charts y el audio los lee Moonchart (ver FluxMoonchart).
 */
class FluxCodename
{
	/** Ruta de un archivo de mod (mod actual, globales y mods/), o null si no existe. */
	public static function find(key:String):String
	{
		var path:String = Paths.modFolders(key);
		return (path != null && FileSystem.exists(path)) ? path : null;
	}

	/** El XML de un mod ya leído (el primer elemento), o null. */
	public static function readXml(key:String):Access
	{
		var path:String = find(key);
		if (path == null) return null;
		try
		{
			return CodenameData.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			trace('[Flux Codename] No se pudo leer $path: $e');
			return null;
		}
	}
}
#end
