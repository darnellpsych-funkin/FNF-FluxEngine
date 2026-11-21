package flux.scripting;

#if FLUX_SCRIPTS_ALLOWED
import flixel.FlxBasic;
import psychlua.LuaUtils;
import psychlua.CustomSubstate;

using StringTools;

/**
 * Crea los scripts extra de Flux Engine según la extensión del archivo
 * y les pone las mismas variables/funciones que tiene un .hx de Psych.
 *
 *   .nx  / .nxs  -> NXScript     (define NXSCRIPT_ALLOWED)
 *   .rhx         -> RuleScript   (define RULESCRIPT_ALLOWED)
 *   .hsp         -> hscript-plus (define HSCRIPT_PLUS_ALLOWED)
 *   .hxs         -> hscript-improved de Codename, con preset expandido (define HSCRIPT_IMPROVED_ALLOWED)
 *   .luau        -> Luau, el Lua de Roblox, con el mismo preset que los .hxs (define LUAU_ALLOWED)
 */
class FluxScriptHandler
{
	public static var NX_EXTENSIONS(default, null):Array<String> = ['.nx', '.nxs'];
	public static var RULE_EXTENSIONS(default, null):Array<String> = ['.rhx'];
	public static var HSPLUS_EXTENSIONS(default, null):Array<String> = ['.hsp'];
	public static var HXS_EXTENSIONS(default, null):Array<String> = ['.hxs'];
	public static var LUAU_EXTENSIONS(default, null):Array<String> = ['.luau'];

	static var initialized:Bool = false;

	/** Extensiones activas en esta build */
	public static function getExtensions():Array<String>
	{
		var exts:Array<String> = [];
		#if NXSCRIPT_ALLOWED exts = exts.concat(NX_EXTENSIONS); #end
		#if RULESCRIPT_ALLOWED exts = exts.concat(RULE_EXTENSIONS); #end
		#if HSCRIPT_PLUS_ALLOWED exts = exts.concat(HSPLUS_EXTENSIONS); #end
		#if HSCRIPT_IMPROVED_ALLOWED exts = exts.concat(HXS_EXTENSIONS); #end
		#if LUAU_ALLOWED exts = exts.concat(LUAU_EXTENSIONS); #end
		return exts;
	}

	public static function isSupported(file:String):Bool
	{
		if (file == null) return false;
		var lower = file.toLowerCase();
		for (ext in getExtensions())
			if (lower.endsWith(ext)) return true;
		return false;
	}

	public static function init()
	{
		if (initialized) return;
		initialized = true;

		FluxScript.onError = function(script:FluxScript, message:String) {
			var text = '[${script.language}] ${script.origin}: $message';
			trace(text);
			if (PlayState.instance != null && FlxG.state == PlayState.instance)
				PlayState.instance.addTextToDebug(text, FlxColor.RED);
		};
		FluxScript.onWarning = function(script:FluxScript, message:String) {
			var text = '[${script.language}] ${script.origin}: $message';
			trace(text);
			if (PlayState.instance != null && FlxG.state == PlayState.instance)
				PlayState.instance.addTextToDebug(text, FlxColor.YELLOW);
		};

		#if LUAU_ALLOWED
		// require() e import() de los .luau buscan igual que los .hxs
		FluxLuau.fileResolver = FluxHxsPreset.findFile;
		FluxLuau.importResolver = FluxHxsPreset.resolveImport;
		#end

		#if (RULESCRIPT_ALLOWED && HSCRIPT_ALLOWED)
		// FlxColor es un abstract: "import flixel.util.FlxColor;" usa la versión de Psych
		var original = rulescript.Abstracts.resolveAbstract;
		rulescript.Abstracts.resolveAbstract = function(name:String):Class<Dynamic> {
			if (name == 'flixel.util.FlxColor') return cast psychlua.HScript.CustomFlxColor;
			return original(name);
		};
		#end
	}

