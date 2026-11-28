# ZS Script (`.zs`) de ZS Engine

Transpilador de ZS a Lua de [ZS Engine](https://github.com/SuperHero2010/FNF-ZSEngine) por SuperHero2010,
copiado de `source/zsscript/` en el commit `9515e3ad3c323788e857ea1405f0cd981a8ab67c` (2026-11-24).
Licencia Apache 2.0 (ver `LICENSE`).

Cambios de Flux Engine:
- `ZSTranspiler.hx`: usa `zsscript.ZSDebugger` (nuevo, en esta carpeta) en vez de `debug.ZSDebugger`,
  y `ZSDebugger.enabled` en vez de `ClientPrefs.data.zsDebugger`.
- `ZSTranspiler.hx`: los 4 `trace(...)` de depuración (splitArgs, bloques) pasan por
  `ZSDebugger.logTranspiler`, así no llenan la consola cada vez que se carga un script.

Lo demás está igual. Flux pasa el `.zs` a Lua con `ZSTranspiler.transpile` y lo corre como un script
de Lua de Psych (ver `source/flux/scripting/FluxZS.hx`).
