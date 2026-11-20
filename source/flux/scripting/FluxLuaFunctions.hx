package flux.scripting;

#if (LUA_ALLOWED && FLUX_SCRIPTS_ALLOWED)
import psychlua.FunkinLua;
import psychlua.LuaUtils;

using StringTools;

/**
 * Funciones de Lua para usar los lenguajes de Flux Engine desde un .lua.
 *
 * Ejecutar código (cada script Lua tiene su propio intérprete por lenguaje,
 * así las variables y funciones se mantienen entre llamadas):
 *   runRuleScript(codigo, ?funcion, ?argumentos)
 *   runNXScript(codigo, ?funcion, ?argumentos)
 *   runHScriptPlus(codigo, ?funcion, ?argumentos)
 *   runHScriptImproved(codigo, ?funcion, ?argumentos)
 *   runFluxFunction(lenguaje, funcion, ?argumentos)   -- lenguaje: "rulescript", "nxscript", "hscriptplus" o "hxs"
 *
 * Scripts de archivo (.rhx, .nx, .nxs, .hsp, .hxs):
 *   addFluxScript(archivo, ?ignorarSiYaCorre)
 *   removeFluxScript(archivo)
 *   isFluxScriptRunning(archivo)
 *   getRunningFluxScripts()
 *   callFluxScript(archivo, funcion, ?argumentos)
 *   getFluxScriptVar(archivo, variable)
 *   setFluxScriptVar(archivo, variable, valor)
 *   callOnFluxScripts(funcion, ?argumentos, ?ignorarStops, ?excluirScripts, ?excluirValores)
 *   setOnFluxScripts(variable, valor, ?excluirScripts)
 *
 * Ejemplo en Lua:
 *   function onCreatePost()
 *       runRuleScript([[
 *           function saludar(nombre) return 'Hola ' + nombre + ' desde RuleScript';
 *       ]])
 *       debugPrint(runFluxFunction('rulescript', 'saludar', {'Juaquin'}))
 *       addFluxScript('scripts/bfInmortalSicks.rhx')
 *   end
 */
class FluxLuaFunctions
{
	/** Intérpretes creados con runRuleScript/runNXScript/runHScriptPlus (clave: scriptLua|extensión) */
	static var codeScripts:Map<String, FluxScript> = new Map();