	/**
	 * Lee el archivo, crea el script adecuado, le pone el preset y lo ejecuta.
	 * Devuelve null si la extensión no es soportada o el script falló al cargar.
	 */
	public static function create(path:String):FluxScript
	{
		if (path == null || !FileSystem.exists(path)) return null;

		var modFolder:String = null;
		#if MODS_ALLOWED
		var folders:Array<String> = path.replace('\\', '/').split('/');
		if (folders.length > 1 && folders[0] + '/' == Paths.mods()
			&& (Mods.currentModDirectory == folders[1] || Mods.getGlobalMods().contains(folders[1])))
			modFolder = folders[1];
		#end

		return createFromCode(path, path, File.getContent(path), modFolder);
	}

	/**
	 * Crea un script a partir de código. "extOrPath" decide el lenguaje
	 * (una extensión como ".rhx" o una ruta que termine en ella).
	 */
	public static function createFromCode(origin:String, extOrPath:String, code:String, ?modFolder:String, ?extraVars:Map<String, Dynamic>):FluxScript
	{
		init();
		var lower = extOrPath.toLowerCase();
		var script:FluxScript = null;

		#if NXSCRIPT_ALLOWED
		for (ext in NX_EXTENSIONS)
			if (lower.endsWith(ext)) script = new FluxNXScript(origin, code);
		#end
		#if RULESCRIPT_ALLOWED
		if (script == null)
			for (ext in RULE_EXTENSIONS)
				if (lower.endsWith(ext)) script = new FluxRuleScript(origin, code, FlxG.state);
		#end
		#if HSCRIPT_PLUS_ALLOWED
		if (script == null)
			for (ext in HSPLUS_EXTENSIONS)
				if (lower.endsWith(ext)) script = new FluxHScriptPlus(origin, code);
		#end
		#if HSCRIPT_IMPROVED_ALLOWED
		if (script == null)
			for (ext in HXS_EXTENSIONS)
				if (lower.endsWith(ext)) script = new FluxHScriptImproved(origin, code, FlxG.state);
		#end
		#if LUAU_ALLOWED
		if (script == null)
			for (ext in LUAU_EXTENSIONS)
				if (lower.endsWith(ext)) script = new FluxLuau(origin, code);
		#end

		if (script == null) return null;

		script.modFolder = modFolder;
		preset(script);
		#if HSCRIPT_IMPROVED_ALLOWED
		if (script is FluxHScriptImproved) FluxHxsPreset.apply(script);
		#end
		#if LUAU_ALLOWED
		if (script is FluxLuau) FluxHxsPreset.apply(script);
		#end
		if (extraVars != null)
			for (name => value in extraVars)
				script.set(name, value);

		if (!script.execute())
		{
			script.destroy();
			return null;
		}
		return script;
	}

