package flux.scripting;

#if LUAU_ALLOWED
import flux.scripting.luau.LuauNative;
import flux.scripting.luau.LuauNative.LuauState;
import haxe.Constraints.IMap;
import haxe.ds.IntMap;
import haxe.ds.ObjectMap;

using StringTools;

/**
 * Scripts `.luau`: Luau, el Lua de Roblox (https://luau.org), compilado dentro del juego.
 *
 * Los objetos del juego se usan directo, sin getProperty/setProperty:
 *
 *   game.boyfriend.alpha = 0.5
 *   local spr = FlxSprite.new(100, 100)      -- o FlxSprite(100, 100)
 *   spr:makeGraphic(50, 50, 0xFFFF0000)      -- métodos con ':' (o con '.')
 *   game:add(spr)
 *   for i, note in game.notes.members do ... end   -- las listas de Haxe empiezan en 1
 *
 * Además trae `task.wait/spawn/delay/defer`, `wait`, `require`, `import`, `print`, `warn`,
 * `loadstring` y `toTable` (ver README).
 *
 * Cómo funciona: cada objeto de Haxe que llega a Luau es un userdata con un id; los
 * metamétodos (__index, __newindex, __namecall...) llaman a `dispatch`, que usa Reflect.
 * Las funciones de Luau que llegan a Haxe se envuelven con Reflect.makeVarArgs.
 * Luau se compila con hxcpp gracias a `luau.xml` (ver flux/scripting/luau/LuauBuild.hx).
 */
@:build(flux.scripting.luau.LuauBuild.inject())
class FluxLuau extends FluxScript
{
	/** Busca un archivo para require() (FluxScriptHandler lo conecta con mods y assets). */
	public static var fileResolver:String->String = function(path:String):String {
		return sys.FileSystem.exists(path) ? path : null;
	};

	/** Equivalentes de clases para import() (FluxScriptHandler lo conecta con el de los .hxs). */
	public static var importResolver:String->Dynamic = null;

	/** Lo que hace print() */
	public static var onPrint:(script:FluxLuau, text:String) -> Void = function(script:FluxLuau, text:String) {
		trace('[Luau] ${script.origin}: $text');
	};

	static var scripts:IntMap<FluxLuau> = new IntMap();
	static var nextScriptId:Int = 0;
	static var callbacksReady:Bool = false;

	@:unreflective var state:LuauState;
	@:unreflective var current:LuauState;
	var closed:Bool = false;
	var inDispatch:Int = 0;
	var depth:Int = 0;
	var pendingClose:Bool = false;
	var scriptId:Int = 0;

	var objects:IntMap<Dynamic> = new IntMap();
	var objectIds:ObjectMap<Dynamic, Int> = new ObjectMap();
	var nextObjectId:Int = 0;
	var newObjects:Int = 0;
	var luaFunctions:IntMap<Dynamic> = new IntMap();
	var luaFunctionRefs:ObjectMap<Dynamic, Int> = new ObjectMap();
	var constructors:ObjectMap<Dynamic, Dynamic> = new ObjectMap();

	var preludeDone:Bool = false;
	var callRef:Int = -1;
	var stepRef:Int = -1;

	public function new(origin:String, code:String)
	{
		super(origin, code);
		language = 'Luau';

		if (!callbacksReady)
		{
			callbacksReady = true;
			untyped __cpp__('fluxluau_setcallbacks((fluxluau_Dispatch)&::flux::scripting::FluxLuau_obj::luauDispatch, (fluxluau_Release)&::flux::scripting::FluxLuau_obj::luauRelease)');
		}

		scriptId = ++nextScriptId;
		state = LuauNative.newstate(scriptId);
		current = state;
		scripts.set(scriptId, this);

		set('__flux_report', function(message:Dynamic) error(Std.string(message)));
		set('__flux_print', function(text:String) onPrint(this, text));
		set('__flux_warn', function(text:String) FluxScript.onWarning(this, text));
		set('__flux_findmodule', findModule);
		set('__flux_readfile', function(path:String):String return sys.io.File.getContent(path));
		set('import', importType);
	}

	// ------------------------------------------------------------------
	// API de FluxScript
	// ------------------------------------------------------------------

