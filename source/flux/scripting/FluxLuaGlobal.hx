package flux.scripting;

#if LUA_GLOBAL_ALLOWED
import flixel.FlxState;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import flixel.util.FlxTimer.FlxTimerManager;
import llua.Lua;
import llua.LuaL;
import llua.State;

/**
 * Scripts `.luag`: Lua global. Es el mismo Lua de Psych (LuaJIT), pero el script
 * corre siempre, en todos los menús y canciones, sin reiniciarse (ver FluxStateScripts).
 *
 * No usa FunkinLua porque ese necesita una canción cargada. Tiene su propio
 * estado de Lua y sus propias funciones (FluxLuaGlobalFunctions), con los mismos
 * nombres que las de Psych. Las llamadas desde Lua entran por
 * psychlua.CallbackHandler, que primero pregunta si el Lua es de acá.
 *
 * - Los timers de un .luag siguen andando al cambiar de menú.
 * - Los tweens se cortan al cambiar de menú (Flixel los borra), igual que en Psych.
 * - En las canciones también recibe los callbacks de Lua de PlayState
 *   (goodNoteHit, onSongStart, onEvent...) con los mismos argumentos que un .lua.
 */
class FluxLuaGlobal extends FluxScript
{
	public static var instances(default, null):Array<FluxLuaGlobal> = [];

	/** Los timers de los .luag no se borran al cambiar de estado (los de Flixel sí). */
	public static var timerManager(get, null):FlxTimerManager;

	public var lua(default, null):State = null;
	public var callbacks(default, null):Map<String, Dynamic> = new Map();

	public var tweens(default, null):Map<String, FlxTween> = new Map();
	public var timers(default, null):Map<String, FlxTimer> = new Map();
	public var sounds(default, null):Map<String, FlxSound> = new Map();
	public var saves(default, null):Map<String, FlxSave> = new Map();

	/** Variables de getVar/setVar cuando el estado no es un MusicBeatState */
	public var looseVariables(default, null):Map<String, Dynamic> = new Map();

	/** El intérprete de runHaxeCode */
	public var haxeScript:FluxScript = null;

	var closeRequested:Bool = false;
	var depth:Int = 0;

	public function new(origin:String, code:String)
	{
		super(origin, code);
		language = 'Lua';
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		instances.push(this);
		FluxLuaGlobalFunctions.implement(this);
	}

	/** Agrega una función que Lua puede llamar (solo para este script). */
	public function addCallback(name:String, fn:Dynamic):Void
	{
		if (lua == null)
			return;
		callbacks.set(name, fn);
		Lua.add_callback_function(lua, name);
	}

	/** Lo usa psychlua.CallbackHandler para saber si un estado de Lua es de un .luag */
	public static function ofState(l:State):FluxLuaGlobal
	{
		for (script in instances)
			if (script.lua == l)
				return script;
		return null;
	}

	/** Lua llamó a una de nuestras funciones */
	public function handleCallback(l:State, name:String):Int
	{
		var fn:Dynamic = callbacks.get(name);
		if (fn == null)
			return 0;

		var args:Array<Dynamic> = [for (i in 0...Lua.gettop(l)) readValue(l, i + 1)];

		var result:Dynamic = null;
		var failure:String = null;
		try
		{
			result = Reflect.callMethod(null, fn, args);
		}
		catch (e:Dynamic)
		{
			failure = errorText(e);
		}

		if (failure != null)
		{
			// luaL_error usa el texto como formato: un "%s" suelto lo haría crashear
			LuaL.error(l, '$name: $failure'.split('%').join('%%'));
			return 0;
		}
		if (result == null)
			return 0;
		pushValue(l, result);
		return 1;
	}

	// ------------------------------------------------------------------
	// API de FluxScript
	// ------------------------------------------------------------------

	override public function execute():Bool
	{
		if (lua == null || !active || code == null)
			return false;
		var status:Int = LuaL.loadbuffer(lua, code, haxe.io.Bytes.ofString(code).length, '@' + origin);
		if (status == Lua.LUA_OK)
		{
			depth++;
			status = Lua.pcall(lua, 0, 0, 0);
			depth--;
		}
		if (status != Lua.LUA_OK)
		{
			error(popError(status));
			finish();
			return false;
		}
		finish();
		return active;
	}

