package flux.scripting;

#if FLUXSCRIPT_ALLOWED
import fluxscript.FluxScript as Runtime;

/**
 * FluxScript (.flux): el lenguaje propio de Flux Engine, un addon de HScript.
 * Repo: https://github.com/darnellpsych-funkin/FluxScript (incluido en
 * source/flux/vendor/fluxscript).
 *
 * Se escribe como un .hx de Psych y además tiene: clases sin `import`, los campos
 * del estado directo (`health = 2`), textos con variables ('Hola $nombre'),
 * `on('beatHit', función)`, `shared`, `wait`/`every`, la API de Lua de Psych
 * (makeLuaSprite, doTweenX, runTimer...) y el preset de los .hxs.
 */
class FluxScriptLang extends FluxScript
{
	public var runtime(default, null):Runtime;

	static var definesReady:Bool = false;

	public function new(origin:String, code:String, ?parentInstance:Dynamic)
	{
		super(origin, code);
		language = 'FluxScript';
		setupDefines();

		runtime = new Runtime(code, origin, parentInstance);
		runtime.onError = function(message:String) error(message);
		runtime.onWarning = function(message:String) FluxScript.onWarning(this, message);
		runtime.onClose = function() active = false;
	}

	/** Lo que se puede usar en `#if` dentro de un .flux (y el resolver de los `import`). */
	static function setupDefines():Void
	{
		if (definesReady)
			return;
		definesReady = true;
		// los `import` de Codename y V-Slice usan su equivalente de Psych, como en los .hxs
		fluxscript.FluxClasses.resolver = FluxHxsPreset.resolveImport;
		var defines = Runtime.defines;
		defines.set('FLUX_ENGINE', true);
		defines.set('PSYCH', true);
		#if LUA_ALLOWED defines.set('LUA_ALLOWED', true); #end
		#if VIDEOS_ALLOWED defines.set('VIDEOS_ALLOWED', true); #end
		#if MODS_ALLOWED defines.set('MODS_ALLOWED', true); #end
		#if FLUX_VSLICE defines.set('FLUX_VSLICE', true); #end
	}

	override public function execute():Bool
	{
		if (!active || code == null || runtime == null)
			return false;
		runtime.modFolder = modFolder;
		var ok:Bool = runtime.run(code);
		returnValue = runtime.returnValue;
		return ok;
	}

	override public function exists(name:String):Bool
		return active && runtime != null && runtime.exists(name);

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active || runtime == null)
			return null;
		return runtime.call(name, args);
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (runtime != null)
			runtime.set(name, value);
	}

	override public function get(name:String):Dynamic
		return runtime != null ? runtime.get(name) : null;

	override public function setParentInstance(parent:Dynamic):Void
	{
		if (runtime != null)
			runtime.parent = parent;
	}

	override public function destroy():Void
	{
		super.destroy();
		if (runtime != null)
			runtime.destroy();
		runtime = null;
	}
}
#end