	override public function execute():Bool
	{
		if (closed || !active)
			return false;
		if (!preludeDone && !runPrelude())
			return false;

		var L:LuauState = current;
		var top:Int = LuauNative.gettop(L);
		LuauNative.getref(L, callRef);
		if (load(L, '@' + origin, code) != 0)
		{
			error(popError(L, top));
			return false;
		}
		var ok:Bool = protectedCall(L, top, 1);
		if (ok)
			returnValue = toHaxe(L, -1);
		finishCall(L, top);
		return ok;
	}

	override public function exists(name:String):Bool
	{
		if (closed || !active)
			return false;
		// onUpdate siempre "existe": es lo que mueve task.wait/delay aunque el script no lo use
		if (name == 'onUpdate')
			return true;
		var L:LuauState = current;
		getGlobal(L, name);
		var type:Int = LuauNative.type(L, -1);
		LuauNative.settop(L, -2);
		return type == LuauNative.TFUNCTION;
	}

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (closed || !active || !preludeDone)
			return null;
		var L:LuauState = current;
		var top:Int = LuauNative.gettop(L);

		if (name == 'onUpdate' && stepRef >= 0)
		{
			LuauNative.getref(L, stepRef);
			push(L, (args != null && args.length > 0) ? args[0] : 0);
			protectedCall(L, top, 1);
			finishCall(L, top);
			if (closed || !active)
				return null;
		}

