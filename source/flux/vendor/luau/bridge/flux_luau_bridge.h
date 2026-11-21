// Puente entre Flux Engine (Haxe/hxcpp) y Luau.
//
// Este header NO incluye nada de Luau a propósito: así el código que genera
// hxcpp nunca ve el lua.h de Luau y no choca con el lua.h de LuaJIT (linc_luajit),
// que Psych usa para los .lua normales. Todo se maneja con void* y enteros.
#ifndef FLUX_LUAU_BRIDGE_H
#define FLUX_LUAU_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// Tipos que devuelve fluxluau_type
#define FLUXLUAU_TNIL 0
#define FLUXLUAU_TBOOLEAN 1
#define FLUXLUAU_TNUMBER 2
#define FLUXLUAU_TSTRING 3
#define FLUXLUAU_TTABLE 4
#define FLUXLUAU_TFUNCTION 5
#define FLUXLUAU_TOBJECT 6 // un objeto de Haxe envuelto por Flux
#define FLUXLUAU_TOTHER 7  // hilos, buffers, userdata ajenos...
#define FLUXLUAU_TVECTOR 8

// Lo que Luau le pide a Haxe (el "kind" de fluxluau_Dispatch)
#define FLUXLUAU_KFUNC 0     // llamar una función de Haxe
#define FLUXLUAU_KINDEX 1    // obj[key]
#define FLUXLUAU_KNEWINDEX 2 // obj[key] = value
#define FLUXLUAU_KCALL 3     // obj(...)
#define FLUXLUAU_KNAMECALL 4 // obj:metodo(...)  (el nombre queda arriba de todo en la pila)
#define FLUXLUAU_KTOSTRING 5
#define FLUXLUAU_KLEN 6
#define FLUXLUAU_KEQ 7
#define FLUXLUAU_KITER 8     // for k, v in obj do
#define FLUXLUAU_KITERNEXT 9
#define FLUXLUAU_KCONCAT 10

// Devuelve cuántos valores dejó en la pila, o -1 si hubo error (con el mensaje arriba de todo).
typedef int (*fluxluau_Dispatch)(void* L, int kind, int id);
// Luau liberó el objeto "id" (el recolector de basura de Luau ya no lo usa).
typedef void (*fluxluau_Release)(void* L, int id);

void fluxluau_setcallbacks(fluxluau_Dispatch dispatch, fluxluau_Release release);

void* fluxluau_newstate(int scriptId);
void fluxluau_close(void* L);
int fluxluau_scriptid(void* L);

// Compila y carga código (length < 0 = hasta el \0). 0 = ok (deja la función en la pila), otro = error (deja el mensaje).
int fluxluau_load(void* L, const char* chunkname, const char* source, int length);
// lua_pcall. 0 = ok; si no, deja el mensaje de error.
int fluxluau_pcall(void* L, int nargs, int nresults);

int fluxluau_gettop(void* L);
void fluxluau_settop(void* L, int idx);
int fluxluau_absindex(void* L, int idx);
int fluxluau_type(void* L, int idx);
int fluxluau_toboolean(void* L, int idx);
double fluxluau_tonumber(void* L, int idx);
// Solo para strings (no convierte números). Si no es string devuelve NULL y length = -1.
const char* fluxluau_tolstring(void* L, int idx, int* length);
// Id del objeto de Haxe, o -1 si ese valor no es un objeto de Flux
int fluxluau_objectid(void* L, int idx);
// Id de la función de Haxe que envuelve ese valor, o -1 si es una función de Luau
int fluxluau_functionid(void* L, int idx);

void fluxluau_pushnil(void* L);
void fluxluau_pushboolean(void* L, int value);
void fluxluau_pushnumber(void* L, double value);
void fluxluau_pushstring(void* L, const char* value);
void fluxluau_pushvalue(void* L, int idx);
// Crea un objeto nuevo de Flux con ese id (y lo guarda en la caché débil)
void fluxluau_pushobject(void* L, int id);
// Crea una función de Luau que llama a la función de Haxe con ese id
void fluxluau_pushfunction(void* L, int id);
// Pone el objeto/función ya creado para ese id. Devuelve 0 (y no pone nada) si ya no existe.
int fluxluau_pushcached(void* L, int id);
// La función "next" que usa __iter
void fluxluau_pushiternext(void* L);

void fluxluau_getglobal(void* L, const char* name);
void fluxluau_setglobal(void* L, const char* name);

// Referencia fija a una función de Luau (siempre el mismo número para la misma función)
int fluxluau_reffunction(void* L, int idx);
void fluxluau_getref(void* L, int ref);
void fluxluau_unref(void* L, int ref);

int fluxluau_checkstack(void* L, int size);
// Recolección completa (Luau no ve cuánta memoria de Haxe sostiene cada objeto)
void fluxluau_collect(void* L);
int fluxluau_memorykb(void* L);
void fluxluau_newtable(void* L, int narr, int nrec);
// Pone t[n] en la pila y devuelve su tipo
int fluxluau_rawgeti(void* L, int idx, int n);
// t[n] = valor de arriba (lo saca de la pila)
void fluxluau_rawseti(void* L, int idx, int n);
// t[k] = valor de arriba (lo saca de la pila)
void fluxluau_rawsetfield(void* L, int idx, const char* k);
int fluxluau_objlen(void* L, int idx);
// lua_next: deja clave y valor, devuelve 0 cuando termina
int fluxluau_next(void* L, int idx);

#ifdef __cplusplus
}
#endif

#endif
