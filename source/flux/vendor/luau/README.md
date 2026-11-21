# Luau dentro de Flux Engine

[Luau](https://github.com/luau-lang/luau) (el Lua de Roblox, licencia MIT: `LICENSE.txt` y `lua_LICENSE.txt`) compilado dentro del juego para los scripts `.luau`.

- `Common/`, `Ast/`, `Bytecode/`, `Compiler/`, `VM/`: copia sin cambios de esas carpetas de Luau (solo `include/` y `src/`).
- `bridge/`: el puente entre Haxe y Luau. `flux_luau_bridge.h` no incluye nada de Luau, así el código de hxcpp nunca ve el `lua.h` de Luau y no choca con el de LuaJIT que usa Psych.
- `cxx/`: un `.cxx` por cada `.cpp` de Luau. hxcpp 4.3 les agrega `-std=c++11` a los `.cpp` en Linux, Mac y MinGW, y Luau necesita C++17; a los `.cxx` no les agrega nada.
- `luau.xml`: la compilación con hxcpp. Lo incluye `flux.scripting.FluxLuau` con `@:buildXml` (ver `source/flux/scripting/luau/LuauBuild.hx`).

El lado de Haxe está en `source/flux/scripting/FluxLuau.hx`.

Para actualizar Luau: reemplazar las carpetas `include/` y `src/` de `Common`, `Ast`, `Bytecode`, `Compiler` y `VM` con las de la versión nueva, y si cambió la lista de `.cpp` (ver `Sources.cmake` de Luau), agregar o quitar los `.cxx` de `cxx/` y las líneas de `luau.xml`.
