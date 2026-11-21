// Puente entre Flux Engine y Luau (ver flux_luau_bridge.h).
// Se compila junto con Luau (C++17), nunca junto con el código de hxcpp.
#include "lua.h"
#include "lualib.h"
#include "luacode.h"

#include "flux_luau_bridge.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Tag de userdata de Luau para los objetos de Haxe
#define FLUX_TAG 100

static const char* const FLUX_OBJECTS = "flux.objects";   // id -> objeto/función (valores débiles)
static const char* const FLUX_FUNCREFS = "flux.funcrefs"; // función de Luau -> ref

static fluxluau_Dispatch g_dispatch = NULL;
static fluxluau_Release g_release = NULL;

struct FluxBox
{
    int id;
};

static int flux_boxid(lua_State* L, int idx)
{
    FluxBox* box = (FluxBox*)lua_touserdatatagged(L, idx, FLUX_TAG);
    return box != NULL ? box->id : -1;
}

static void flux_dtor(lua_State* L, void* ud)
{
    FluxBox* box = (FluxBox*)ud;
    if (g_release != NULL && box->id > 0)
        g_release(L, box->id);
}

// Llama a Haxe. Si Haxe devolvió error, lanza el error de Luau desde acá
// (nunca desde adentro de Haxe, así la excepción no pasa por código de hxcpp).
static int flux_call(lua_State* L, int kind, int id)
{
    int n = -1;
    if (g_dispatch != NULL)
        n = g_dispatch(L, kind, id);
    else
        lua_pushstring(L, "Flux: Luau no está conectado con Haxe");

    if (n < 0)
    {
        if (lua_type(L, -1) != LUA_TSTRING)
            lua_pushstring(L, "error de Haxe");
        luaL_where(L, 1);
        lua_insert(L, -2);
        lua_concat(L, 2);
        lua_error(L);
    }
    return n;
}

static int mt_index(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KINDEX, flux_boxid(L, 1));
}

static int mt_newindex(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KNEWINDEX, flux_boxid(L, 1));
}

static int mt_call(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KCALL, flux_boxid(L, 1));
}

static int mt_namecall(lua_State* L)
{
    const char* name = lua_namecallatom(L, NULL);
    if (name == NULL)
        luaL_error(L, "llamada con ':' sin nombre de función");
    lua_pushstring(L, name);
    return flux_call(L, FLUXLUAU_KNAMECALL, flux_boxid(L, 1));
}

static int mt_tostring(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KTOSTRING, flux_boxid(L, 1));
}

static int mt_len(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KLEN, flux_boxid(L, 1));
}

static int mt_eq(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KEQ, flux_boxid(L, 1));
}

static int mt_iter(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KITER, flux_boxid(L, 1));
}

static int mt_concat(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KCONCAT, -1);
}

static int fn_haxe(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KFUNC, flux_boxid(L, lua_upvalueindex(1)));
}

static int fn_iternext(lua_State* L)
{
    return flux_call(L, FLUXLUAU_KITERNEXT, flux_boxid(L, 1));
}

// __flux_load(codigo, nombre) -> función | nil, error   (lo usan require y loadstring)
static int fn_load(lua_State* L)
{
    size_t length = 0;
    const char* source = luaL_checklstring(L, 1, &length);
    const char* chunkname = luaL_optstring(L, 2, "=loadstring");
    if (fluxluau_load(L, chunkname, source, (int)length) != 0)
    {
        lua_pushnil(L);
        lua_insert(L, -2);
        return 2;
    }
    return 1;
}

static void flux_cache(lua_State* L, int id)
{
    lua_rawgetfield(L, LUA_REGISTRYINDEX, FLUX_OBJECTS);
    lua_pushvalue(L, -2);
    lua_rawseti(L, -2, id);
    lua_pop(L, 1);
}

static void flux_setfn(lua_State* L, const char* name, lua_CFunction fn)
{
    lua_pushcfunction(L, fn, name);
    lua_setfield(L, -2, name);
}