		LuauNative.getref(L, callRef);
		getGlobal(L, name);
		if (LuauNative.type(L, -1) != LuauNative.TFUNCTION)
		{
			LuauNative.settop(L, top);
			return null;
		}
		var count:Int = pushArgs(L, args);
		var result:Dynamic = null;
		if (protectedCall(L, top, count + 1))
			result = toHaxe(L, -1);
		finishCall(L, top);
		return result;
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (closed)
			return;
		var L:LuauState = current;
		push(L, value);
		untyped __cpp__('fluxluau_setglobal({0}, {1}.utf8_str())', L, name);
	}

	override public function get(name:String):Dynamic
	{
		if (closed)
			return null;
		var L:LuauState = current;
		getGlobal(L, name);
		var value:Dynamic = toHaxe(L, -1);
		LuauNative.settop(L, -2);
		return value;
	}

	override public function destroy():Void
	{
		if (closed)
			return;
		active = false;
		// si Luau todavía está corriendo (el script se cerró desde adentro), se cierra al volver
		if (depth > 0 || inDispatch > 0)
		{
			pendingClose = true;
			return;
		}
		closeState();
	}

	/** Llama a una función de Luau que se guardó en Haxe (callbacks de tweens, timers, señales...). */
	public function callFunctionRef(ref:Int, args:Array<Dynamic>):Dynamic
	{
		if (closed || !active || !preludeDone)
			return null;
		var L:LuauState = current;
		var top:Int = LuauNative.gettop(L);
		LuauNative.getref(L, callRef);
		LuauNative.getref(L, ref);
		var count:Int = pushArgs(L, args);
		var result:Dynamic = null;
		if (protectedCall(L, top, count + 1))
			result = toHaxe(L, -1);
		finishCall(L, top);
		return result;
	}

	// ------------------------------------------------------------------
	// Ejecución
	// ------------------------------------------------------------------

	function runPrelude():Bool
	{
		var L:LuauState = current;
		var top:Int = LuauNative.gettop(L);
		if (load(L, '=flux', PRELUDE) != 0)
		{
			error('prelude: ' + popError(L, top));
			return false;
		}
		depth++;
		var status:Int = LuauNative.pcall(L, 0, 2);
		depth--;
		if (status != 0)
		{
			error('prelude: ' + popError(L, top));
			return false;
		}
		callRef = LuauNative.reffunction(L, -2);
		stepRef = LuauNative.reffunction(L, -1);
		LuauNative.settop(L, top);
		preludeDone = true;
		return true;
	}

	/** pcall con nresults = 1. Si falla, avisa el error y deja la pila como estaba. */
	function protectedCall(L:LuauState, top:Int, nargs:Int):Bool
	{
		depth++;
		var status:Int = LuauNative.pcall(L, nargs, 1);
		depth--;
		if (status != 0)
		{
			var message:String = popError(L, top);
			if (!closed)
				error(message);
			return false;
		}
		return true;
	}

	function finishCall(L:LuauState, top:Int):Void
	{
		if (!closed)
			LuauNative.settop(L, top);
		if (pendingClose && depth == 0 && inDispatch == 0)
			closeState();
		else if (!closed && depth == 0 && inDispatch == 0 && newObjects >= COLLECT_EVERY)
			collectGarbage();
	}

	/**
	 * Cada objeto de Haxe en Luau es un userdata chiquito, así que Luau no se da cuenta
	 * de cuánta memoria de Haxe está sosteniendo. Cada tantos objetos nuevos se hace
	 * una recolección completa para soltarlos.
	 */
	static inline var COLLECT_EVERY:Int = 4096;

	public function collectGarbage():Void
	{
		if (closed)
			return;
		newObjects = 0;
		LuauNative.collect(state);
	}

	function popError(L:LuauState, top:Int):String
	{
		var value:Dynamic = toHaxe(L, -1);
		LuauNative.settop(L, top);
		return value == null ? 'error' : Std.string(value);
	}

	function pushArgs(L:LuauState, args:Array<Dynamic>):Int
	{
		if (args == null)
			return 0;
		LuauNative.checkstack(L, args.length + 4);
		for (arg in args)
			push(L, arg);
		return args.length;
	}

	function closeState():Void
	{
		if (closed)
			return;
		var L:LuauState = state;
		closed = true;
		pendingClose = false;
		LuauNative.close(L);
		scripts.remove(scriptId);
		objects = new IntMap();
		objectIds = new ObjectMap();
		luaFunctions = new IntMap();
		luaFunctionRefs = new ObjectMap();
		constructors = new ObjectMap();
		super.destroy();
	}

	static function load(L:LuauState, chunkname:String, source:String):Int
	{
		return untyped __cpp__('fluxluau_load({0}, {1}.utf8_str(), {2}.utf8_str(), -1)', L, chunkname, source);
	}

	static function getGlobal(L:LuauState, name:String):Void
	{
		untyped __cpp__('fluxluau_getglobal({0}, {1}.utf8_str())', L, name);
	}

	static function pushString(L:LuauState, value:String):Void
	{
		untyped __cpp__('fluxluau_pushstring({0}, {1}.utf8_str())', L, value);
	}

	static function toString(L:LuauState, idx:Int):String
	{
		var length:Int = -1;
		var chars:cpp.RawConstPointer<cpp.Char> = untyped __cpp__('fluxluau_tolstring({0}, {1}, &{2})', L, idx, length);
		if (length < 0)
			return null;
		return untyped __cpp__('::String::create({0}, {1})', chars, length);
	}

	// ------------------------------------------------------------------
	// Haxe -> Luau
	// ------------------------------------------------------------------

	function push(L:LuauState, value:Dynamic):Void
	{
		switch (Type.typeof(value))
		{
			case TNull:
				LuauNative.pushnil(L);
			case TBool:
				LuauNative.pushboolean(L, value ? 1 : 0);
			case TInt | TFloat:
				LuauNative.pushnumber(L, value);
			case TFunction:
				pushFunction(L, value);
			case TClass(c) if (c == String):
				pushString(L, value);
			default:
				pushObject(L, value);
		}
	}

	function pushObject(L:LuauState, value:Dynamic):Void
	{
		var id:Null<Int> = objectIds.get(value);
		if (id != null && LuauNative.pushcached(L, id) != 0)
			return;
		LuauNative.pushobject(L, register(value));
	}

	function pushFunction(L:LuauState, fn:Dynamic):Void
	{
		// una función de Luau que volvió: se pone la original
		var ref:Null<Int> = luaFunctionRefs.get(fn);
		if (ref != null)
		{
			LuauNative.getref(L, ref);
			return;
		}
		var id:Null<Int> = objectIds.get(fn);
		if (id != null && LuauNative.pushcached(L, id) != 0)
			return;
		LuauNative.pushfunction(L, register(fn));
	}

	function register(value:Dynamic):Int
	{
		do
		{
			nextObjectId++;
			if (nextObjectId > 0x7FFFFFF0)
				nextObjectId = 1;
		}
		while (objects.exists(nextObjectId));
		objects.set(nextObjectId, value);
		objectIds.set(value, nextObjectId);
		newObjects++;
		return nextObjectId;
	}

	function release(id:Int):Void
	{
		if (!objects.exists(id))
			return;
		var value:Dynamic = objects.get(id);
		objects.remove(id);
		if (value != null && objectIds.get(value) == id)
			objectIds.remove(value);
	}

	// ------------------------------------------------------------------
	// Luau -> Haxe
	// ------------------------------------------------------------------

	function toHaxe(L:LuauState, idx:Int, level:Int = 0):Dynamic
	{
		switch (LuauNative.type(L, idx))
		{
			case LuauNative.TBOOLEAN:
				return LuauNative.toboolean(L, idx) != 0;
			case LuauNative.TNUMBER:
				return numberToHaxe(LuauNative.tonumber(L, idx));
			case LuauNative.TSTRING:
				return toString(L, idx);
			case LuauNative.TTABLE:
				return level > 32 ? null : tableToHaxe(L, LuauNative.absindex(L, idx), level + 1);
			case LuauNative.TFUNCTION:
				var id:Int = LuauNative.functionid(L, idx);
				if (id >= 0)
					return objects.get(id);
				return luaFunction(L, idx);
			case LuauNative.TOBJECT:
				return objects.get(LuauNative.objectid(L, idx));
			default:
				return null;
		}
	}

	/** Los números enteros pasan como Int (0xFFFF0000 queda como el color, igual que en Psych Lua). */
	static function numberToHaxe(n:Float):Dynamic
	{
		if (n == Math.ffloor(n))
		{
			if (n >= -2147483648.0 && n <= 2147483647.0)
				return Std.int(n);
			if (n > 2147483647.0 && n <= 4294967295.0)
				return Std.int(n - 4294967296.0);
		}
		return n;
	}

	/** {1, 2, 3} -> Array, {x = 1} -> objeto anónimo, {} -> Array vacío */
	function tableToHaxe(L:LuauState, idx:Int, level:Int):Dynamic
	{
		LuauNative.checkstack(L, 8);
		var length:Int = LuauNative.objlen(L, idx);
		var count:Int = 0;
		var isArray:Bool = true;

		LuauNative.pushnil(L);
		while (LuauNative.next(L, idx) != 0)
		{
			count++;
			if (isArray)
			{
				if (LuauNative.type(L, -2) != LuauNative.TNUMBER)
					isArray = false;
				else
				{
					var key:Float = LuauNative.tonumber(L, -2);
					if (key != Math.ffloor(key) || key < 1 || key > length)
						isArray = false;
				}
			}
			LuauNative.settop(L, -2);
		}

		if (isArray && count == length)
		{
			var list:Array<Dynamic> = [];
			for (i in 1...length + 1)
			{
				LuauNative.rawgeti(L, idx, i);
				list.push(toHaxe(L, -1, level));
				LuauNative.settop(L, -2);
			}
			return list;
		}

		var object:Dynamic = {};
		LuauNative.pushnil(L);
		while (LuauNative.next(L, idx) != 0)
		{
			var key:Dynamic = toHaxe(L, -2, level);
			Reflect.setField(object, Std.string(key), toHaxe(L, -1, level));
			LuauNative.settop(L, -2);
		}
		return object;
	}

	function luaFunction(L:LuauState, idx:Int):Dynamic
	{
		var ref:Int = LuauNative.reffunction(L, idx);
		var fn:Dynamic = luaFunctions.get(ref);
		if (fn != null)
			return fn;
		var script:FluxLuau = this;
		fn = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return script.callFunctionRef(ref, args));
		luaFunctions.set(ref, fn);
		luaFunctionRefs.set(fn, ref);
		return fn;
	}

	function collectArgs(L:LuauState, from:Int, to:Int):Array<Dynamic>
	{
		var args:Array<Dynamic> = [];
		var i:Int = from;
		while (i <= to)
		{
			args.push(toHaxe(L, i));
			i++;
		}
		return args;
	}

	// ------------------------------------------------------------------
	// Luau pide algo a Haxe
	// ------------------------------------------------------------------

	@:keep @:noCompletion
	static function luauDispatch(L:LuauState, kind:Int, id:Int):Int
	{
		var script:FluxLuau = scripts.get(LuauNative.scriptid(L));
		if (script == null || script.closed)
		{
			pushString(L, 'el script ya está cerrado');
			return -1;
		}
		return script.dispatch(L, kind, id);
	}

	@:keep @:noCompletion
	static function luauRelease(L:LuauState, id:Int):Void
	{
		var script:FluxLuau = scripts.get(LuauNative.scriptid(L));
		if (script != null)
			script.release(id);
	}

	function dispatch(L:LuauState, kind:Int, id:Int):Int
	{
		var previous:LuauState = current;
		current = L;
		inDispatch++;
		var result:Int = -1;
		try
		{
			result = handle(L, kind, id);
		}
		catch (e:Dynamic)
		{
			result = -1;
			LuauNative.checkstack(L, 2);
			pushString(L, errorText(e));
		}
		inDispatch--;
		current = previous;
		return result;
	}

	function handle(L:LuauState, kind:Int, id:Int):Int
	{
		switch (kind)
		{
			case LuauNative.KFUNC:
				var fn:Dynamic = objectOf(id);
				var result:Dynamic = Reflect.callMethod(null, fn, collectArgs(L, 1, LuauNative.gettop(L)));
				push(L, result);
				return 1;

			case LuauNative.KINDEX:
				push(L, getField(objectOf(id), toHaxe(L, 2)));
				return 1;

			case LuauNative.KNEWINDEX:
				setField(objectOf(id), toHaxe(L, 2), toHaxe(L, 3));
				return 0;

			case LuauNative.KCALL:
				var target:Dynamic = objectOf(id);
				var args:Array<Dynamic> = collectArgs(L, 2, LuauNative.gettop(L));
				if (!isClass(target))
					throw '${describe(target)} no se puede llamar como función';
				push(L, Type.createInstance(target, args));
				return 1;

			case LuauNative.KNAMECALL:
				var top:Int = LuauNative.gettop(L);
				var name:String = toString(L, top);
				var target:Dynamic = objectOf(id);
				push(L, callMethod(target, name, collectArgs(L, 2, top - 1)));
				return 1;

			case LuauNative.KTOSTRING:
				pushString(L, Std.string(objectOf(id)));
				return 1;

			case LuauNative.KLEN:
				LuauNative.pushnumber(L, lengthOf(objectOf(id)));
				return 1;

			case LuauNative.KEQ:
				var a:Dynamic = toHaxe(L, 1);
				var b:Dynamic = toHaxe(L, 2);
				LuauNative.pushboolean(L, (a == b || (Reflect.isEnumValue(a) && Reflect.isEnumValue(b) && Type.enumEq(a, b))) ? 1 : 0);
				return 1;

			case LuauNative.KITER:
				var iterator:LuauIterator = LuauIterator.of(objectOf(id));
				if (iterator == null)
					throw '${describe(objects.get(id))} no se puede recorrer con for';
				LuauNative.pushiternext(L);
				pushObject(L, iterator);
				LuauNative.pushnil(L);
				return 3;

			case LuauNative.KITERNEXT:
				var iterator:LuauIterator = objectOf(id);
				if (!iterator.advance())
				{
					LuauNative.pushnil(L);
					return 1;
				}
				push(L, iterator.key);
				push(L, iterator.value);
				return 2;

			case LuauNative.KCONCAT:
				pushString(L, textOf(toHaxe(L, 1)) + textOf(toHaxe(L, 2)));
				return 1;
		}
		throw 'operación desconocida $kind';
	}

	function objectOf(id:Int):Dynamic
	{
		if (!objects.exists(id))
			throw 'objeto de Haxe perdido (#$id)';
		return objects.get(id);
	}

	function getField(target:Dynamic, key:Dynamic):Dynamic
	{
		if (key == null)
			return null;
		if (Std.isOfType(key, Float))
		{
			if (Std.isOfType(target, Array))
			{
				// Dynamic a propósito: convertir un Array<Int> o Array<FlxSprite> a Array<Dynamic> en C++ hace una copia
				var list:Dynamic = target;
				var index:Int = Std.int(key) - 1;
				return (index >= 0 && index < list.length) ? list[index] : null;
			}
			if (Std.isOfType(target, IMap))
				return (target : IMap<Dynamic, Dynamic>).get(key);
		}

		var name:String = Std.string(key);
		if (Std.isOfType(target, IMap))
		{
			var map:IMap<Dynamic, Dynamic> = target;
			if (MAP_METHODS.contains(name))
				return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return callMapMethod(map, name, args));
			return map.get(key);
		}
		if (isClass(target) && name == 'new')
			return constructorOf(target);
		return Reflect.getProperty(target, name);
	}

	function setField(target:Dynamic, key:Dynamic, value:Dynamic):Void
	{
		if (key == null)
			throw 'no se puede usar nil como clave';
		if (Std.isOfType(key, Float))
		{
			if (Std.isOfType(target, Array))
			{
				var list:Dynamic = target;
				var length:Int = list.length;
				var index:Int = Std.int(key) - 1;
				if (index < 0 || index > length)
					throw 'posición $key fuera de la lista (tiene $length)';
				list[index] = value;
				return;
			}
			if (Std.isOfType(target, IMap))
			{
				(target : IMap<Dynamic, Dynamic>).set(key, value);
				return;
			}
		}

		var name:String = Std.string(key);
		if (Std.isOfType(target, IMap))
		{
			(target : IMap<Dynamic, Dynamic>).set(key, value);
			return;
		}
		try
		{
			Reflect.setProperty(target, name, value);
		}
		catch (e:Dynamic)
		{
			throw 'no se puede poner "$name" en ${describe(target)} (${errorText(e)})';
		}
	}

	function callMethod(target:Dynamic, name:String, args:Array<Dynamic>):Dynamic
	{
		// los Map de Haxe no se pueden usar con Reflect en C++
		if (Std.isOfType(target, IMap) && MAP_METHODS.contains(name))
			return callMapMethod(target, name, args);
		var fn:Dynamic = (isClass(target) && name == 'new') ? constructorOf(target) : Reflect.getProperty(target, name);
		if (fn == null || !Reflect.isFunction(fn))
			throw 'no existe la función "$name" en ${describe(target)}';
		return Reflect.callMethod(target, fn, args);
	}

	function constructorOf(cls:Dynamic):Dynamic
	{
		var fn:Dynamic = constructors.get(cls);
		if (fn == null)
		{
			fn = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic return Type.createInstance(cls, args));
			constructors.set(cls, fn);
		}
		return fn;
	}

	// ------------------------------------------------------------------
	// Funciones para el script
	// ------------------------------------------------------------------

	function importType(path:String):Dynamic
	{
		var value:Dynamic = resolveType(path);
		if (value == null)
		{
			FluxScript.onWarning(this, 'import: no existe "$path"');
			return null;
		}
		set(path.split('.').pop(), value);
		return value;
	}

	static function resolveType(path:String):Dynamic
	{
		if (path == null)
			return null;
		var value:Dynamic = Type.resolveClass(path);
		if (value == null)
			value = Type.resolveEnum(path);
		if (value == null && importResolver != null)
			value = importResolver(path);
		return value;
	}

	function findModule(name:String):String
	{
		if (name == null || name.length == 0)
			return null;
		var names:Array<String> = (name.endsWith('.luau') || name.endsWith('.lua')) ? [name] : [name + '.luau', name];
		var dir:String = haxe.io.Path.directory(origin);
		for (file in names)
		{
			if (dir.length > 0)
			{
				var local:String = fileResolver(dir + '/' + file);
				if (local != null)
					return local;
			}
			var found:String = fileResolver(file);
			if (found != null)
				return found;
		}
		return null;
	}

	// ------------------------------------------------------------------
	// Utilidades
	// ------------------------------------------------------------------

	static var MAP_METHODS:Array<String> = [
		'get', 'set', 'exists', 'remove', 'keys', 'values', 'iterator', 'copy', 'toString', 'clear'
	];

	static function callMapMethod(map:IMap<Dynamic, Dynamic>, name:String, args:Array<Dynamic>):Dynamic
	{
		switch (name)
		{
			case 'get':
				return map.get(args[0]);
			case 'set':
				map.set(args[0], args[1]);
				return null;
			case 'exists':
				return map.exists(args[0]);
			case 'remove':
				return map.remove(args[0]);
			case 'keys':
				return [for (k in map.keys()) k];
			case 'values' | 'iterator':
				return [for (v in map) v];
			case 'copy':
				return map.copy();
			case 'clear':
				map.clear();
				return null;
			default:
				return map.toString();
		}
	}

	static function isClass(value:Dynamic):Bool
	{
		return value != null && (Std.isOfType(value, Class) || Std.isOfType(value, Enum));
	}

	static function lengthOf(value:Dynamic):Int
	{
		if (Std.isOfType(value, Array))
		{
			var list:Dynamic = value;
			return list.length;
		}
		if (Std.isOfType(value, IMap))
		{
			var count:Int = 0;
			for (k in (value : IMap<Dynamic, Dynamic>).keys())
				count++;
			return count;
		}
		var length:Dynamic = Reflect.getProperty(value, 'length');
		return Std.isOfType(length, Int) ? length : 0;
	}

	static function describe(value:Dynamic):String
	{
		if (value == null)
			return 'nil';
		if (Std.isOfType(value, Class))
			return 'la clase ' + Type.getClassName(value);
		if (Std.isOfType(value, Enum))
			return 'el enum ' + Type.getEnumName(value);
		var cls:Class<Dynamic> = Type.getClass(value);
		if (cls != null)
			return Type.getClassName(cls);
		return 'el objeto';
	}

	static function textOf(value:Dynamic):String
	{
		return value == null ? 'nil' : Std.string(value);
	}

	static function errorText(e:Dynamic):String
	{
		if (Std.isOfType(e, haxe.Exception))
			return (e : haxe.Exception).message;
		return Std.string(e);
	}

	/**
	 * Lo que corre antes de cada script: task, wait, print, warn, require, loadstring, toTable.
	 * Devuelve las funciones que usa Haxe para llamar al script (call) y para mover task.wait (step).
	 * Cada función del script que llama Haxe corre en su propia corrutina, así task.wait anda en
	 * cualquier lado (como en Roblox).
	 */
	static var PRELUDE:String = "
