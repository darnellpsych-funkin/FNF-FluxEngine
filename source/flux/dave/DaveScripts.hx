package flux.dave;

#if FLUX_DAVE_SCRIPTS
import flux.dave.api.DaveCharacter;
import flux.dave.api.DaveStage;
import flux.vslice.FluxVSliceAssets;
import flux.vslice.api.ScriptEvent;
import flux.vslice.modules.FluxVSliceModules;

/**
 * Las clases de Dave Engine que hay en los .hxc de los mods activos.
 *
 * FluxVSliceModules lee todos los .hxc y nos pasa las clases que hacen
 * `extends Character` (personajes) o `extends Stage` (escenarios); acá se
 * guarda qué clase es cada id (el `super('dave')` del constructor). Los
 * `extends SongModule` y los `extends Module` de los mods de Dave van a DaveModules.
 */
class DaveScripts
{
	/** id del personaje -> clase del .hxc. */
	public static var characterClasses(default, null):Map<String, String> = new Map<String, String>();

	/** id del escenario -> clase del .hxc. */
	public static var stageClasses(default, null):Map<String, String> = new Map<String, String>();

	/** Clase -> archivo (para los errores). */
	static var files:Map<String, String> = new Map<String, String>();

	/** Clase -> mod de su .hxc. */
	static var classMods:Map<String, String> = new Map<String, String>();

	public static function clear():Void
	{
		DaveModules.clear();
		characterClasses = new Map<String, String>();
		stageClasses = new Map<String, String>();
		files = new Map<String, String>();
		classMods = new Map<String, String>();
	}

	/**
	 * Un archivo de los mods de Dave (data/characters/x.json, data/offsets/x.txt...) como lo
	 * ve Polymod: del mod actual o los globales, del mod del script, o de cualquier mod activo
	 * (los mods de fans usan los personajes del juego base, que está en otro mod).
	 */
	public static function findFile(file:String, ?className:String):String
	{
		var path:String = FluxVSliceAssets.findData(file);
		if (path != null)
			return path;
		#if MODS_ALLOWED
		var mods:Array<String> = [];
		var own:String = className != null ? classMods.get(className) : null;
		if (own != null)
			mods.push(own);
		for (mod in FluxVSliceModules.enabledMods)
			if (!mods.contains(mod))
				mods.push(mod);
		for (mod in mods)
			for (folder in ['', 'shared/'])
			{
				var modded:String = Paths.mods('$mod/$folder$file');
				if (FileSystem.exists(modded))
					return modded;
			}
		#end
		return null;
	}

	/** Las clases que solo existen en Dave Engine (un mod que las tiene es un mod de Dave). */
	public static function isDaveOnlyClass(superName:String):Bool
	{
		return switch (superName)
		{
			case 'Character' | 'ScriptedCharacter' | 'SongModule' | 'ScriptedSongModule' | 'Dialogue' | 'ScriptedDialogue' | 'VoidBGSprite'
				| 'ScriptedBGSprite': true;
			default: false;
		}
	}

	/**
	 * Guarda la clase si es de Dave (personaje, escenario o módulo). Devuelve false si no lo es.
	 * `superId`: el primer texto del `super(...)` del constructor. `daveMod`: si el mod del
	 * .hxc es de Dave (así un `extends Module` es un módulo de Dave y no uno de V-Slice).
	 */
	public static function register(name:String, superName:String, superId:String, file:String, ?mod:String, daveMod:Bool = false):Bool
	{
		switch (superName)
		{
			case 'SongModule' | 'ScriptedSongModule':
				remember(name, file, mod);
				DaveModules.addClass(name, true);
				return true;
			case 'Module' | 'ScriptedModule' if (daveMod):
				remember(name, file, mod);
				DaveModules.addClass(name, false);
				return true;
			default:
		}
		var map:Map<String, String> = switch (superName)
		{
			case 'Character' | 'ScriptedCharacter': characterClasses;
			case 'Stage' | 'ScriptedStage': stageClasses;
			default: null;
		}
		if (map == null)
			return false;
		var id:String = (superId != null && superId.length > 0) ? superId : name;
		if (map.exists(id) && map.get(id) != name)
			trace('[Dave Engine] ${map.get(id)} y $name son el mismo "$id"; se usa $name.');
		map.set(id, name);
		remember(name, file, mod);
		return true;
	}

	static function remember(name:String, file:String, mod:String):Void
	{
		files.set(name, file);
		if (mod != null)
			classMods.set(name, mod);
	}

