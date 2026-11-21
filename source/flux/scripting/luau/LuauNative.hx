package flux.scripting.luau;

#if (cpp && LUAU_ALLOWED)
/** Un `lua_State*` de Luau (o de una corrutina). */
typedef LuauState = cpp.RawPointer<cpp.Void>;

/**
 * Funciones de `flux_luau_bridge.h` (source/flux/vendor/luau/bridge).
 * Las que usan strings están en FluxLuau con `untyped __cpp__`.
 */
@:include('flux_luau_bridge.h')
extern class LuauNative
{
	public static inline var TNIL:Int = 0;
	public static inline var TBOOLEAN:Int = 1;
	public static inline var TNUMBER:Int = 2;
	public static inline var TSTRING:Int = 3;
	public static inline var TTABLE:Int = 4;
	public static inline var TFUNCTION:Int = 5;
	public static inline var TOBJECT:Int = 6;
	public static inline var TOTHER:Int = 7;
	public static inline var TVECTOR:Int = 8;

	public static inline var KFUNC:Int = 0;
	public static inline var KINDEX:Int = 1;
	public static inline var KNEWINDEX:Int = 2;
	public static inline var KCALL:Int = 3;
	public static inline var KNAMECALL:Int = 4;
	public static inline var KTOSTRING:Int = 5;
	public static inline var KLEN:Int = 6;
	public static inline var KEQ:Int = 7;
	public static inline var KITER:Int = 8;
	public static inline var KITERNEXT:Int = 9;
	public static inline var KCONCAT:Int = 10;

	@:native('fluxluau_newstate') static function newstate(scriptId:Int):LuauState;
	@:native('fluxluau_close') static function close(L:LuauState):Void;
	@:native('fluxluau_scriptid') static function scriptid(L:LuauState):Int;
	@:native('fluxluau_pcall') static function pcall(L:LuauState, nargs:Int, nresults:Int):Int;
	@:native('fluxluau_gettop') static function gettop(L:LuauState):Int;
	@:native('fluxluau_settop') static function settop(L:LuauState, idx:Int):Void;
	@:native('fluxluau_absindex') static function absindex(L:LuauState, idx:Int):Int;
	@:native('fluxluau_checkstack') static function checkstack(L:LuauState, size:Int):Int;
	@:native('fluxluau_collect') static function collect(L:LuauState):Void;
	@:native('fluxluau_memorykb') static function memorykb(L:LuauState):Int;
	@:native('fluxluau_type') static function type(L:LuauState, idx:Int):Int;
	@:native('fluxluau_toboolean') static function toboolean(L:LuauState, idx:Int):Int;
	@:native('fluxluau_tonumber') static function tonumber(L:LuauState, idx:Int):Float;
	@:native('fluxluau_objectid') static function objectid(L:LuauState, idx:Int):Int;
	@:native('fluxluau_functionid') static function functionid(L:LuauState, idx:Int):Int;
	@:native('fluxluau_pushnil') static function pushnil(L:LuauState):Void;
	@:native('fluxluau_pushboolean') static function pushboolean(L:LuauState, value:Int):Void;
	@:native('fluxluau_pushnumber') static function pushnumber(L:LuauState, value:Float):Void;
	@:native('fluxluau_pushvalue') static function pushvalue(L:LuauState, idx:Int):Void;
	@:native('fluxluau_pushobject') static function pushobject(L:LuauState, id:Int):Void;
	@:native('fluxluau_pushfunction') static function pushfunction(L:LuauState, id:Int):Void;
	@:native('fluxluau_pushcached') static function pushcached(L:LuauState, id:Int):Int;
	@:native('fluxluau_pushiternext') static function pushiternext(L:LuauState):Void;
	@:native('fluxluau_reffunction') static function reffunction(L:LuauState, idx:Int):Int;
	@:native('fluxluau_getref') static function getref(L:LuauState, ref:Int):Void;
	@:native('fluxluau_unref') static function unref(L:LuauState, ref:Int):Void;
	@:native('fluxluau_newtable') static function newtable(L:LuauState, narr:Int, nrec:Int):Void;
	@:native('fluxluau_rawgeti') static function rawgeti(L:LuauState, idx:Int, n:Int):Int;
	@:native('fluxluau_rawseti') static function rawseti(L:LuauState, idx:Int, n:Int):Void;
	@:native('fluxluau_objlen') static function objlen(L:LuauState, idx:Int):Int;
	@:native('fluxluau_next') static function next(L:LuauState, idx:Int):Int;
}
#end