	public static function implement(funk:FunkinLua)
	{
		// ---------------- Ejecutar código de otros lenguajes ----------------
		#if RULESCRIPT_ALLOWED
		funk.addLocalCallback("runRuleScript", function(code:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null) {
			return runCode(funk, '.rhx', code, funcToRun, funcArgs);
		});
		#end
		#if NXSCRIPT_ALLOWED
		funk.addLocalCallback("runNXScript", function(code:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null) {
			return runCode(funk, '.nx', code, funcToRun, funcArgs);
		});
		#end
		#if HSCRIPT_PLUS_ALLOWED
		funk.addLocalCallback("runHScriptPlus", function(code:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null) {
			return runCode(funk, '.hsp', code, funcToRun, funcArgs);
		});
		#end
		#if HSCRIPT_IMPROVED_ALLOWED
		funk.addLocalCallback("runHScriptImproved", function(code:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null) {
			return runCode(funk, '.hxs', code, funcToRun, funcArgs);
		});
		#end
		funk.addLocalCallback("runFluxFunction", function(language:String, funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			var ext:String = extensionOf(language);
			var script:FluxScript = ext != null ? codeScripts.get(keyOf(funk, ext)) : null;
			if (script == null)
			{
				FunkinLua.luaTrace('runFluxFunction: primero usa run${languageName(ext)} para crear el script ($language)', false, false, FlxColor.RED);
				return null;
			}
			return toLua(script.call(funcToRun, funcArgs));
		});

		// ---------------- Scripts de archivo ----------------
		funk.addLocalCallback("addFluxScript", function(scriptFile:String, ?ignoreAlreadyRunning:Bool = false) {
			var game:PlayState = PlayState.instance;
			var path:String = findScriptFile(scriptFile);
			if (path == null || game == null)
			{
				FunkinLua.luaTrace('addFluxScript: el script "$scriptFile" no existe', false, false, FlxColor.RED);
				return false;
			}
			if (!ignoreAlreadyRunning && findRunning(scriptFile) != null)
			{
				FunkinLua.luaTrace('addFluxScript: el script "$path" ya está corriendo');
				return false;
			}
			return game.initFluxScript(path);
		});
		funk.addLocalCallback("removeFluxScript", function(scriptFile:String) {
			var game:PlayState = PlayState.instance;
			var script:FluxScript = findRunning(scriptFile);
			if (script == null || game == null)
			{
				FunkinLua.luaTrace('removeFluxScript: el script "$scriptFile" no está corriendo', false, false, FlxColor.RED);
				return false;
			}
			script.call('onDestroy');
			script.destroy(); // queda inactivo y se saca de la lista en la próxima llamada
			return true;
		});
		funk.addLocalCallback("isFluxScriptRunning", function(scriptFile:String) {
			return findRunning(scriptFile) != null;
		});
		funk.addLocalCallback("getRunningFluxScripts", function() {
			var game:PlayState = PlayState.instance;
			var list:Array<String> = [];
			if (game != null && game.fluxScriptArray != null)
				for (script in game.fluxScriptArray)
					if (script != null && script.active) list.push(script.origin);
			return list;
		});
		funk.addLocalCallback("callFluxScript", function(scriptFile:String, funcName:String, ?args:Array<Dynamic> = null) {
			var script:FluxScript = findRunning(scriptFile);
			if (script == null)
			{
				FunkinLua.luaTrace('callFluxScript: el script "$scriptFile" no está corriendo', false, false, FlxColor.RED);
				return null;
			}
			return toLua(script.call(funcName, args));
		});
		funk.addLocalCallback("getFluxScriptVar", function(scriptFile:String, varName:String) {
			var script:FluxScript = findRunning(scriptFile);
			return script != null ? toLua(script.get(varName)) : null;
		});
		funk.addLocalCallback("setFluxScriptVar", function(scriptFile:String, varName:String, value:Dynamic) {
			var script:FluxScript = findRunning(scriptFile);
			if (script == null) return false;
			script.set(varName, value);
			return true;
		});
		funk.addLocalCallback("callOnFluxScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops:Bool = false, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			var game:PlayState = PlayState.instance;
			return game != null ? toLua(game.callOnFluxScripts(funcName, args, ignoreStops, excludeScripts, excludeValues)) : null;
		});
		funk.addLocalCallback("setOnFluxScripts", function(varName:String, value:Dynamic, ?exclusions:Array<String> = null) {
			var game:PlayState = PlayState.instance;
			if (game != null) game.setOnFluxScripts(varName, value, exclusions);
		});
	}

	/** Se llama al cerrar el PlayState */
	public static function destroyAll()
	{
		for (script in codeScripts)
			if (script != null) script.destroy();
		codeScripts.clear();
	}

	static function runCode(funk:FunkinLua, ext:String, code:String, ?funcToRun:String, ?funcArgs:Array<Dynamic>):Dynamic
	{
		var key:String = keyOf(funk, ext);
		var script:FluxScript = codeScripts.get(key);

		if (script == null || !script.active)
		{
			var vars:Map<String, Dynamic> = ['parentLua' => funk];
			script = FluxScriptHandler.createFromCode('${funk.scriptName} (${languageName(ext)})', ext, code, funk.modFolder, vars);
			if (script == null) return null; // el error ya se mostró en pantalla
			codeScripts.set(key, script);
		}
		else if (code != null && code.trim().length > 0)
		{
			if (!script.executeCode(code)) return null;
		}

		if (funcToRun != null && funcToRun.length > 0)
			return toLua(script.call(funcToRun, funcArgs));
		return toLua(script.returnValue);
	}

	static inline function keyOf(funk:FunkinLua, ext:String):String
		return funk.scriptName + '|' + ext;

	static function extensionOf(language:String):String
	{
		if (language == null) return null;
		return switch (language.toLowerCase().replace('-', '').replace(' ', '').replace('.', ''))
		{
			case 'rulescript' | 'rule' | 'rhx': '.rhx';
			case 'nxscript' | 'nx' | 'nxs': '.nx';
			case 'hscriptplus' | 'hsplus' | 'hsp': '.hsp';
			case 'hscriptimproved' | 'hsimproved' | 'improved' | 'hxs': '.hxs';
			default: null;
		}
	}

	static function languageName(ext:String):String
	{
		return switch (ext)
		{
			case '.rhx': 'RuleScript';
			case '.nx': 'NXScript';
			case '.hsp': 'HScriptPlus';
			case '.hxs': 'HScriptImproved';
			default: '?';
		}
	}

	/** Solo devuelve a Lua valores que Lua entiende (igual que runHaxeCode) */
	static function toLua(value:Dynamic):Dynamic
		return LuaUtils.isLuaSupported(value) ? value : null;

	/** Busca un archivo de script; si no tiene extensión prueba todas las de Flux (.rhx, .nx, .nxs, .hsp, .hxs) */
	static function findScriptFile(scriptFile:String):String
	{
		if (scriptFile == null) return null;
		var candidates:Array<String> = [scriptFile];
		if (!FluxScriptHandler.isSupported(scriptFile))
			candidates = [for (ext in FluxScriptHandler.getExtensions()) scriptFile + ext];

		for (file in candidates)
		{
			var path:String = Paths.getPath(file, TEXT);
			if (FileSystem.exists(path)) return path;
			if (FileSystem.exists(file)) return file;
		}
		return null;
	}

	/** Busca un script que ya esté corriendo, por ruta completa o por el final de la ruta */
	static function findRunning(scriptFile:String):FluxScript
	{
		var game:PlayState = PlayState.instance;
		if (scriptFile == null || game == null || game.fluxScriptArray == null) return null;

		var wanted:String = scriptFile.replace('\\', '/');
		var path:String = findScriptFile(scriptFile);
		if (path != null) path = path.replace('\\', '/');

		for (script in game.fluxScriptArray)
		{
			if (script == null || !script.active || script.origin == null) continue;
			var origin:String = script.origin.replace('\\', '/');
			if (origin == path || origin == wanted || origin.endsWith('/' + wanted)) return script;
			if (!FluxScriptHandler.isSupported(wanted))
				for (ext in FluxScriptHandler.getExtensions())
					if (origin.endsWith('/' + wanted + ext) || origin == wanted + ext) return script;
		}
		return null;
	}
}
#end