extern "C" {

void fluxluau_setcallbacks(fluxluau_Dispatch dispatch, fluxluau_Release release)
{
    g_dispatch = dispatch;
    g_release = release;
}

void* fluxluau_newstate(int scriptId)
{
    lua_State* L = luaL_newstate();
    if (L == NULL)
        return NULL;

    lua_callbacks(L)->userdata = (void*)(intptr_t)scriptId;
    luaL_openlibs(L);
    lua_setuserdatadtor(L, FLUX_TAG, flux_dtor);

    // metatabla de los objetos de Haxe
    lua_createtable(L, 0, 12);
    flux_setfn(L, "__index", mt_index);
    flux_setfn(L, "__newindex", mt_newindex);
    flux_setfn(L, "__call", mt_call);
    flux_setfn(L, "__namecall", mt_namecall);
    flux_setfn(L, "__tostring", mt_tostring);
    flux_setfn(L, "__len", mt_len);
    flux_setfn(L, "__eq", mt_eq);
    flux_setfn(L, "__iter", mt_iter);
    flux_setfn(L, "__concat", mt_concat);
    lua_pushstring(L, "HaxeObject");
    lua_setfield(L, -2, "__type");
    lua_pushstring(L, "HaxeObject");
    lua_setfield(L, -2, "__metatable");
    lua_setuserdatametatable(L, FLUX_TAG);

    // caché débil: el mismo objeto de Haxe -> el mismo valor de Luau mientras siga vivo
    lua_createtable(L, 0, 0);
    lua_createtable(L, 0, 1);
    lua_pushstring(L, "v");
    lua_setfield(L, -2, "__mode");
    lua_setmetatable(L, -2);
    lua_rawsetfield(L, LUA_REGISTRYINDEX, FLUX_OBJECTS);

    lua_createtable(L, 0, 0);
    lua_rawsetfield(L, LUA_REGISTRYINDEX, FLUX_FUNCREFS);

    lua_pushcfunction(L, fn_load, "__flux_load");
    lua_rawsetfield(L, LUA_GLOBALSINDEX, "__flux_load");
    return L;
}

void fluxluau_close(void* L)
{
    if (L != NULL)
        lua_close((lua_State*)L);
}

int fluxluau_scriptid(void* L)
{
    return (int)(intptr_t)lua_callbacks((lua_State*)L)->userdata;
}

int fluxluau_load(void* p, const char* chunkname, const char* source, int length)
{
    lua_State* L = (lua_State*)p;
    lua_CompileOptions options = {};
    options.optimizationLevel = 1;
    options.debugLevel = 1;
    size_t size = 0;
    size_t sourceLength = length < 0 ? strlen(source) : (size_t)length;
    char* bytecode = luau_compile(source, sourceLength, &options, &size);
    int status = luau_load(L, chunkname, bytecode, size, 0);
    free(bytecode);
    return status;
}

int fluxluau_pcall(void* L, int nargs, int nresults)
{
    return lua_pcall((lua_State*)L, nargs, nresults, 0);
}

int fluxluau_gettop(void* L)
{
    return lua_gettop((lua_State*)L);
}

void fluxluau_settop(void* L, int idx)
{
    lua_settop((lua_State*)L, idx);
}

int fluxluau_absindex(void* L, int idx)
{
    return lua_absindex((lua_State*)L, idx);
}

int fluxluau_type(void* p, int idx)
{
    lua_State* L = (lua_State*)p;
    switch (lua_type(L, idx))
    {
    case LUA_TNONE:
    case LUA_TNIL:
        return FLUXLUAU_TNIL;
    case LUA_TBOOLEAN:
        return FLUXLUAU_TBOOLEAN;
    case LUA_TNUMBER:
        return FLUXLUAU_TNUMBER;
    case LUA_TSTRING:
        return FLUXLUAU_TSTRING;
    case LUA_TTABLE:
        return FLUXLUAU_TTABLE;
    case LUA_TFUNCTION:
        return FLUXLUAU_TFUNCTION;
    case LUA_TVECTOR:
        return FLUXLUAU_TVECTOR;
    case LUA_TUSERDATA:
        return lua_userdatatag(L, idx) == FLUX_TAG ? FLUXLUAU_TOBJECT : FLUXLUAU_TOTHER;
    default:
        return FLUXLUAU_TOTHER;
    }
}

int fluxluau_toboolean(void* L, int idx)
{
    return lua_toboolean((lua_State*)L, idx);
}

double fluxluau_tonumber(void* L, int idx)
{
    return lua_tonumber((lua_State*)L, idx);
}

const char* fluxluau_tolstring(void* p, int idx, int* length)
{
    lua_State* L = (lua_State*)p;
    if (lua_type(L, idx) != LUA_TSTRING)
    {
        if (length != NULL)
            *length = -1;
        return NULL;
    }
    size_t len = 0;
    const char* s = lua_tolstring(L, idx, &len);
    if (length != NULL)
        *length = (int)len;
    return s;
}

int fluxluau_objectid(void* p, int idx)
{
    return flux_boxid((lua_State*)p, idx);
}

int fluxluau_functionid(void* p, int idx)
{
    lua_State* L = (lua_State*)p;
    if (lua_type(L, idx) != LUA_TFUNCTION || lua_tocfunction(L, idx) != fn_haxe)
        return -1;
    if (lua_getupvalue(L, idx, 1) == NULL)
        return -1;
    int id = flux_boxid(L, -1);
    lua_pop(L, 1);
    return id;
}

void fluxluau_pushnil(void* L)
{
    lua_pushnil((lua_State*)L);
}

void fluxluau_pushboolean(void* L, int value)
{
    lua_pushboolean((lua_State*)L, value);
}

void fluxluau_pushnumber(void* L, double value)
{
    lua_pushnumber((lua_State*)L, value);
}

void fluxluau_pushstring(void* L, const char* value)
{
    if (value == NULL)
        lua_pushnil((lua_State*)L);
    else
        lua_pushstring((lua_State*)L, value);
}

void fluxluau_pushvalue(void* L, int idx)
{
    lua_pushvalue((lua_State*)L, idx);
}

void fluxluau_pushobject(void* p, int id)
{
    lua_State* L = (lua_State*)p;
    FluxBox* box = (FluxBox*)lua_newuserdatataggedwithmetatable(L, sizeof(FluxBox), FLUX_TAG);
    box->id = id;
    flux_cache(L, id);
}

void fluxluau_pushfunction(void* p, int id)
{
    lua_State* L = (lua_State*)p;
    FluxBox* box = (FluxBox*)lua_newuserdatataggedwithmetatable(L, sizeof(FluxBox), FLUX_TAG);
    box->id = id;
    lua_pushcclosure(L, fn_haxe, "haxe", 1);
    flux_cache(L, id);
}

int fluxluau_pushcached(void* p, int id)
{
    lua_State* L = (lua_State*)p;
    lua_rawgetfield(L, LUA_REGISTRYINDEX, FLUX_OBJECTS);
    lua_rawgeti(L, -1, id);
    if (lua_isnil(L, -1))
    {
        lua_pop(L, 2);
        return 0;
    }
    lua_remove(L, -2);
    return 1;
}

void fluxluau_pushiternext(void* L)
{
    lua_pushcfunction((lua_State*)L, fn_iternext, "next");
}

void fluxluau_getglobal(void* L, const char* name)
{
    lua_rawgetfield((lua_State*)L, LUA_GLOBALSINDEX, name);
}

void fluxluau_setglobal(void* L, const char* name)
{
    lua_rawsetfield((lua_State*)L, LUA_GLOBALSINDEX, name);
}

int fluxluau_reffunction(void* p, int idx)
{
    lua_State* L = (lua_State*)p;
    idx = lua_absindex(L, idx);
    lua_rawgetfield(L, LUA_REGISTRYINDEX, FLUX_FUNCREFS);
    lua_pushvalue(L, idx);
    lua_rawget(L, -2);
    if (lua_type(L, -1) == LUA_TNUMBER)
    {
        int ref = (int)lua_tonumber(L, -1);
        lua_pop(L, 2);
        return ref;
    }
    lua_pop(L, 1);
    int ref = lua_ref(L, idx);
    lua_pushvalue(L, idx);
    lua_pushnumber(L, (double)ref);
    lua_rawset(L, -3);
    lua_pop(L, 1);
    return ref;
}

void fluxluau_getref(void* L, int ref)
{
    lua_getref((lua_State*)L, ref);
}

void fluxluau_unref(void* p, int ref)
{
    lua_State* L = (lua_State*)p;
    lua_rawgetfield(L, LUA_REGISTRYINDEX, FLUX_FUNCREFS);
    lua_getref(L, ref);
    if (!lua_isnil(L, -1))
    {
        lua_pushnil(L);
        lua_rawset(L, -3);
    }
    else
        lua_pop(L, 1);
    lua_pop(L, 1);
    lua_unref(L, ref);
}

void fluxluau_newtable(void* L, int narr, int nrec)
{
    lua_createtable((lua_State*)L, narr, nrec);
}

void fluxluau_collect(void* L)
{
    lua_gc((lua_State*)L, LUA_GCCOLLECT, 0);
}

int fluxluau_memorykb(void* L)
{
    return lua_gc((lua_State*)L, LUA_GCCOUNT, 0);
}

int fluxluau_checkstack(void* L, int size)
{
    return lua_checkstack((lua_State*)L, size);
}

int fluxluau_rawgeti(void* L, int idx, int n)
{
    lua_rawgeti((lua_State*)L, idx, n);
    return fluxluau_type(L, -1);
}

void fluxluau_rawseti(void* L, int idx, int n)
{
    lua_rawseti((lua_State*)L, idx, n);
}

void fluxluau_rawsetfield(void* L, int idx, const char* k)
{
    lua_rawsetfield((lua_State*)L, idx, k);
}

int fluxluau_objlen(void* L, int idx)
{
    return lua_objlen((lua_State*)L, idx);
}

int fluxluau_next(void* L, int idx)
{
    return lua_next((lua_State*)L, idx);
}

} // extern "C"
