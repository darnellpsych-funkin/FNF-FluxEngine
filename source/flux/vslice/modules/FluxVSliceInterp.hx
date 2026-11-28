package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
import flux.scripting.FluxRuleScript.FluxRuleScriptInterp;
import flux.vslice.api.VSliceApi.VSMissing;
import hscript.Expr;

using StringTools;

/**
 * Intérprete de RuleScript para los módulos .hxc de V-Slice.
 *  - Los `import funkin...` usan las clases de Flux/Psych (VSliceTypes).
 *  - Los campos con nombre de V-Slice se traducen a Psych (VSliceAdapter).
 *  - Si falta una clase, el módulo carga igual y se avisa en la consola.
 *  - Errores más claros cuando se llama a algo que no existe.
 */
class FluxVSliceInterp extends FluxRuleScriptInterp
{
	/** Tipos que el script importó y que Flux todavía no tiene. */
	public var missingTypes(default, null):Array<String> = [];

	/** Si es un script de Dave Engine (personaje o escenario). */
	public var dave(default, null):Bool = false;

	/** Para los scripts de Dave Engine: sus imports (play.*, audio.*...) y sus clases sin importar. */
	public function enableDave():Void
	{
		dave = true;
		#if FLUX_DAVE_SCRIPTS
		if (variables != null)
			flux.dave.api.DaveApi.DaveTypes.applyGlobals(variables);
		#end
	}

	override function resolveType(path:String):Dynamic
	{
		#if FLUX_DAVE_SCRIPTS
		if (dave)
		{
			var daveType:Dynamic = flux.dave.api.DaveApi.DaveTypes.resolve(path);
			if (daveType != null)
				return daveType;
		}
		#end
		var type:Dynamic = VSliceTypes.resolve(path);
		if (type != null)
			return type;

		var enumType:Dynamic = Type.resolveEnum(path);
		if (enumType != null)
			return enumType;

		type = Type.resolveClass(path);
		#if interp
		// en el intérprete de Haxe (pruebas) una clase que no existe vuelve "vacía"
		if (type != null)
		{
			var empty:Bool = true;
			try
			{
				empty = Type.getInstanceFields(type).length == 0 && Type.getClassFields(type).length == 0;
			}
			catch (e:Dynamic) {}
			if (empty)
				type = null;
		}
		#end
		if (type != null)
			return type;

		try
		{
			type = super.resolveType(path);
		}
		catch (e:Dynamic)
		{
			type = null;
		}

		if (type == null)
		{
			if (!missingTypes.contains(path))
				missingTypes.push(path);
			return VSMissing;
		}
		return type;
	}

	override function set_scriptPackage(value:String):String
	{
		var result:String = super.set_scriptPackage(value);
		if (variables != null)
			VSliceTypes.applyGlobals(variables);
		return result;
	}

	override function get(o:Dynamic, f:String):Dynamic
	{
		if (o != null && o != this)
		{
			#if FLUX_DAVE_SCRIPTS
			if (dave)
			{
				// lo que el PlayState de Dave tiene y el de Psych no (switchDad, ghostTapping, dadStrums...)
				var daveValue:Dynamic = flux.dave.DaveAdapter.getField(o, f);
				if (daveValue != VSliceAdapter.UNHANDLED)
					return daveValue;
			}
			#end
			var value:Dynamic = VSliceAdapter.getField(o, f);
			if (value != VSliceAdapter.UNHANDLED)
				return value;
		}
		return super.get(o, f);
	}

	override function set(o:Dynamic, f:String, v:Dynamic):Dynamic
	{
		#if FLUX_DAVE_SCRIPTS
		if (dave && o != null && o != this && flux.dave.DaveAdapter.setField(o, f, v))
			return v;
		#end
		if (o != null && o != this && VSliceAdapter.setField(o, f, v))
			return v;
		if (o == VSMissing)
			error(ECustom('No se puede cambiar "$f": ese tipo de V-Slice todavía no existe en Flux'));
		return super.set(o, f, v);
	}

	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic
	{
		if (o == null)
			error(EInvalidAccess(f));
		if (o == VSMissing)
			error(ECustom('No se puede usar "$f": ese tipo de V-Slice todavía no existe en Flux'));

		var fn:Dynamic = get(o, f);
		if (fn == null || !Reflect.isFunction(fn))
			error(ECustom('No existe la función "$f" en ${VSliceAdapter.describe(o)}'));
		return call(o, fn, args);
	}

	override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic
	{
		if (f == null)
			error(ECustom('Se llamó a una función que es null'));
		return super.call(o, f, args);
	}

	/** `for (x in null)` no hace nada (en vez de cortar todo el script con "Invalid iterator"). */
	override function makeIterator(v:Dynamic):Iterator<Dynamic>
	{
		if (v == null)
			return [].iterator();
		return super.makeIterator(v);
	}

	/** `for (k => v in mapa)` también en C++ (el de RuleScript falla con los Map ahí). */
	override function makeKeyValueIterator(v:Dynamic):{next:() -> Dynamic, hasNext:() -> Bool}
	{
		if (Std.isOfType(v, haxe.Constraints.IMap))
		{
			var map:haxe.Constraints.IMap<Dynamic, Dynamic> = cast v;
			var keys:Array<Dynamic> = [];
			var values:Array<Dynamic> = [];
			for (key in map.keys())
			{
				keys.push(key);
				values.push(map.get(key));
			}
			return cast new VSKeyValueIterator(keys, values);
		}
		if (Std.isOfType(v, Array))
		{
			var array:Array<Dynamic> = cast v;
			return cast new VSKeyValueIterator([for (i in 0...array.length) i], array.copy());
		}
		return super.makeKeyValueIterator(v);
	}

	override function cnew(cl:String, args:Array<Dynamic>):Dynamic
	{
		var type:Dynamic = variables.get(cl);
		if (type == null && (cl == 'Map' || cl == 'StringMap'))
			return new haxe.ds.StringMap<Dynamic>();
		if (type == VSMissing)
			error(ECustom('No se puede crear "$cl": ese tipo de V-Slice todavía no existe en Flux'));
		// new SparrowCharacter('bf') / new BaseCharacter('bf', 'sparrow') de V-Slice -> personaje de Flux
		if (type == objects.Character && args.length > 0 && Std.isOfType(args[0], String))
			return flux.vslice.api.VSliceApi.VSCharacterDataParser.fetchCharacter(args[0]);
		if (type != null && Std.isOfType(type, Class))
			return Type.createInstance(type, args);
		return super.cnew(cl, args);
	}
}
@:keep
class VSKeyValueIterator
{
	var keys:Array<Dynamic>;
	var values:Array<Dynamic>;
	var index:Int = 0;

	public function new(keys:Array<Dynamic>, values:Array<Dynamic>)
	{
		this.keys = keys;
		this.values = values;
	}

	public function hasNext():Bool
		return index < keys.length;

	public function next():Dynamic
	{
		var i:Int = index++;
		return {key: keys[i], value: values[i]};
	}
}
#end