local report, hxprint, hxwarn = __flux_report, __flux_print, __flux_warn
local findmodule, readfile, load = __flux_findmodule, __flux_readfile, __flux_load
__flux_report, __flux_print, __flux_warn, __flux_findmodule, __flux_readfile, __flux_load = nil, nil, nil, nil, nil, nil

local co_create, co_resume, co_status, co_running, co_yield, co_yieldable =
	coroutine.create, coroutine.resume, coroutine.status, coroutine.running, coroutine.yield, coroutine.isyieldable
local pack, unpack, insert, remove, concat = table.pack, table.unpack, table.insert, table.remove, table.concat

local clock = 0
local waiting = {}
local seq = 0

local function schedule(entry)
	seq += 1
	entry.seq = seq
	insert(waiting, entry)
end

local function earlier(a, b)
	if a.wake ~= b.wake then return a.wake < b.wake end
	return a.seq < b.seq
end

local function resume(co, ...)
	local ok, err = co_resume(co, ...)
	if not ok then report(err) end
end

local function call(fn, ...)
	local co = co_create(fn)
	local r = pack(co_resume(co, ...))
	if not r[1] then error(r[2], 0) end
	return unpack(r, 2, r.n)
end

local function step(dt)
	clock += tonumber(dt) or 0
	if #waiting == 0 then return end
	local ready = {}
	local i = 1
	while i <= #waiting do
		local w = waiting[i]
		if w.wake <= clock then
			remove(waiting, i)
			insert(ready, w)
		else
			i += 1
		end
	end
	table.sort(ready, earlier)
	for _, w in ready do
		if co_status(w.co) == 'suspended' then
			if w.args then
				resume(w.co, unpack(w.args, 1, w.args.n))
			else
				resume(w.co, clock - w.start)
			end
		end
	end
