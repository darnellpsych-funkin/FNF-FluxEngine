package flux.scripting;

#if NXSCRIPT_ALLOWED
import nx.script.Interpreter;
import nx.script.Bytecode.Value;

/**
 * Soporte de NXScript (.nx / .nxs) para Flux Engine.
 * Librería: https://github.com/senioritaelizabeth/NxScript
 *
 * Ejemplo de script (mods/MiMod/scripts/hola.nx):
 *
 *   var bg
 *   func onCreatePost() {
 *       bg = new FlxSprite(0, 0)
 *       bg.makeGraphic(200, 200, FlxColor.RED)
 *       game.add(bg)
 *       FlxTween.tween(bg, toHaxe({"alpha": 0}), 2)
 *   }
 *   func onBeatHit() {
 *       if (curBeat % 4 == 0) game.camGame.zoom += 0.03
 *   }
 *
 * IMPORTANTE: NXScript convierte sus diccionarios {...} y sus funciones a `null`
 * cuando los pasa a un método de Haxe. Para eso existe `toHaxe(valor)`, que los
 * convierte en un objeto/función real de Haxe:
 *
 *   FlxTween.tween(spr, toHaxe({"x": 100}), 1, toHaxe({"onComplete": t => trace("listo")}))
 *   new FlxTimer().start(1, toHaxe(t => trace("pasó 1 segundo")))
 *
 * Las funciones que pone Flux Engine (setVar, debugPrint, etc.) ya hacen esa
 * conversión solas, no hace falta toHaxe() con ellas.
 */
class FluxNXScript extends FluxScript
{
	public var interp:Interpreter;

	/** Cache de funciones resueltas (null = no existe), para no buscar cada frame */
	var callableCache:Map<String, Null<Value>> = new Map();
	var noArgs:Array<Value> = [];

	public function new(origin:String, code:String)
	{
		super(origin, code);
		language = 'NXScript';
		interp = new Interpreter();

		interp.register('toHaxe', 1, function(args:Array<Value>):Value {
			var v = args.length > 0 ? args[0] : VNull;
			return switch (v)
			{
				case VDict(_) | VArray(_) | VFunction(_, _) | VNativeFunction(_, _, _):
					VNativeObject(toHaxe(v));
				default:
					v;
			}
		});
	}

	override public function execute():Bool
	{
		if (!active || code == null) return false;
		try
		{
			returnValue = toHaxe(interp.run(code, origin));
			callableCache.clear();
			return true;
		}
		catch (e:Dynamic)
		{
			error('Error al cargar: $e');
			return false;
		}
	}

	override public function exists(name:String):Bool
		return resolve(name) != null;

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active) return null;
		var fn = resolve(name);
		if (fn == null) return null;

		try
		{
			var nxArgs:Array<Value> = noArgs;
			if (args != null && args.length > 0)
				nxArgs = [for (a in args) interp.vm.haxeToValue(a)];

			return toHaxe(interp.vm.callResolved(fn, nxArgs));
		}
		catch (e:Dynamic)
		{
			error('Error en $name: $e');
			return null;
		}
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (interp == null) return;
		callableCache.remove(name);

		if (Reflect.isFunction(value))
		{
			// Función nativa que sí entiende diccionarios y lambdas de NXScript
			var vm = interp.vm;
			interp.globals.set(name, VNativeFunction(name, -1, function(args:Array<Value>):Value {
				var haxeArgs:Array<Dynamic> = [for (a in args) toHaxe(a)];
				return vm.haxeToValue(Reflect.callMethod(null, value, haxeArgs));
			}));
			return;
		}
		interp.set(name, value);
	}

	override public function get(name:String):Dynamic
	{
		if (interp == null) return null;
		var v = interp.get(name);
		return v == null ? null : toHaxe(v);
	}

	override public function destroy():Void
	{
		super.destroy();
		callableCache = null;
		interp = null;
	}

	function resolve(name:String):Null<Value>
	{
		if (interp == null || name == null) return null;
		if (callableCache.exists(name)) return callableCache.get(name);

		var found:Null<Value> = null;
		try
		{
			var v = interp.resolveCallable(name);
			switch (v)
			{
				case VFunction(_, _) | VNativeFunction(_, _, _):
					found = v;
				default:
			}
		}
		catch (e:Dynamic) {}

		callableCache.set(name, found);
		return found;
	}

	/**
	 * Convierte un valor de NXScript a Haxe de forma profunda.
	 * A diferencia de vm.valueToHaxe(), los diccionarios pasan a objetos
	 * anónimos y las funciones del script pasan a funciones llamables desde Haxe.
	 */
	public function toHaxe(v:Value):Dynamic
	{
		if (v == null || interp == null) return null;
		return switch (v)
		{
			case VDict(map):
				var obj:Dynamic = {};
				for (key => val in map)
					Reflect.setField(obj, key, toHaxe(val));
				obj;
			case VArray(arr):
				[for (val in arr) toHaxe(val)];
			case VFunction(_, _) | VNativeFunction(_, _, _):
				makeHaxeFunction(v);
			default:
				interp.vm.valueToHaxe(v);
		}
	}

	function makeHaxeFunction(fn:Value):Dynamic
	{
		return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
			if (!active || interp == null) return null;
			try
			{
				return toHaxe(interp.vm.callResolved(fn, [for (a in args) interp.vm.haxeToValue(a)]));
			}
			catch (e:Dynamic)
			{
				error('Error en callback: $e');
				return null;
			}
		});
	}
}
#end
