package flux.scripting;

#if FLUX_ZS
import psychlua.FunkinLua;
import zsscript.ZSTranspiler;

/**
 * Scripts `.zs` de ZS Engine (el lenguaje "natural" de SuperHero2010, ej. `onBeatHit:`,
 * `trigger event 'Hey!' with value 'BF'`). Su transpilador (source/flux/vendor/zsscript)
 * los pasa a Lua y Flux los corre como un script de Lua de Psych: tienen las mismas
 * funciones y callbacks, y se cargan en los mismos lugares que los .lua.
 */
class FluxZS
{
	public static inline function isZS(file:String):Bool
		return file != null && file.toLowerCase().endsWith('.zs');

	/** El Lua de un .zs, o null si tiene errores (salen en la consola y en la pantalla). */
	public static function transpile(path:String):String
	{
		var code:String = null;
		try
		{
			code = File.getContent(path);
		}
		catch (e:Dynamic)
		{
			report(path, 'no se pudo leer: $e');
			return null;
		}

		var lua:Null<String> = null;
		try
		{
			lua = ZSTranspiler.transpile(code);
		}
		catch (e:Dynamic)
		{
			report(path, Std.string(e));
			return null;
		}
		if (lua == null)
		{
			for (error in ZSTranspiler.errors)
				report(path, error);
			if (ZSTranspiler.errors.length == 0)
				report(path, 'no se pudo pasar a Lua');
		}
		return lua;
	}

	/** Corre un .zs como script de Lua (si no está corriendo ya). */
	public static function start(path:String):FunkinLua
	{
		var game:PlayState = PlayState.instance;
		if (game != null && game.luaArray != null)
			for (script in game.luaArray)
				if (script != null && script.scriptName == path)
					return null;

		var lua:String = transpile(path);
		if (lua == null)
			return null;
		return new FunkinLua(path, lua);
	}

	/** Como PlayState.startLuasNamed, pero con el .zs (del mod o de assets/shared). */
	public static function startNamed(file:String):Bool
	{
		var path:String = null;
		#if MODS_ALLOWED
		path = Paths.modFolders(file);
		if (!FileSystem.exists(path))
		#end
		path = Paths.getSharedPath(file);
		return FileSystem.exists(path) && start(path) != null;
	}

	static function report(path:String, message:String):Void
	{
		var text:String = '[ZS] $path: $message';
		trace(text);
		if (PlayState.instance != null)
			PlayState.instance.addTextToDebug(text, FlxColor.RED);
	}
}
#end