end

local function threadOf(fn)
	if type(fn) == 'thread' then return fn end
	if type(fn) ~= 'function' then error('se esperaba una función', 3) end
	return co_create(fn)
end

task = {}

function task.wait(seconds)
	if not co_yieldable() then error('task.wait no se puede usar acá', 2) end
	schedule({co = co_running(), wake = clock + (tonumber(seconds) or 0), start = clock})
	return co_yield()
end

function task.spawn(fn, ...)
	local co = threadOf(fn)
	resume(co, ...)
	return co
end

function task.defer(fn, ...)
	local co = threadOf(fn)
	schedule({co = co, wake = clock, args = pack(...)})
	return co
end

function task.delay(seconds, fn, ...)
	local co = threadOf(fn)
	schedule({co = co, wake = clock + (tonumber(seconds) or 0), args = pack(...)})
	return co
end

function task.cancel(co)
	for i = #waiting, 1, -1 do
		if waiting[i].co == co then remove(waiting, i) end
	end
end

local timerWait = wait
function wait(seconds, fn)
	if fn ~= nil and timerWait ~= nil then return timerWait(seconds, fn) end
	return task.wait(seconds)
end
spawn = task.defer
delay = task.delay

local function joinArgs(...)
	local parts = {}
	for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
	return concat(parts, '\t')
