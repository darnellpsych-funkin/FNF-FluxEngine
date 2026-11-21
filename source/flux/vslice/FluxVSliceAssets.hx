package flux.vslice;

#if FLUX_VSLICE
/**
 * Los mods de V-Slice guardan muchos archivos en "bibliotecas": `shared/` (personajes,
 * props de escenarios...) o la carpeta de un nivel (`week1/`...). Por ejemplo la
 * imagen "characters/Finn" puede estar en `mods/MiMod/shared/images/characters/Finn.png`.
 *
 * Psych solo busca en la raíz del mod, así que Paths.modFolders() y Paths.fileExists()
 * preguntan acá cuando no encuentran un archivo.
 */
class FluxVSliceAssets
{
	/** La ruta del archivo dentro de una biblioteca de V-Slice, o null si no está. */
	public static function find(key:String):String
	{
		#if MODS_ALLOWED
		if (key == null || key.length == 0)
			return null;

		var libraries:Array<String> = [];
		var level:String = Paths.currentLevel;
		if (level != null && level.length > 0 && level != 'shared')
			libraries.push(level);
		libraries.push('shared');

		for (mod in modsToCheck())
			for (library in libraries)
			{
				var path:String = Paths.mods('$mod/$library/$key');
				if (FileSystem.exists(path))
					return path;
			}
		#end
		return null;
	}

	/** Un archivo de datos (data/characters/x.json, data/stages/x.json...) del mod actual o los globales. */
	public static function findData(key:String):String
	{
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(key);
		if (FileSystem.exists(path))
			return path;
		#end
		return null;
	}

	public static function readJson(path:String):Dynamic
	{
		if (path == null || !FileSystem.exists(path))
			return null;
		try
		{
			return haxe.Json.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			trace('[Flux V-Slice] JSON inválido: $path ($e)');
			return null;
		}
	}

	static function modsToCheck():Array<String>
	{
		var list:Array<String> = [];
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			list.push(Mods.currentModDirectory);
		for (mod in Mods.getGlobalMods())
			if (!list.contains(mod))
				list.push(mod);
		return list;
	}
}
#end