	override public function exists(name:String):Bool
	{
		if (lua == null || !active)
			return false;
		Lua.getglobal(lua, name);
		var isFunction:Bool = Lua.type(lua, -1) == Lua.LUA_TFUNCTION;
		Lua.pop(lua, 1);
		return isFunction;
	}

	override public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (lua == null || !active)
			return null;

		if (name == 'onStateCreate' && args != null && args.length > 0)
			FluxLuaGlobalFunctions.updateStateVariables(this, args[0]);
		else if (name == 'onStateSwitch')
			FluxLuaGlobalFunctions.onStateSwitch(this);

		Lua.getglobal(lua, name);
		if (Lua.type(lua, -1) != Lua.LUA_TFUNCTION)
		{
			Lua.pop(lua, 1);
			return null;
		}

		var count:Int = 0;
		if (args != null)
			for (arg in args)
			{
				pushValue(lua, arg);
				count++;
			}

		depth++;
		var status:Int = Lua.pcall(lua, count, 1, 0);
		depth--;
		if (status != Lua.LUA_OK)
		{
			error('$name: ' + popError(status));
			finish();
			return null;
		}

		var result:Dynamic = readValue(lua, -1);
		Lua.pop(lua, 1);
		finish();
		return result;
	}

	override public function set(name:String, value:Dynamic):Void
	{
		if (lua == null || name == 'game') // en Lua "game" se usa como nombre (getProperty('game.x')), no como variable
			return;
		pushValue(lua, value);
		Lua.setglobal(lua, name);
	}

	override public function get(name:String):Dynamic
	{
		if (lua == null)
			return null;
		Lua.getglobal(lua, name);
		var value:Dynamic = readValue(lua, -1);
		Lua.pop(lua, 1);
		return value;
	}

	/** close() desde Lua: se cierra cuando termina la función que lo llamó. */
	public function requestClose():Void
	{
		closeRequested = true;
		active = false;
	}

	override public function destroy():Void
	{
		if (depth > 0)
		{
			requestClose();
			return;
		}

		for (tween in tweens)
			if (tween != null)
				tween.cancel();
		for (timer in timers)
			if (timer != null)
				timer.cancel();
		tweens.clear();
		timers.clear();
		sounds.clear();

		if (haxeScript != null)
		{
			haxeScript.destroy();
			haxeScript = null;
		}

		instances.remove(this);
		if (lua != null)
		{
			Lua.close(lua);
			lua = null;
		}
		super.destroy();
	}

	// ------------------------------------------------------------------

	function finish():Void
	{
		if (closeRequested && depth == 0)
		{
			closeRequested = false;
			destroy();
		}
	}

	/**
	 * Mete un valor de Haxe en la pila de Lua (siempre exactamente uno).
	 * Los estados se pasan por nombre ("MainMenuState"); lo que Lua no entiende llega como nil.
	 * No usa Convert.toLua porque ese, con un objeto raro dentro de una tabla, desarma la pila.
	 */
	static function pushValue(l:State, value:Dynamic, level:Int = 0):Void
	{
		if (value == null || level > 16 || Lua.checkstack(l, 4) == 0)
		{
			Lua.pushnil(l);
			return;
		}
		if (Std.isOfType(value, FlxState))
		{
			Lua.pushstring(l, FluxStateScripts.stateNameOf(value));
			return;
		}
		switch (Type.typeof(value))
		{
			case TBool:
				Lua.pushboolean(l, value);
			case TInt:
				Lua.pushinteger(l, value);
			case TFloat:
				Lua.pushnumber(l, value);
			case TClass(String):
				Lua.pushstring(l, value);
			case TClass(Array):
				var list:Array<Dynamic> = value;
				Lua.createtable(l, list.length, 0);
				for (i in 0...list.length)
				{
					pushValue(l, list[i], level + 1);
					Lua.rawseti(l, -2, i + 1);
				}
			case TClass(haxe.ds.StringMap) | TClass(haxe.ds.ObjectMap) | TClass(haxe.ds.IntMap):
				var map:haxe.Constraints.IMap<Dynamic, Dynamic> = value;
				Lua.createtable(l, 0, 0);
				for (key in map.keys())
				{
					Lua.pushstring(l, Std.string(key));
					pushValue(l, map.get(key), level + 1);
					Lua.rawset(l, -3);
				}
			case TObject if (!Std.isOfType(value, Class) && !Std.isOfType(value, Enum)):
				var fields:Array<String> = Reflect.fields(value);
				Lua.createtable(l, 0, fields.length);
				for (field in fields)
				{
					Lua.pushstring(l, field);
					pushValue(l, Reflect.field(value, field), level + 1);
					Lua.rawset(l, -3);
				}
			default:
				Lua.pushnil(l);
		}
	}

	/**
	 * Lee un valor de la pila de Lua sin sacarlo. Las funciones de Lua llegan como null
	 * (Convert.fromLua las saca de la pila y la deja corrida).
	 */
	static function readValue(l:State, index:Int, level:Int = 0):Dynamic
	{
		if (index < 0)
			index = Lua.gettop(l) + index + 1;
		switch (Lua.type(l, index))
		{
			case Lua.LUA_TBOOLEAN:
				return Lua.toboolean(l, index);
			case Lua.LUA_TNUMBER:
				return Lua.tonumber(l, index);
			case Lua.LUA_TSTRING:
				return Lua.tostring(l, index);
			case Lua.LUA_TTABLE if (level <= 16 && Lua.checkstack(l, 4) != 0):
				return readTable(l, index, level);
			default:
				return null;
		}
	}

	static function readTable(l:State, index:Int, level:Int):Dynamic
	{
		var count:Int = 0;
		var isList:Bool = true;
		var maxKey:Float = 0;
		Lua.pushnil(l);
		while (Lua.next(l, index) != 0)
		{
			count++;
			if (isList)
			{
				if (Lua.type(l, -2) != Lua.LUA_TNUMBER)
					isList = false;
				else
				{
					var key:Float = Lua.tonumber(l, -2);
					if (key < 1 || Std.int(key) != key)
						isList = false;
					else if (key > maxKey)
						maxKey = key;
				}
			}
			Lua.pop(l, 1);
		}

		// {[100000] = 1} no se convierte en una lista gigante
		if (count > 0 && isList && maxKey <= count * 2 + 16)
		{
			var list:Array<Dynamic> = [];
			Lua.pushnil(l);
			while (Lua.next(l, index) != 0)
			{
				list[Std.int(Lua.tonumber(l, -2)) - 1] = readValue(l, -1, level + 1);
				Lua.pop(l, 1);
			}
			return list;
		}

		var object:haxe.DynamicAccess<Dynamic> = {};
		if (count == 0)
			return object;
		Lua.pushnil(l);
		while (Lua.next(l, index) != 0)
		{
			// tostring() solo en claves que ya son texto: con un número cambiaría la clave y rompería next()
			switch (Lua.type(l, -2))
			{
				case Lua.LUA_TSTRING:
					object.set(Lua.tostring(l, -2), readValue(l, -1, level + 1));
				case Lua.LUA_TNUMBER:
					object.set(Std.string(Lua.tonumber(l, -2)), readValue(l, -1, level + 1));
				default:
			}
			Lua.pop(l, 1);
		}
		return object;
	}

	function popError(status:Int):String
	{
		var message:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);
		if (message == null || message.length == 0)
			message = switch (status)
			{
				case Lua.LUA_ERRSYNTAX: 'error de sintaxis';
				case Lua.LUA_ERRMEM: 'sin memoria';
				default: 'error';
			}
		return message;
	}

	static function errorText(e:Dynamic):String
	{
		if (Std.isOfType(e, haxe.Exception))
			return (e : haxe.Exception).message;
		return Std.string(e);
	}

	static var _timerManager:FlxTimerManager = null;

	static function get_timerManager():FlxTimerManager
	{
		if (_timerManager == null)
		{
			_timerManager = new FlxTimerManager();
			FlxG.signals.preStateSwitch.remove(_timerManager.clear);
			FlxG.plugins.addPlugin(_timerManager);
		}
		return _timerManager;
	}
}
#end