end
function print(...) hxprint(joinArgs(...)) end
function warn(...) hxwarn(joinArgs(...)) end

function loadstring(source, chunkname)
	return load(source, chunkname or '=loadstring')
end

local modules = {}
function require(name)
	if type(name) ~= 'string' then error('require: se esperaba el nombre del archivo', 2) end
	local cached = modules[name]
	if cached ~= nil then return cached end
	local path = findmodule(name)
	if path == nil then error('require: no existe \"' .. name .. '\"', 2) end
	local fn, err = load(readfile(path), '@' .. path)
	if fn == nil then error(err, 0) end
	local result = fn()
	if result == nil then result = true end
	modules[name] = result
	return result
end

local function convert(value, level)
	if typeof(value) ~= 'HaxeObject' or level > 16 then return value end
	local t = {}
	local ok = pcall(function()
		for k, v in value do t[k] = convert(v, level + 1) end
	end)
	if not ok then return value end
	return t
end
function toTable(value) return convert(value, 0) end

return call, step
";
}

/** Estado de un `for k, v in objetoDeHaxe do` */
@:keep
class LuauIterator
{
	public var key:Dynamic = null;
	public var value:Dynamic = null;

	var list:Dynamic = null; // Dynamic: así no se copia un Array<Int> o Array<FlxSprite>
	var keys:Array<Dynamic> = null;
	var values:Array<Dynamic> = null;
	var iterator:Dynamic = null;
	var position:Int = 0;