	/** Las mismas clases y funciones que HScript.preset() de Psych */
	public static function preset(script:FluxScript)
	{
		// Clases
		script.set('Type', Type);
		script.set('Std', Std);
		script.set('Math', Math);
		script.set('StringTools', StringTools);
		#if sys
		script.set('File', File);
		script.set('FileSystem', FileSystem);
		#end
		script.set('FlxG', FlxG);
		script.set('FlxMath', FlxMath);
		script.set('FlxSprite', FlxSprite);
		script.set('FlxText', FlxText);
		script.set('FlxCamera', FlxCamera);
		script.set('PsychCamera', backend.PsychCamera);
		script.set('FlxTimer', FlxTimer);
		script.set('FlxTween', flixel.tweens.FlxTween);
		script.set('FlxEase', FlxEase);
		#if HSCRIPT_ALLOWED
		script.set('FlxColor', psychlua.HScript.CustomFlxColor);
		#end
		script.set('Countdown', backend.BaseStage.Countdown);
		script.set('PlayState', PlayState);
		script.set('Paths', Paths);
		script.set('Conductor', Conductor);
		script.set('ClientPrefs', ClientPrefs);
		#if ACHIEVEMENTS_ALLOWED
		script.set('Achievements', Achievements);
		#end
		script.set('Character', objects.Character);
		script.set('Alphabet', Alphabet);
		script.set('Note', objects.Note);
		script.set('CustomSubstate', CustomSubstate);
		#if (!flash && sys)
		script.set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		script.set('ErrorHandledRuntimeShader', shaders.ErrorHandledShader.ErrorHandledRuntimeShader);
		#end
		script.set('ShaderFilter', openfl.filters.ShaderFilter);
		#if flxanimate
		script.set('FlxAnimate', FlxAnimate);
		#end

		// Variables
		script.set('game', FlxG.state);
		script.set('controls', Controls.instance);
		script.set('scriptName', script.origin);
		script.set('scriptLanguage', script.language);
		script.set('modFolder', script.modFolder);
		script.set('buildTarget', LuaUtils.getBuildTarget());
		script.set('customSubstate', CustomSubstate.instance);
		script.set('customSubstateName', CustomSubstate.name);

		script.set('Function_Stop', LuaUtils.Function_Stop);
		script.set('Function_Continue', LuaUtils.Function_Continue);
		script.set('Function_StopLua', LuaUtils.Function_StopLua);
		script.set('Function_StopHScript', LuaUtils.Function_StopHScript);
		script.set('Function_StopAll', LuaUtils.Function_StopAll);

		// Funciones
		script.set('add', function(obj:FlxBasic) return FlxG.state.add(obj));
		script.set('insert', function(pos:Int, obj:FlxBasic) return FlxG.state.insert(pos, obj));
		script.set('remove', function(obj:FlxBasic, ?splice:Bool = false) return FlxG.state.remove(obj, splice));

		script.set('setVar', function(name:String, value:Dynamic) {
			MusicBeatState.getVariables().set(name, value);
			return value;
		});
		script.set('getVar', function(name:String):Dynamic {
			var vars = MusicBeatState.getVariables();
			return vars.exists(name) ? vars.get(name) : null;
		});
		script.set('removeVar', function(name:String) {
			return MusicBeatState.getVariables().remove(name);
		});
		script.set('debugPrint', function(text:Dynamic, ?color:Null<Int>) {
			var textColor:FlxColor = (color != null) ? FlxColor.fromInt(color) : FlxColor.WHITE;
			if (PlayState.instance != null && FlxG.state == PlayState.instance)
				PlayState.instance.addTextToDebug(Std.string(text), textColor);
			else
				trace(text);
		});
		script.set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if (modName == null) modName = script.modFolder;
			if (modName == null)
			{
				@:privateAccess script.error('getModSetting: el script no está dentro de una carpeta de mod');
				return null;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});
		script.set('importClass', function(path:String):Dynamic {
			var cls:Dynamic = Type.resolveClass(path);
			if (cls == null) cls = Type.resolveEnum(path);
			if (cls != null) script.set(path.split('.').pop(), cls);
			return cls;
		});

		// Teclado / controles
		script.set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		script.set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		script.set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		script.set('keyJustPressed', function(name:String = ''):Bool {
			return switch (name.toLowerCase())
			{
				case 'left': Controls.instance.NOTE_LEFT_P;
				case 'down': Controls.instance.NOTE_DOWN_P;
				case 'up': Controls.instance.NOTE_UP_P;
				case 'right': Controls.instance.NOTE_RIGHT_P;
				default: Controls.instance.justPressed(name.toLowerCase());
			}
		});
		script.set('keyPressed', function(name:String = ''):Bool {
			return switch (name.toLowerCase())
			{
				case 'left': Controls.instance.NOTE_LEFT;
				case 'down': Controls.instance.NOTE_DOWN;
				case 'up': Controls.instance.NOTE_UP;
				case 'right': Controls.instance.NOTE_RIGHT;
				default: Controls.instance.pressed(name.toLowerCase());
			}
		});
		script.set('keyReleased', function(name:String = ''):Bool {
			return switch (name.toLowerCase())
			{
				case 'left': Controls.instance.NOTE_LEFT_R;
				case 'down': Controls.instance.NOTE_DOWN_R;
				case 'up': Controls.instance.NOTE_UP_R;
				case 'right': Controls.instance.NOTE_RIGHT_R;
				default: Controls.instance.justReleased(name.toLowerCase());
			}
		});
	}
}
#end