	/** Si la clase es de un personaje o escenario de Dave (tienen los "imports por defecto" de Dave). */
	public static function isDaveClass(name:String):Bool
		return name != null && files.exists(name);

	/** "DaveCharacter (mods/x/scripts/characters/dave.hxc)" */
	public static function describe(target:Dynamic):String
	{
		var name:String = null;
		if (Std.isOfType(target, DaveCharacter))
			name = (cast target : DaveCharacter).scriptClass;
		else if (Std.isOfType(target, DaveStage))
			name = (cast target : DaveStage).scriptClass;
		else if (target != null && Std.isOfType(target, rulescript.scriptedClass.RuleScriptedClass))
			return moduleName(target);
		if (name == null)
			return 'Dave Engine';
		var file:String = files.get(name);
		return file != null ? '$name ($file)' : name;
	}

	/** "miModulo (mods/x/scripts/modules/algo.hxc)" para los errores de un módulo. */
	static function moduleName(target:Dynamic):String
	{
		var id:Dynamic = Reflect.getProperty(target, 'moduleId');
		var script:Dynamic = Reflect.field(target, '__rulescript');
		var file:Dynamic = script != null ? Reflect.getProperty(script, 'scriptName') : null;
		var name:String = id != null ? Std.string(id) : 'Dave Engine';
		return file != null ? '$name ($file)' : name;
	}

	public static function report(target:Dynamic, error:Dynamic):Void
	{
		var message:String = Std.isOfType(error, haxe.Exception) ? (cast error : haxe.Exception).message : Std.string(error);
		FluxVSliceModules.reportError(describe(target), message);
	}

	/** Un error de una clase por su nombre (con su archivo). */
	public static function reportClass(name:String, message:String):Void
		FluxVSliceModules.reportError(files.exists(name) ? '$name (${files.get(name)})' : name, message);

	/** Crea el script de un personaje para un personaje de Psych (null si falla). */
	public static function createCharacter(className:String, target:objects.Character):DaveCharacter
	{
		var script:FluxScriptedDaveCharacter = null;
		DaveCharacter.pendingTarget = target;
		try
		{
			script = new FluxScriptedDaveCharacter(className, []);
		}
		catch (e:Dynamic)
		{
			FluxVSliceModules.reportError(files.exists(className) ? '$className (${files.get(className)})' : className, 'no se pudo crear: $e');
			script = null;
		}
		DaveCharacter.pendingTarget = null;
		if (script == null)
			return null;
		script.scriptClass = className;
		script.scriptInterp = @:privateAccess script.__rulescript.interp;
		return script;
	}

	/** Crea el script de un escenario (null si falla). */
	public static function createStage(className:String, runtime:FluxDaveStage):DaveStage
	{
		var script:FluxScriptedDaveStage = null;
		DaveStage.pendingRuntime = runtime;
		try
		{
			script = new FluxScriptedDaveStage(className, []);
		}
		catch (e:Dynamic)
		{
			FluxVSliceModules.reportError(files.exists(className) ? '$className (${files.get(className)})' : className, 'no se pudo crear: $e');
			script = null;
		}
		DaveStage.pendingRuntime = null;
		if (script == null)
			return null;
		script.scriptClass = className;
		script.scriptInterp = @:privateAccess script.__rulescript.interp;
		return script;
	}

	/** Si el script tiene su propia versión de una función. */
	public static function hasOwn(target:Dynamic, name:String):Bool
	{
		if (target == null || !Std.isOfType(target, rulescript.scriptedClass.RuleScriptedClass))
			return false;
		var scripted:rulescript.scriptedClass.RuleScriptedClass = cast target;
		var value:Dynamic = scripted.variableExists(name) ? scripted.getVariable(name) : null;
		return value != null && Reflect.isFunction(value);
	}

	/**
	 * Manda un evento de Dave a un script (onScriptEvent y la función del evento),
	 * como ScriptEventDispatcher.callEvent de Dave. Los errores van a la consola.
	 */
	public static function dispatch(target:Dynamic, method:String, event:Dynamic):Void
	{
		if (target == null)
			return;
		try
		{
			callMethod(target, 'onScriptEvent', event);
			if (event == null || !Std.isOfType(event, ScriptEvent) || (cast event : ScriptEvent).shouldPropagate)
				callMethod(target, method, event);
		}
		catch (e:Dynamic)
		{
			report(target, e);
		}
	}

	static inline function callMethod(target:Dynamic, name:String, event:Dynamic):Void
	{
		var fn:Dynamic = Reflect.getProperty(target, name);
		if (fn != null && Reflect.isFunction(fn))
			Reflect.callMethod(target, fn, [event]);
	}
}
#end