	function new() {}

	public static function of(target:Dynamic):LuauIterator
	{
		if (target == null)
			return null;
		var it:LuauIterator = new LuauIterator();
		if (Std.isOfType(target, Array))
		{
			it.list = target;
			return it;
		}
		if (Std.isOfType(target, IMap))
		{
			var map:IMap<Dynamic, Dynamic> = target;
			it.keys = [];
			it.values = [];
			for (k in map.keys())
			{
				it.keys.push(k);
				it.values.push(map.get(k));
			}
			return it;
		}
		if (Std.isOfType(target, Class) || Std.isOfType(target, Enum))
			return null;
		var iteratorFn:Dynamic = Reflect.getProperty(target, 'iterator');
		if (iteratorFn != null && Reflect.isFunction(iteratorFn))
		{
			it.iterator = Reflect.callMethod(target, iteratorFn, []);
			return it;
		}
		if (Reflect.hasField(target, 'hasNext') && Reflect.hasField(target, 'next'))
		{
			it.iterator = target;
			return it;
		}
		if (Type.getClass(target) == null && Type.typeof(target) == TObject)
		{
			it.keys = [];
			it.values = [];
			for (field in Reflect.fields(target))
			{
				it.keys.push(field);
				it.values.push(Reflect.field(target, field));
			}
			return it;
		}
		return null;
	}

	public function advance():Bool
	{
		if (list != null)
		{
			var length:Int = list.length;
			if (position >= length)
				return false;
			value = list[position];
			position++;
			key = position;
			return true;
		}
		if (iterator != null)
		{
			if (!iterator.hasNext())
				return false;
			value = iterator.next();
			position++;
			key = position;
			return true;
		}
		if (position >= keys.length)
			return false;
		key = keys[position];
		value = values[position];
		position++;
		return true;
	}
}
#end
