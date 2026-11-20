package flux.scripting;

#if FLUX_SCRIPTS_ALLOWED
import flixel.FlxState;

using StringTools;

/**
 * Scripts de Flux fuera de las canciones (sobre todo .hxs, pero sirve con
 * cualquier lenguaje de Flux):
 *
 *  - Globales: `scripts/global/` del mod (por ejemplo `mods/MiMod/scripts/global/fps.hxs`).
 *    Corren siempre, en todos los menús y en las canciones.
 *    Funciones: onCreate, onStateCreate(estado), onStateCreatePost(estado),
 *    onStateSwitch(estado), onUpdate(elapsed), onBeatHit(beat), onStepHit(step),
 *    onFocusLost, onFocus.
 *
 *  - De estado: `states/<NombreDelEstado>` del mod, por ejemplo
 *    `mods/MiMod/states/MainMenuState.hxs`. Corren mientras ese menú está abierto
 *    (TitleState, MainMenuState, FreeplayState, StoryMenuState, OptionsState,
 *    CreditsState...). `game` es el menú. Las canciones (PlayState) siguen usando
 *    las carpetas de siempre (scripts/, data/<canción>/...).
 *    Funciones: onCreate, onCreatePost, onUpdate(elapsed), onUpdatePost(elapsed),
 *    onBeatHit(beat), onStepHit(step), onDestroy, onFocusLost, onFocus.
 *
 *  - Estados nuevos: `switchState('MiMenu')` (desde un .hxs) abre
 *    `states/MiMenu.hxs` como un menú propio, aunque no exista en el código.
 *
 * Se buscan en las mismas carpetas que usa Psych: assets/shared, mods/,
 * los mods globales y el mod actual.
 */
class FluxStateScripts
{
	public static var globalScripts(default, null):Array<FluxScript> = [];
	public static var stateScripts(default, null):Array<FluxScript> = [];

	static var initialized:Bool = false;
	static var globalSignature:String = null;
	static var scriptsState:FlxState = null;

	public static function init():Void
	{
		if (initialized)
			return;
		initialized = true;
		FlxG.signals.preStateSwitch.add(onPreStateSwitch);
		FlxG.signals.preStateCreate.add(onPreStateCreate);
		FlxG.signals.postStateSwitch.add(onPostStateSwitch);
		FlxG.signals.postUpdate.add(onPostUpdate);
		FlxG.signals.focusLost.add(function() callAll('onFocusLost', []));
		FlxG.signals.focusGained.add(function() callAll('onFocus', []));
	}

	/** Nombre que se usa para buscar `states/<nombre>`. */
	public static function stateNameOf(state:FlxState):String
	{
		if (state == null)
			return null;
		if (Std.isOfType(state, FluxScriptedState))
			return (cast state : FluxScriptedState).stateName;
		return Type.getClassName(Type.getClass(state)).split('.').pop();
	}

	/** ¿Hay un script para un estado con ese nombre? (para switchState) */
	public static function stateFileExists(name:String):Bool
		return findStateFiles(name).length > 0;

	// ----- Señales -----

	static function onPreStateSwitch():Void
	{
		for (script in stateScripts)
			if (script != null && script.active)
			{
				script.call('onDestroy');
				script.destroy();
			}
		stateScripts = [];
		scriptsState = null;
		callGlobals('onStateSwitch', [FlxG.state]);
	}

	static function onPreStateCreate(state:FlxState):Void
	{
		reloadGlobals();
		for (script in globalScripts)
			script.set('game', state);
		callGlobals('onStateCreate', [state]);

		var name:String = stateNameOf(state);
		if (name == null || Std.isOfType(state, states.PlayState))
			return;
		for (file in findStateFiles(name))
		{
			var script:FluxScript = FluxScriptHandler.create(file);
			if (script != null)
				stateScripts.push(script);
		}
		scriptsState = state;
		callState('onCreate', []);
	}

	static function onPostStateSwitch():Void
	{
		callState('onCreatePost', []);
		callGlobals('onStateCreatePost', [FlxG.state]);
	}

	static function onPostUpdate():Void
		callGlobals('onUpdate', [FlxG.elapsed]);

	// ----- Los llama MusicBeatState -----

	public static function onUpdate(state:FlxState, elapsed:Float):Void
		if (state == scriptsState)
			callState('onUpdate', [elapsed]);

	public static function onUpdatePost(state:FlxState, elapsed:Float):Void
		if (state == scriptsState)
			callState('onUpdatePost', [elapsed]);

	public static function onBeatHit(state:FlxState, beat:Int):Void
	{
		if (state == scriptsState)
			callState('onBeatHit', [beat]);
		if (state == FlxG.state)
			callGlobals('onBeatHit', [beat]);
	}

	public static function onStepHit(state:FlxState, step:Int):Void
	{
		if (state == scriptsState)
			callState('onStepHit', [step]);
		if (state == FlxG.state)
			callGlobals('onStepHit', [step]);
	}

	// ----- Carga -----

	static function reloadGlobals():Void
	{
		var folders:Array<String> = directories('scripts/global/');
		var files:Array<String> = [];
		for (folder in folders)
			for (file in listScripts(folder))
				files.push(file);
		var signature:String = files.join('|');
		if (signature == globalSignature)
			return;
		globalSignature = signature;

		for (script in globalScripts)
			if (script != null && script.active)
			{
				script.call('onDestroy');
				script.destroy();
			}
		globalScripts = [];

		for (file in files)
		{
			var script:FluxScript = FluxScriptHandler.create(file);
			if (script == null)
				continue;
			script.setParentInstance(null); // no pertenece a ningún estado
			globalScripts.push(script);
			script.call('onCreate');
		}
	}

	static function findStateFiles(name:String):Array<String>
	{
		var result:Array<String> = [];
		if (name == null || name.length == 0)
			return result;
		for (folder in directories('states/'))
			for (ext in FluxScriptHandler.getExtensions())
			{
				var path:String = folder + name + ext;
				if (FileSystem.exists(path) && !result.contains(path))
					result.push(path);
			}
		return result;
	}

	static function directories(sub:String):Array<String>
	{
		var list:Array<String> = [];
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), sub))
		{
			var path:String = folder.endsWith('/') ? folder : folder + '/';
			if (!list.contains(path))
				list.push(path);
		}
		return list;
	}

	static function listScripts(folder:String):Array<String>
	{
		var result:Array<String> = [];
		if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
			return result;
		var entries:Array<String> = FileSystem.readDirectory(folder);
		entries.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));
		for (entry in entries)
			if (FluxScriptHandler.isSupported(entry))
				result.push(folder + entry);
		return result;
	}

	// ----- Llamadas -----

	static function callState(name:String, args:Array<Dynamic>):Void
		for (script in stateScripts.copy())
			if (script != null && script.active)
				script.call(name, args);

	static function callGlobals(name:String, args:Array<Dynamic>):Void
		for (script in globalScripts.copy())
			if (script != null && script.active)
				script.call(name, args);

	static function callAll(name:String, args:Array<Dynamic>):Void
	{
		callGlobals(name, args);
		callState(name, args);
	}
}

#end
