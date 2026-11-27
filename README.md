# Flux Engine

Fork de **Psych Engine 1.0.4** con más lenguajes de scripting, compatibilidad con mods de **V-Slice** y **Codename Engine**, **multi-keys** (4 a 17 teclas), **modcharts** (FunkinModchart) y charts de **osu!mania, StepMania, Quaver y Codename** (Moonchart).

## Scripting de Flux Engine

| Lenguaje | Extensión | Librería |
|---|---|---|
| Lua | `.lua` | linc_luajit (Psych) |
| HScript | `.hx`, `.hscript` | hscript-iris (Psych). `.hscript` es lo mismo que `.hx` (como en otros engines) |
| NXScript | `.nx`, `.nxs` | [nxscript 0.5.8](https://github.com/senioritaelizabeth/NxScript) |
| RuleScript | `.rhx` | [rulescript 0.2.0](https://github.com/Kriptel/RuleScript) + hscript 2.6.0 |
| hscript-plus | `.hsp` | [hscript-plus](https://github.com/DleanJeans/hscript-plus) (incluido en `source/flux/vendor/hsplus`) |
| HScript expandido | `.hxs` | [hscript-improved](https://github.com/CodenameCrew/hscript-improved) de Codename Engine (incluido en `source/flux/vendor/hsimproved`) |
| Luau | `.luau` | [Luau](https://github.com/luau-lang/luau), el Lua de Roblox (incluido en `source/flux/vendor/luau`, se compila con el juego) |
| SScript | `.ss` | [SScript 24.0.0](https://github.com/ThomasDarkson/SScript) (incluido en `source/flux/vendor/sscript`, se compila con el juego) |
| FluxScript | `.flux` | [FluxScript](https://github.com/darnellpsych-funkin/FluxScript), el addon de HScript de Flux (incluido en `source/flux/vendor/fluxscript`) |
| Globales | `.hxsg`, `.luaug`, `.ssg`, `.fluxg`... y `.luag` | Los mismos lenguajes, pero corren en todo el juego (ver abajo) |

Los scripts nuevos se cargan en los mismos lugares que los `.hx`: `scripts/`, `data/<canción>/`, `stages/`, `characters/`, `custom_notetypes/` y `custom_events/`. Reciben los mismos callbacks (`onCreate`, `onCreatePost`, `onUpdate`, `onBeatHit`, `goodNoteHit`, ...) y las mismas variables (`game`, `FlxG`, `FlxSprite`, `FlxTween`, `PlayState`, `setVar`, `debugPrint`, `Function_Stop`, ...). Corren después de HScript y respetan `Function_StopHScript` / `Function_StopAll`. Para cambiar valores del juego usa `game.` (`game.health`, `game.combo`...).

- **NXScript**: sus diccionarios `{...}` y funciones se convierten a `null` al pasarlos a Haxe; usa `toHaxe(valor)` para pasarlos (ej. `FlxTween.tween(spr, toHaxe({"alpha": 0}), 1)`). Las funciones del preset (`setVar`, `debugPrint`...) ya lo hacen solas.
- **RuleScript**: los campos del PlayState (`boyfriend`, `camGame`, `add(...)`...) se pueden leer directo. Soporta `import ... as`, `using`, propiedades, interpolación `'${x}'`, `??=` y clases en script.
- **hscript-plus**: agrega clases con herencia (`class Jefe extends Enemigo`). Es una versión vieja de hscript (2017): no tiene `() -> {}`, `?.` ni `??`. Dentro de una clase usa `campo = campo + 1` en vez de `+=`. Flux corrige un bug del original que evaluaba dos veces el lado derecho de `a = b`.
- **HScript expandido (`.hxs`)**: el más completo, ver la sección de abajo.
- **Luau (`.luau`)**: Lua con los objetos del juego directo (`game.boyfriend.alpha = 0.5`), ver la sección de abajo.
- **SScript (`.ss`)**: HScript que corre en su propia máquina virtual de C++ (rápido), ver la sección de abajo.
- **FluxScript (`.flux`)**: nuestro propio lenguaje, el HScript de Psych con cosas extra, ver la sección de abajo.

### HScript expandido (`.hxs`)

Usa el hscript-improved de Codename Engine y trae mucho más listo para usar:

- **Lenguaje**: clases propias (`class Enemigo { ... }`), herencia entre ellas con `super`, `static`, propiedades `(get, set)`, `is` (también con herencia), `enum` con argumentos y `switch` sobre ellos, `import` y `import ... as`, `using StringTools;`, `final`, regex `~/.../`, `?.`, `??`, `'${interpolación}'` y `for (k => v in mapa)`.
- **Los campos del estado se usan directo**: `boyfriend`, `health`, `camHUD`, `add(...)`... (igual que `game.boyfriend`).
- **`static var`** se comparten entre todos los `.hxs` y duran toda la sesión (sirven para contar partidas, guardar cosas entre canciones, etc.).
- **`import` que no existe**: no corta el script; avisa en amarillo y la variable queda en `null`. Algunos nombres de Codename y de V-Slice se cambian solos por los de Psych (`funkin.game.PlayState`, `funkin.backend.assets.Paths`, `funkin.Conductor`...).
- **Clases sin `import`**: casi todo Flixel (`FlxSprite`, `FlxText`, `FlxGroup`, `FlxSpriteGroup`, `FlxBackdrop`, `FlxTrail`, `FlxBar`, `FlxPoint`, `FlxRect`, `FlxSound`, `FlxGradient`, `FlxAxes`, `FlxTweenType`...), OpenFL (`BitmapData`, `BlurFilter`, `GlowFilter`, `ColorMatrixFilter`, `Matrix`, `BlendMode`...), Haxe (`Json`, `Reflect`, `Lambda`, `Date`, `DateTools`, `EReg`, `Timer`) y Psych (`Paths`, `Conductor`, `ClientPrefs`, `CoolUtil`, `Character`, `Note`, `StrumNote`, `HealthIcon`, `Bar`, `BGSprite`, `Song`, `WeekData`, `Highscore`, `Mods`, los menús, `PauseSubState`, `GameOverSubstate`...).

Funciones extra:

| Función | Qué hace |
|---|---|
| `getProperty('boyfriend.scale.x')` / `setProperty('dad.visible', false)` | Como en Lua (también `notes.members[0].alpha` y las variables de `setVar`) |
| `getPropertyFromClass('backend.ClientPrefs', 'data.downScroll')` / `setPropertyFromClass(...)` | Igual, en una clase |
| `makeSprite(x, y, 'imagen')` / `makeAnimatedSprite(x, y, 'atlas')` / `makeText(x, y, ancho, 'texto', 24)` | Crea sprites y texto (para agregarlos usa `add`) |
| `addAnim(sprite, 'idle', 'prefijo', 24, true)` / `playAnim(sprite, 'idle', true)` | Animaciones (`addAnim(..., '0,1,2')` usa índices) |
| `screenCenter(objeto, 'xy')` | Centra en pantalla (`'x'`, `'y'` o `'xy'`) |
| `tween(objeto, {alpha: 0}, 1, 'quadOut', fin)` / `tweenColor(objeto, 1, desde, hasta)` / `cancelTweens(objeto)` | Tweens con el nombre del ease como en Lua |
| `timer(1.5, function(t) {...}, 3)` / `wait(1, function() {...})` | Timers |
| `playSound('nombre', 0.7)` / `playMusic('nombre')` / `precacheImage(...)`, `precacheSound(...)`, `precacheMusic(...)` | Sonido |
| `getCamera('hud')` / `cameraShake('game', 0.01, 0.2)` / `cameraFlash('hud', color, 0.5)` / `cameraFade(...)` | Cámaras (`'game'`, `'hud'` u `'other'`) |
| `color('#FF0000')` / `lerp(a, b, t)` / `clamp(v, min, max)` / `randomInt(0, 10)` / `randomFloat(0, 1)` / `randomBool(50)` | Números y colores |
| `fileExists('data/x.json')` / `readFile('data/x.txt')` / `parseJson(texto)` / `toJson(valor, true)` | Archivos del mod y JSON |
| `callOnScripts('func', [args])` / `callOnLuas(...)` / `setOnScripts('var', valor)` / `triggerEvent('Hey!', 'bf', '0.6')` | Otros scripts y eventos (en las canciones) |
| `importScript('scripts/utilidades')` | Corre otro `.hxs` dentro de este (comparten variables y funciones) |
| `switchState('MainMenuState')` / `resetState()` / `openCustomSubstate('nombre', true)` | Cambiar de menú (también menús hechos con script, ver abajo) |
| `mouseX()`, `mouseY()`, `mouseClicked()`, `mousePressed()`, `mouseReleased()`, `mouseOverlaps(sprite)` | Mouse |

Desde Lua: `runHScriptImproved(código, ?función, ?argumentos)` y `runFluxFunction('hxs', función, argumentos)`.

### Luau (`.luau`)

[Luau](https://luau.org) es el Lua de Roblox. Va compilado dentro del juego (no necesita haxelib) y el código Lua corre en su propia máquina virtual de C++. A diferencia de los `.lua` de Psych, los objetos del juego **se usan directo**, sin `getProperty`/`setProperty`:

```lua
game.boyfriend.alpha = 0.5               -- leer y cambiar campos
local spr = FlxSprite.new(100, 100)      -- crear objetos (o FlxSprite(100, 100))
spr:makeGraphic(50, 50, 0xFFFF0000)      -- métodos con ':' (también anda con '.')
game:add(spr)
spr.cameras = {game.camHUD}              -- las tablas se convierten solas (lista o {x = 1})
for i, strum in game.opponentStrums.members do strum.alpha = 0.5 end
texto.text = `Puntos: {game.songScore}`  -- interpolación de Luau
```

- **Mismo preset que los `.hxs`**: `game`, `FlxG`, `Paths`, `Conductor`, casi todo Flixel/OpenFL/Psych y las funciones (`makeText`, `tween`, `playSound`, `getVar`/`setVar`, `debugPrint`, `color`, `switchState`...). Mismos callbacks y lugares que los demás scripts, también menús (`states/<Menú>.luau`) y globales (`scripts/global/*.luau`).
- **Listas y mapas de Haxe**: `#lista`, `lista[1]` (**empiezan en 1**, como en Lua), `lista:push(x)`, `mapa.clave` / `mapa:exists('clave')`, y `for k, v in objeto do` en listas, mapas, grupos y objetos. `toTable(lista)` las copia a una tabla normal de Luau (para `table.insert`, `ipairs`...).
- **Funciones de Luau en Haxe**: se pueden pasar como callbacks (`FlxTimer.new():start(1, function(t) ... end)`, `{onComplete = function() ... end}` en los tweens, señales...).
- **Como en Roblox**: `task.wait(seg)`, `task.spawn`, `task.delay`, `task.defer`, `task.cancel`, `wait(seg)`, `print`, `warn` y `typeof`. `task.wait` funciona en cualquier función del script: pausa solo esa función y sigue sola (se mueve con `onUpdate`, así que en pausa también se pausa).
- **Extras**: `require('utilidades')` carga `utilidades.luau` (primero al lado del script, después en el mod), `import('flixel.addons.display.FlxBackdrop')` trae cualquier clase, `loadstring(código)` e `importScript('scripts/otro')`.
- Los números enteros llegan a Haxe como `Int` (`0xFFFF0000` sirve como color). Los errores muestran el archivo y la línea; el script sigue funcionando.

Desde Lua: `runLuau(código, ?función, ?argumentos)` y `runFluxFunction('luau', función, argumentos)`.

Ejemplos: [`ejemplo.luau`](docs/flux-examples/ejemplo.luau) (usa [`utilidades.luau`](docs/flux-examples/utilidades.luau)) y [`states/MainMenuState.luau`](docs/flux-examples/states/MainMenuState.luau).

### SScript (`.ss`)

[SScript](https://github.com/ThomasDarkson/SScript) 24 es un fork de HScript. Corre los scripts en su propia máquina virtual de C++ (SSVM), así que es rápido. Se escribe como un `.hx` de Psych:

- **Mismo preset que los `.hxs`**: `game`, `FlxG`, `Paths`, casi todo Flixel/OpenFL/Psych y las funciones (`makeText`, `tween`, `timer`, `playSound`, `getVar`/`setVar`, `debugPrint`, `switchState`...). Los campos del estado se usan directo (`boyfriend`, `camHUD`, `add(...)`).
- **Lenguaje**: `import`, funciones con tipos (`function f(x:Int):Int`), `?.`, `??`, `'${interpolación}'`, `switch`, `try/catch`, mapas (`['a' => 1]`) y `for (k => v in mapa)`.
- Si el script usa un nombre que todavía no existe cuando se carga (por ejemplo una variable que otro script pone después), SScript usa su intérprete en vez de la máquina virtual. Funciona igual, pero más lento.
- Flux corrige tres fallas del SScript original:
  - `null` y las variables que valen `null` daban error en el intérprete.
  - Una función sin argumentos no servía de callback (`onComplete: function() ...`).
  - Un error dentro de un tween o un timer cerraba el juego. Ahora sale como un error del script, y el juego sigue.
- También sirve para menús (`states/<Menú>.ss`) y como script global (`.ssg`).

Desde Lua: `runSScript(código, ?función, ?argumentos)` y `runFluxFunction('sscript', función, argumentos)`.

Ejemplo: [`ejemplo.ss`](docs/flux-examples/ejemplo.ss).

### FluxScript (`.flux`)

[FluxScript](https://github.com/darnellpsych-funkin/FluxScript) es nuestro addon de HScript: el mismo HScript de Psych (un `.hx` funciona igual) con cosas extra.

- **Clases sin `import`**: `new FlxBackdrop(...)`, `new HealthIcon('bf')`... Un `import` de algo que no existe avisa en amarillo y no corta el script.
- **Los campos del juego directo, también para cambiarlos**: `health = 2`, `songScore += 100`, `boyfriend.visible = false`. Para los que Psych ya da como variables (`curBeat`, `combo`, `misses`...) usa `game.` (`game.combo = 0`).
- **Textos con variables**: `'Beat $curBeat - vida ${health * 50}%'` (con comillas simples).
- **Varias funciones para el mismo evento**: `on('beatHit', función)` y `off('beatHit')`. También se llama la función `onBeatHit` del script si existe.
- **`shared`**: datos que comparten todos los `.flux` y duran toda la partida (`shared.canciones = 3`).
- **`wait(segundos, función)`, `every(segundos, función)`** (se repite hasta que la función devuelva `false`) y `color('#FF0066')`.
- **La API de Lua de Psych** con los mismos nombres y argumentos: `makeLuaSprite`, `addLuaSprite`, `makeLuaText`, `setProperty`, `doTweenX`, `runTimer`, `playSound`, `cameraFlash`, `characterPlayAnim`... Donde va un tag también se puede pasar el objeto, y `onTweenCompleted`/`onTimerCompleted` llegan al script que los creó. Los tags son los mismos que usan los `.lua`.
- **Todo el preset de los `.hxs`** (`makeText`, `tween`, `timer`, `switchState`, `importScript`...).
- También sirve para menús (`states/<Menú>.flux`) y como script global (`.fluxg`). `#if FLUXSCRIPT` y `#if FLUX_ENGINE` funcionan.

Desde Lua: `runFluxScript(código, ?función, ?argumentos)` y `runFluxFunction('fluxscript', función, argumentos)`.

La lista completa está en el [README de FluxScript](https://github.com/darnellpsych-funkin/FluxScript). Ejemplos: [`ejemplo.flux`](docs/flux-examples/ejemplo.flux), [`estilo-lua.flux`](docs/flux-examples/estilo-lua.flux), [`states/MainMenuState.flux`](docs/flux-examples/states/MainMenuState.flux) y [`scripts/global/contador.flux`](docs/flux-examples/scripts/global/contador.flux).

### Scripts de menús y scripts globales

Funcionan con todos los lenguajes de Flux:

- **Menús**: `mods/TuMod/states/<Menú>.hxs` (o `.luau`, `.ss`...), por ejemplo `states/MainMenuState.hxs`, `states/FreeplayState.hxs`, `states/TitleState.hxs` o `states/OptionsState.hxs`. Corre mientras ese menú está abierto, y `game` es el menú. Funciones: `onCreate`, `onCreatePost`, `onUpdate(elapsed)`, `onUpdatePost(elapsed)`, `onBeatHit(beat)`, `onStepHit(step)`, `onDestroy`, `onFocusLost` y `onFocus`.
- **Menús nuevos**: `switchState('MiMenu')` abre `states/MiMenu.hxs` como un menú propio, aunque no exista en el código del engine.
- **Globales**: corren siempre, en todos los menús y canciones, y no se reinician al cambiar de menú (las variables se mantienen). Hay dos formas de hacerlos:
  - Con la extensión del lenguaje más una `g`, en `mods/TuMod/scripts/`: `.hxsg`, `.luaug`, `.ssg`, `.fluxg`, `.rhxg`, `.nxg`, `.nxsg` y `.hspg`. Para Lua es `.luag` (ver abajo).
  - Con cualquier script de Flux en `mods/TuMod/scripts/global/`.

  Funciones: `onCreate`, `onStateCreate(menú)`, `onStateCreatePost(menú)`, `onStateSwitch(menú)`, `onUpdate(elapsed)`, `onBeatHit`, `onStepHit`, `onFocusLost` y `onFocus`. En las canciones también reciben todos los callbacks de la canción (`goodNoteHit`, `noteMiss`, `onSongStart`, `onEvent`, `onPause`, `onUpdatePost`...), con los mismos argumentos que un script normal, y pueden devolver `Function_Stop`.

Se buscan en las mismas carpetas que usa Psych: el mod actual, los mods globales y `mods/`. Los `.hxs`, `.lua`, `.luau`... sueltos en `scripts/` siguen siendo scripts de canción, como siempre.

Ejemplos: [`ejemplo.hxs`](docs/flux-examples/ejemplo.hxs), [`states/MainMenuState.hxs`](docs/flux-examples/states/MainMenuState.hxs), [`states/MiMenu.hxs`](docs/flux-examples/states/MiMenu.hxs), [`scripts/global/reloj.hxs`](docs/flux-examples/scripts/global/reloj.hxs) y [`scripts/contador.hxsg`](docs/flux-examples/scripts/contador.hxsg).

### Lua global (`.luag`)

Es el mismo Lua de Psych, pero corre en todo el juego: en los menús y en las canciones, sin reiniciarse. Va en `mods/TuMod/scripts/`, por ejemplo `scripts/reloj.luag`.

- **Funciones**: las de Psych que sirven en cualquier menú, con los mismos nombres y argumentos:
  - `getProperty`/`setProperty` (también `FromClass` y `FromGroup`), `callMethod`, `callMethodFromClass`, `createInstance`, `addInstance`, `getObjectOrder`/`setObjectOrder`.
  - Sprites: `makeLuaSprite`, `makeAnimatedLuaSprite`, `makeGraphic`, `loadGraphic`, `addAnimationByPrefix`/`addAnimation`/`addAnimationByIndices`, `playAnim`, `addLuaSprite`/`removeLuaSprite`, `scaleObject`, `screenCenter`, `setObjectCamera`, `setBlendMode`...
  - Textos: `makeLuaText`, `addLuaText`, `removeLuaText`, `setTextString`, `setTextSize`, `setTextColor`, `setTextAlignment`, `getTextString`...
  - Tweens y timers: `doTweenX`/`Y`/`Angle`/`Alpha`/`Zoom`/`Color`, `startTween`, `cancelTween`, `runTimer`, `cancelTimer`.
  - Sonido y cámaras: `playMusic`, `playSound`, `stopSound`, `soundFadeIn`/`Out`, `cameraShake`/`Flash`/`Fade`, `precacheImage`/`Sound`/`Music`.
  - Otras: teclado y mouse (`keyboardJustPressed`, `keyJustPressed`, `mouseClicked`, `getMouseX`...), `setVar`/`getVar`, `debugPrint`, `getRandomInt`, `initSaveData`/`getDataFromSave`/`setDataFromSave`, `getModSetting`, `getTextFromFile`, `runHaxeCode` y `close`.
  - Nuevas: `switchState('FreeplayState')` (también menús hechos con script) y `resetState()`.
- **Variables**: `curState` (el menú actual, por ejemplo `'MainMenuState'`), `inSong` e `isGlobalScript`. En las canciones también `songName`, `curBeat`, `score`, `misses`... como en un `.lua` normal.
- **Callbacks**: los de los globales de arriba, más `onTweenCompleted`, `onTimerCompleted` y `onSoundFinished`.
- `game` es el menú actual, o la canción si estás jugando. En una canción, lo propio de la canción se hace con `getProperty`/`setProperty`/`callMethod`, por ejemplo `setProperty('health', 2)` o `callMethod('boyfriend.playAnim', {'hey', true})`.
- Los timers siguen andando al cambiar de menú, y también en la pausa. Los tweens, sonidos, sprites y textos son del menú: Flixel los borra al cambiar. Los saves de `initSaveData` se mantienen.
- Para los callbacks de `startTween` se usa el nombre de la función como texto, como en Psych (`onComplete = 'miFuncion'`). Una función de Lua ahí llega como `nil`.
- `close()` lo apaga hasta que reinicies el juego.

Ejemplo: [`scripts/reloj.luag`](docs/flux-examples/scripts/reloj.luag).

Experimental: para que las clases de un `.hxs` puedan heredar de clases de Flixel (`class MiSprite extends FlxSprite`), quita el comentario de `HXS_FLIXEL_CLASSES` en `Project.xml`. La compilación tarda más.

### Lua usa los otros lenguajes

| Función de Lua | Qué hace |
|---|---|
| `runRuleScript(código, ?función, ?argumentos)` | Ejecuta código RuleScript (las variables y funciones se mantienen entre llamadas) |
| `runNXScript(código, ?función, ?argumentos)` | Igual, con NXScript |
| `runHScriptPlus(código, ?función, ?argumentos)` | Igual, con hscript-plus |
| `runHScriptImproved(código, ?función, ?argumentos)` | Igual, con el HScript expandido (`.hxs`) |
| `runLuau(código, ?función, ?argumentos)` | Igual, con Luau (`.luau`) |
| `runSScript(código, ?función, ?argumentos)` | Igual, con SScript (`.ss`) |
| `runFluxScript(código, ?función, ?argumentos)` | Igual, con FluxScript (`.flux`) |
| `runFluxFunction(lenguaje, función, ?argumentos)` | Llama una función creada antes con `run...` (`"rulescript"`, `"nxscript"`, `"hscriptplus"`, `"hxs"`, `"luau"`, `"sscript"` o `"fluxscript"`) |
| `addFluxScript(archivo)` / `removeFluxScript(archivo)` | Carga o quita un script `.rhx`, `.nx`, `.nxs`, `.hsp`, `.hxs`, `.luau`, `.ss` o `.flux` (la extensión es opcional) |
| `isFluxScriptRunning(archivo)` / `getRunningFluxScripts()` | Saber qué scripts están corriendo |
| `callFluxScript(archivo, función, ?argumentos)` | Llama una función de un script de archivo |
| `getFluxScriptVar(archivo, variable)` / `setFluxScriptVar(archivo, variable, valor)` | Lee o cambia una variable de un script |
| `callOnFluxScripts(función, ?argumentos)` / `setOnFluxScripts(variable, valor)` | Llama una función o pone una variable en todos los scripts de Flux |

`callOnHScript` y `setOnHScript` de Psych también llegan a los scripts de Flux.

## Mods de V-Slice (fases 1 y 2: canciones, personajes y escenarios)

Pon la carpeta del mod de V-Slice dentro de `mods/` (la que tiene `_polymod_meta.json`). Flux lee:

- **Semanas** (`data/levels/*.json`): salen en Story Mode y Freeplay, con el título y el color del level.
- **Canciones** (`data/songs/<canción>/<canción>-metadata.json` y `-chart.json`): todas las dificultades, cambios de BPM, cámara (`FocusCamera`) y tipos de nota comunes.
- **Variaciones**: Erect y Nightmare se suman como dificultades de la canción normal; los mixes que repiten dificultades (Pico Mix, BF Mix...) salen aparte en Freeplay con su nombre.
- **Audio** con los nombres de V-Slice: `Inst.ogg`, `Inst-erect.ogg`, `Voices-bf.ogg`, `Voices-dad-erect.ogg`, `Voices-pico-pico.ogg`...
- **Eventos**: `PlayAnimation`, `ScrollSpeed`, `ZoomCamera` (también con `easeDir`), `SetCameraBop`, `SetHealthIcon`, `SetTargetBopSpeed` y `Subtitles` (la letra abajo de la pantalla). Los demás llegan a `onEvent` de los scripts con el valor en JSON.
- **Cambios de personaje**: V-Slice no trae un evento para eso y cada mod usa el suyo, casi siempre el `ChangeCharacter` de NebulaStellaNova (`{"character": "dad", "newchar": "finn-sword"}`). Flux lo convierte al "Change Character" de Psych: los personajes se cargan al empezar y cambian en su lugar del escenario, con su ícono. También entiende nombres parecidos (`SetCharacter`, `SwitchCharacter`, `Change Character`...) con `character`/`char`/`target` y `newchar`/`id`/`to`.

### Personajes y escenarios de V-Slice (fase 2)

Si un personaje o un escenario no existe en Psych, Flux usa el de V-Slice:

- **Personajes** (`data/characters/<id>.json`): `sparrow`, `multisparrow` y `packer`. Las animaciones, sus offsets (que en V-Slice crecen con la escala), `flipX`, `scale`, `singTime`, `danceEvery`, el ícono y los offsets de cámara funcionan como en V-Slice. `animateatlas` todavía no.
- **Escenarios** (`data/stages/<id>.json`): los props con su posición, escala, scroll, alpha, ángulo, color, blend, `flipX`/`flipY` y animaciones. Los que tienen `danceEvery` bailan con la canción. Los personajes quedan parados en su lugar (el centro de abajo, como en V-Slice), con la escala, el scroll, el alpha y los offsets de cámara del escenario, y todo se ordena por `zIndex`. También el zoom (`cameraZoom`).
- Los props con nombre se pueden usar desde Lua y HScript (`getProperty('bg.alpha')`), y desde los módulos con `getNamedProp`. El `refresh()` de los módulos ordena el escenario por `zIndex` sin mover el HUD.
- **Game over**: si el jugador tiene `firstDeath`, `deathLoop` y `deathConfirm` (como en V-Slice), el game over usa al mismo personaje, en el mismo lugar y con el mismo tamaño.
- Los archivos que el mod guarda en `shared/` (por ejemplo `shared/images/characters/...`) se encuentran solos.

Todavía no (próximas fases): los scripts de canción, escenario y personajes (`extends Song`, `Stage`, `SparrowCharacter`...), las skins de notas (`noteStyle`) y los props o personajes `animateatlas`. Los módulos, tipos de nota y eventos con script sí (ver abajo). Para desactivar todo lo de V-Slice, comenta `FLUX_VSLICE` en `Project.xml`.

## Módulos de V-Slice (`.hxc`, fase 5)

Flux carga las clases de los `.hxc` que hacen `extends Module`, igual que el `ModuleHandler` de V-Slice, los tipos de nota (`extends NoteKind` o `ScriptedNoteKind`) y los eventos del chart con script (`extends SongEvent` o `ScriptedSongEvent`). Busca en todos los mods activos al abrir el juego, y otra vez si cambias los mods activos. Esas clases funcionan en cualquier menú y en las canciones, y reciben los mismos eventos que en V-Slice:

- En todo el juego: `onCreate`, `onDestroy`, `onUpdate`, `onStateChangeBegin`/`End`, `onSubStateOpenEnd`/`CloseEnd` y `onFocusLost`/`Gained`.
- En las canciones: `onSongLoaded`, `onCountdownStart`/`Step`/`End`, `onSongStart`, `onSongEnd`, `onNoteIncoming`, `onNoteHit`, `onNoteMiss`, `onNoteGhostMiss`, `onSongEvent`, `onBeatHit`, `onStepHit`, `onPause`, `onResume` y `onGameOver`.

Un tipo de nota recibe los eventos de las notas de su tipo (`onNoteHit`, `onNoteMiss`, `onNoteIncoming`...) y los demás de la canción. Lo que pone en `super(...)` también funciona: con `noanim` el personaje no canta esas notas (por ejemplo, para que las cante otro desde el script), el sufijo va a la animación y `scoreable = false` hace que no den puntaje. Así funcionan las notas de Morty de Schwifty (Rick and Morty).

Un evento con script hace `super('IdDelEvento')` y cuando la canción llega a un evento con ese id, Flux llama a su `handleEvent(data)` (`data.getFloat('duration')`, `data.getString('target')`, `data.value`...). Mientras la canción tenga eventos de ese tipo, también recibe los eventos de la canción (`onSongLoaded`, `onPause`...), como en V-Slice. Si el evento es uno que Flux ya hace solo (`ZoomCamera`, `SetCameraBop`, `Subtitles`, `SetHealthIcon`, `SetTargetBopSpeed`, `PlayAnimation`), se usa el de Flux. Probado con los eventos de VS Nonsense (`BlackSquare`, `FlashCam`, `ShakeCam`, `SkillCheck`) y de Applecore (`ChangeStage`, `ChangeCharacters`, `ShowImageEvent` y el flash de cámara).

**Cambiar de escenario a mitad de canción** funciona como en V-Slice: `PlayState.instance.remove(currentStage)`, `PlayState.instance.currentStage = StageRegistry.instance.fetchEntry('otro')`, `currentStage.buildStage()`, `PlayState.instance.add(currentStage)` y `currentStage.addCharacter(personaje, CharacterType.BF)`. Los props del escenario viejo se van, los del nuevo quedan en el mismo lugar del juego ordenados por `zIndex` con los personajes, y la cámara toma el zoom (`resetCameraZoom()`) y los offsets del escenario nuevo. Por ahora entre escenarios de V-Slice (`data/stages/<id>.json`).

Con `event.cancel()` se frena lo que haría Psych: un golpe o un fallo no cuentan, una pausa o una muerte no pasan, y un evento no se ejecuta. Eso último solo vale para el efecto del evento: los demás scripts igual lo reciben.

Los nombres de V-Slice se traducen a Psych. Por ejemplo, `PlayState.instance` es el de Psych, y `state.playerStrumline` (`getNotesMayHit`, `hitNote`, `playStatic`...), `state.currentStage.getBoyfriend()`, `state.vocals.playerVolume`, `currentSong.validScore`, `currentSong.difficulties.get(variación).get(dificultad)` y `currentChart` (`stage`, `characters.player`, `songArtist`, `getStartingBPM()`...) funcionan. También funcionan en las notas `note.hasBeenHit`, `note.kind`, `note.noteData.getDirection()` y `note.noteData.getMustHitNote()`, y además `sprite.zIndex`, `Save.instance.modOptions`, `ModStore`, `Conductor.instance`, `Paths`, `FunkinSprite`, `Highscore.tallies`, `Scoring` y `Constants`. `Assets.getText(Paths.frag('x'))` (de `funkin.Assets` o de `openfl.utils.Assets`) lee los archivos del mod, como hace Polymod en V-Slice. Para personajes: `CharacterDataParser.fetchCharacter`/`listCharacterIds`/`parseCharacterData`, `new SparrowCharacter('id')` (y los otros tipos), `currentStage.addCharacter(personaje, CharacterType.OTHER)` (un personaje más que baila con la canción) o con `BF`/`DAD`/`GF` (reemplaza al de Psych), `currentStage.getCharacter(id)`, `getBoyfriendPosition()`, `remove`, `character.initHealthIcon`, `character.characterOrigin` y `PlayState.instance.songEvents`. También `FlxTweenUtil`, `FunkinMemory`, `PolymodErrorHandler.showAlert` y los imports que V-Slice pone solos (`Paths`, `Assets`, `Preferences`, `Constants` y `FlxG`). En el menú de pausa, un módulo puede agregar opciones propias con `currentMenuEntries` y `clearAndAddMenuEntries()`.

Probado con el botplay de snezhok174 y Kai0903: la opción "Enable Botplay" aparece en la pausa, el bot pega todas las notas (también los sustains), no pega las notas de daño y, como en V-Slice, la puntuación no se guarda si usaste el bot. Su esquive automático para los mods de QT se probó con un módulo de prueba.

Límites por ahora:
- Se usan los módulos, los tipos de nota y los eventos. Las clases de canciones, escenarios y personajes (`extends Song`, `Stage`, `BaseCharacter`...) todavía se ignoran con un aviso en la consola.
- Lo que Flux todavía no tiene (por ejemplo el menú de opciones de V-Slice, `OptionsState`/`PreferencesMenu`) no rompe el módulo: el `.hxc` carga igual, la consola dice qué falta y esas partes no hacen nada. Por eso la página de opciones del botplay no aparece.
- Los errores de un módulo salen en la consola y, si estás jugando, en pantalla, con el archivo y la línea. El mismo error se muestra 3 veces como máximo.

Necesita RuleScript (`RULESCRIPT_ALLOWED`). Para desactivar los módulos, comenta `FLUX_VSLICE_SCRIPTS` en `Project.xml`.

## Modcharts (FunkinModchart)

Flux trae [FunkinModchart 1.2.5](https://github.com/TheoDevelops/FunkinModchart) (de TheoDevelops, licencia Apache 2.0, incluido en `source/flux/vendor/funkinmodchart`): efectos como los de NotITG en las flechas (`drunk`, `tipsy`, `reverse`, `rotate`, `beat`, `bounce`, `stealth`...), que cambian en el beat que quieras y con eases.

Usa el modchart en `onCreatePost` (o en `onCountdownStarted` si la canción empieza con un diálogo), porque necesita que las flechas ya existan. Ejemplo: [`docs/flux-examples/modchart.lua`](docs/flux-examples/modchart.lua).

| Función de Lua | Qué hace |
|---|---|
| `startModchart()` | Crea el modchart de la canción (las otras funciones también lo crean solas) |
| `addModifier(nombre, ?campo)` | Agrega un modificador: `'drunk'`, `'tipsy'`, `'reverse'`, `'transform'`... |
| `setPercent(nombre, valor, ?jugador, ?campo)` | Cambia el valor ahora (1 = 100%) |
| `getPercent(nombre, ?jugador, ?campo)` | Devuelve el valor |
| `setModifier(nombre, beat, valor, ?jugador, ?campo)` | Cambia el valor en ese beat |
| `easeModifier(nombre, beat, duración, valor, ?ease, ?jugador, ?campo)` | Lo lleva a ese valor con un ease (`'linear'`, `'quadOut'`, `'sineInOut'`...); la duración es en beats |
| `addEaseModifier(nombre, beat, duración, valor, ?ease, ?jugador, ?campo)` | Igual, pero suma al valor que tenga |
| `setAddModifier(nombre, beat, valor, ?jugador, ?campo)` | Suma al valor en ese beat |
| `modchartCallback(beat, 'función', ?campo)` | Llama una función de tu script en ese beat (recibe el beat) |
| `modchartRepeater(beat, duración, 'función', ?campo)` | Llama esa función en cada frame durante la duración |
| `aliasModifier(nombre, otroNombre, ?campo)` | Le pone otro nombre a un valor |
| `addPlayfield()` | Agrega otro grupo de flechas (devuelve su número). Los modificadores agregados antes no pasan al nuevo |
| `setModchartConfig(opción, valor)` | Cambia una opción de `modchart.Config` (por ejemplo `'RENDER_ARROW_PATHS'`) |

`jugador`: `0` es el oponente, `1` el jugador y `-1` (o nada) los dos. `campo`: el grupo de flechas, `-1` (o nada) es todos.

En los otros lenguajes (`.hx`, `.hxs`, `.ss`, `.rhx`, `.nx`...), `startModchart()` devuelve el `Manager` de FunkinModchart para usarlo directo, como en su [documentación](source/flux/vendor/funkinmodchart/DOC.md):

```haxe
function onCreatePost() {
	var modchart = startModchart();
	modchart.addModifier('drunk');
	modchart.ease('drunk', 8, 4, 1, FlxEase.quadOut); // beat 8, dura 4 beats, llega a 100%
}
```

Las opciones de `modchart.Config` (en los `.hxs` también como `ModchartConfig`) son globales: si cambias una, vuelve a ponerla como estaba en `onDestroy`. Para desactivar los modcharts, comenta `MODCHARTS_ALLOWED` en `Project.xml`.

## Charts de otros juegos (Moonchart)

Con [Moonchart 0.5.1](https://github.com/MaybeMaru/moonchart) (de MaybeMaru, licencia MIT, incluido en `source/flux/vendor/moonchart`), Flux juega charts de otros juegos sin convertirlos antes. Si una canción no tiene chart de Psych (ni de V-Slice), Flux busca en `data/<canción>/` y en `songs/<canción>/`:

| Formato | Archivos | Dificultades |
|---|---|---|
| osu!mania | `.osu` (solo de 4 teclas) | Una por archivo: la `Version` del `.osu` |
| Quaver | `.qua` (solo de 4 teclas) | Una por archivo: el `DifficultyName` |
| StepMania | `.sm` y `.ssc` (solo los charts `dance-single`) | Las del archivo: Beginner, Easy, Medium (o Normal), Hard, Challenge (o Expert) |
| Codename Engine | `charts/<dificultad>.json` y `meta.json` | Los nombres de los archivos de `charts/` |

Cómo agregar una canción:

1. Copia los archivos del chart a `mods/<tu mod>/data/<canción>/`. Para Codename, copia la carpeta de la canción completa a `mods/<tu mod>/songs/<canción>/`.
2. Agrega la canción a una semana (`weeks/*.json`) con esas dificultades en `"difficulties"`, por ejemplo `"Easy, Hard, Insane"`. Si el chart trae una sola dificultad, sirve para todas. Si falta una, Freeplay muestra cuáles trae el chart.
3. Audio: Flux usa el que pide el chart (`AudioFilename` de osu!, `AudioFile` de Quaver, `#MUSIC` de StepMania) o `Inst.ogg`. **En PC no se pueden reproducir MP3**: conviértelo a OGG con el mismo nombre (`audio.mp3` → `audio.ogg`). En Codename se usan `song/Inst.ogg` y `song/Voices.ogg`.

- En osu!mania, Quaver y StepMania todas las notas son del jugador (esos juegos no tienen oponente). En Codename, las notas de cada personaje van a su lado y la cámara sigue los eventos `Camera Movement`.
- Las minas de StepMania y las `Hurt Note` son notas de daño. Los otros tipos de nota de Codename pasan con su nombre: para que hagan algo, crea en `custom_notetypes/` un script con ese nombre.
- Para tenerlo como chart de Psych, abre la canción en el editor de charts (tecla 7) y guarda con Ctrl+S: se guarda al lado del original (`<canción>-<dificultad>.json`). Si estaba en `data/<canción>/`, la próxima vez Flux carga ese.
- Flux arregla dos cosas de Moonchart 0.5.1: el `AudioLeadIn` de osu! (adelantaba las notas) y los `.ssc` con varias dificultades (salían todas iguales).

Para desactivarlo, comenta `MOONCHART_ALLOWED` en `Project.xml`.

## Mods de Codename Engine (fase 1)

Flux carga mods hechos para [Codename Engine](https://github.com/CodenameCrew/CodenameEngine): copia la carpeta del mod a `mods/` tal cual.

| De Codename | En Flux |
|---|---|
| `songs/<canción>/charts/*.json`, `meta.json`, `song/Inst.ogg` y `Voices.ogg` | Charts y audio (con Moonchart, ver arriba) |
| `songs/<canción>/events.json` y los eventos del chart | Eventos de la canción (ver abajo) |
| `data/characters/<nombre>.xml` | Personajes (si no hay uno de Psych o de V-Slice con ese nombre) |
| `data/stages/<nombre>.xml` | Escenarios (si no hay uno de Psych o de V-Slice) |
| `data/weeks/weeks/*.xml` (y el orden de `weeks.txt`) | Semanas en Story Mode y Freeplay; el ícono y el color salen del `meta.json` de cada canción |

- **Personajes**: animaciones con `indices` (`"2..12,0,1"`), offsets, escala, `x`/`y`, `camx`/`camy`, `holdTime`, `flipX`, `icon`, `color`, `antialiasing`, `interval` y `gameOverChar`. Si un personaje se usa del otro lado (un oponente como jugador), se cambian izquierda y derecha como en Codename.
- **Escenarios**: `sprite`, `box`/`solid`, `boyfriend`/`girlfriend`/`dad` (con `camxoffset`, `camyoffset`, `scroll` y `alpha`), `high-memory`/`low-memory` (con "Low Quality"), `type="beat"` (baila en el beat, con `beatInterval` y `beatOffset`), `type="loop"`, `<property>`, `zoom` y `startCamPosX`/`startCamPosY`. Cada sprite queda en las variables del juego con su nombre (`getProperty('bg')` en Lua).
- **Eventos**: `Add Camera Zoom`, `Camera Bop`, `Play Animation`, `Character Change`, `Scroll Speed Change` y `Camera Position` pasan a los de Psych; `Camera Zoom`, `Camera Flash`, `Camera Modulo Change`, `HScript Call` (llama la función en todos los scripts) y `Alt Animation Toggle` los hace Flux. `Camera Movement` y `BPM Change` ya van en las secciones. Los eventos de scripts llegan a `onEvent` con sus dos primeros parámetros.
- Los scripts `.hx` de Codename (de canción, escenario, personaje y globales) todavía no se cargan: es la fase 2. Tampoco los personajes del menú del Story Mode en XML (se usan los de Psych con el mismo nombre o BF y GF).

Para desactivarlo, comenta `FLUX_CODENAME` en `Project.xml`.

## Multi-Keys (de 4 a 17 teclas)

Cualquier canción se puede jugar con más (o menos) teclas, como en Psych Online. En Freeplay abre **Gameplay Changers** (Ctrl) y en **Multi-Keys** elige con izquierda/derecha:

- `Chart`: las teclas que trae el chart (4 en las canciones normales).
- `4K` a `17K`: convierte la canción a esa cantidad de teclas.

La conversión respeta la dirección de cada flecha (una izquierda sigue siendo izquierda; abajo y arriba también usan el círculo del centro), mantiene los jacks y los acordes, no pone notas encima de una sostenida y reparte las notas por todas las teclas. Siempre sale igual para la misma canción. Si bajas de teclas (por ejemplo un chart de 9K a 4K), los acordes más grandes que las teclas pierden notas.

| Teclas | Flechas | Teclado |
|---|---|---|
| 5K | ← ↓ ● ↑ → | D F Espacio J K (y las flechas) |
| 6K | ← ↑ → ← ↓ → | S D F J K L |
| 7K | ← ↑ → ● ← ↓ → | S D F Espacio J K L |
| 8K | ← ↓ ↑ → ← ↓ ↑ → | A S D F H J K L |
| 9K | ← ↓ ↑ → ● ← ↓ ↑ → | A S D F Espacio H J K L |
| 10K | ← ↓ ↑ → ● ● ← ↓ ↑ → | A S D F V N J K L ; |
| 11K | ← ↓ ↑ → ← ● → ← ↓ ↑ → | A S D F R Espacio U J K L ; |
| 12K | ← ↓ ↑ → × 3 | A S D F E R U I J K L ; |
| 13K | ← ↓ ↑ → ← ↓ ● ↑ → ← ↓ ↑ → | A S D F E R Espacio U I J K L ; |
| 14K | ← ↓ ↑ → ← ↑ → ← ↓ → ← ↓ ↑ → | A S D F W E R U I O J K L ; |
| 15K | ← ↓ ↑ → ← ↑ → ● ← ↓ → ← ↓ ↑ → | A S D F W E R Espacio U I O J K L ; |
| 16K | ← ↓ ↑ → × 4 | A S D F Q W E R U I O P J K L ; |
| 17K | ← ↓ ↑ → ← ↓ ↑ → ● ← ↓ ↑ → ← ↓ ↑ → | A S D F Q W E R Espacio U I O P J K L ; |

- **Controles**: en Opciones > Controles, **Q/E** (con mando, los gatillos) cambia entre 4K, 5K... 17K. "Reset to Default Keys" en esas páginas solo reinicia las de esa cantidad de teclas. Con mando, de 5K a 9K ya vienen asignadas. En teclado en español, `;` puede ser la Ñ: si no responde, cámbiala ahí.
- Si una nota usa la R (la tecla de reinicio), en esa canción la R no te mata.
- **Colores**: izquierda, abajo, arriba y derecha usan tus colores de "Note Colors"; las teclas extra usan amarillo, violeta, rojo oscuro y azul oscuro, y el centro (●) es blanco.
- **Nota del centro**: es un círculo (`images/noteSkins/NOTE_circle` y `images/pixelUI/noteSkins/NOTE_circle`). Una skin de un mod puede traer el suyo como `<skin>-circle.png/.xml` (frames `white0000`, `white hold piece`, `white hold end`, `arrowCIRCLE`, `circle press` y `circle confirm`); si no tiene, el centro usa la flecha de arriba.
- **Charts de más teclas**: se juegan tal cual con `"keyCount": 7` en el JSON (carriles `0` a `keyCount - 1` del jugador y el resto del oponente) o con el `mania` de Psych Extra Keys (`mania + 1` teclas) o del mod de Shaggy (0 = 4K, 1 = 6K, 2 = 7K, 3 = 9K, 4 = 5K). Los charts viejos con `mustHitSection` también.
- **Scripts**: en Lua está la variable `keyCount`; en HScript, `FluxKeys.current` (con `import flux.keys.FluxKeys;`) y `FluxKeys.chartCount` (las teclas del chart). `defaultPlayerStrumX0`... existen para todas las teclas, y los colores extra se cambian en `flux.keys.FluxKeysData.extraColors`. Ejemplo: [`docs/flux-examples/multikeys.lua`](docs/flux-examples/multikeys.lua).
- Los dos lados juegan con la misma cantidad de teclas. El editor de charts sigue siendo de 4K, y los charts de osu!mania y Quaver siguen siendo solo de 4 teclas.

## Compilar

En Windows:

1. Abre `setup\windows.bat`. La primera vez crea la carpeta `.haxelib` con las librerías de Flux, separadas de las de otros engines, e instala todo (también hxcpp 4.3.2, `nxscript`, `rulescript` y `hscript 2.6.0`).
2. Abre `art\buildScripts\build_x64.bat`.

Si aparece "Could not load lime.ndll" o "Library lime is not installed", falta el paso 1: se estaban usando las librerías de otro engine (por ejemplo el Lime de Git de V-Slice, que no trae `lime.ndll`). Si compilas a mano en tu carpeta de librerías de siempre, usa `haxelib set hscript 2.6.0` (RuleScript 0.2.0 no compila con hscript 2.7 o más nuevo).

Si aparece `Could not find haxelib "hxcpp-debug-server"`, abriste el script de debug (`build_x64-debug.bat` o `test_x64-debug.bat`) y falta esa librería: abre otra vez `setup\windows.bat` (ahora la instala), o escribe `cmd` en la barra de direcciones de la carpeta de Flux y ejecuta `haxelib install hxcpp-debug-server`. Para jugar normal alcanza con `build_x64.bat`.

Las librerías quedan en la carpeta `.haxelib` dentro de Flux. Si bajas una versión nueva, copia esa carpeta a la carpeta nueva para no instalar todo otra vez.

Luau se compila junto con el juego desde `source/flux/vendor/luau` (necesita C++17; en Windows sirve el Visual Studio que instala `setup/windows-msvc.bat`). La máquina virtual de SScript también se compila con el juego (`source/flux/vendor/sscript/ssvm`, C++11). Por eso la primera compilación tarda un poco más.

Ejemplos: [`docs/flux-examples/`](docs/flux-examples). Para desactivar un lenguaje, comenta `NXSCRIPT_ALLOWED`, `RULESCRIPT_ALLOWED`, `HSCRIPT_PLUS_ALLOWED`, `HSCRIPT_IMPROVED_ALLOWED`, `LUAU_ALLOWED` o `SSCRIPT_ALLOWED` en `Project.xml`. Para desactivar los `.luag`, comenta `LUA_GLOBAL_ALLOWED`.

Código: `source/flux/scripting/` (lenguajes y funciones de Lua), `source/flux/vendor/fluxscript/` (FluxScript, copia de su repo), `source/flux/vslice/` (mods de V-Slice), `source/flux/vslice/modules/` (módulos `.hxc`), `source/flux/modchart/` (modcharts) y `source/flux/moonchart/` (charts de otros juegos).

---

![PsychionalEngineLogo](docs/img/PsychEngineLogoTweak.png)

Engine originally used on [Mind Games Mod](https://gamebanana.com/mods/301107), intended to be a fix for the vanilla version's many issues while keeping the casual play aspect of it. Also aiming to be an easier alternative to newbie coders.

## Installation:

Refer to [the Build Instructions](/docs/BUILDING.md)

## Customization:

If you wish to disable things like *Lua Scripts* or *Video Cutscenes*, you can refer to the `Project.xml` file.

Inside `Project.xml`, you will find several variables to customize Psych Engine to your liking.

To start you off, disabling *Video Cutscenes* should be simple, simply delete the line `"VIDEOS_ALLOWED"` or comment it out by wrapping the line in XML-like comments, like this: `<!-- YOUR_LINE_HERE -->`

Same goes for *Lua Scripts*, comment out or delete the line with `LUA_ALLOWED`, this and other customization options are all available within the `Project.xml` file.

## Softcoding (.lua/.hx)
For this you can head over to [the wiki](https://shadowmario.github.io/psychengine.lua)

There you can learn how to use the 212 PlayState funcions in your mod!

## Credits:
* Shadow Mario - Main Programmer and Head of Psych Engine.
* Riveren - Main Artist/Animator of Psych Engine.

### Special Thanks
* bbpanzu - Ex-Team Member (Programmer).
* crowplexus - HScript Iris, Input System v3, and Other PRs.
* Kamizeta - Creator of Pessy, Psych Engine's mascot.
* MaxNeton - Loading Screen Easter Egg Artist/Animator.
* Keoiki - Note Splash Animations and Latin Alphabet.
* SqirraRNG - Crash Handler and Base code for Chart Editor's Waveform.
* EliteMasterEric - Runtime Shaders support and Other PRs.
* MAJigsaw77 - .MP4 Video Loader Library (hxvlc).
* iFlicky - Composer of Psync, Tea Time and some sound effects.
* KadeDev - Fixed some issues on Chart Editor and Other PRs.
* superpowers04 - LUA JIT Fork.
* CheemsAndFriends - Creator of FlxAnimate.
* Ezhalt - Pessy's Easter Egg Jingle.
* MaliciousBunny - Video for the Final Update.

***

# Features

## Attractive animated dialogue boxes:

![Animated Dialogue Boxes](docs/img/dialogue.gif)

## New Main Menu
* A brand new menu that makes your experience even better!
![Main Menu](docs/img/MainMenu.png)

## Mod Support
* Probably one of the main points of this engine, you can code in .lua files outside of the source code, making your own weeks without even messing with the source!
* Comes with a Mod Organizing/Disabling Menu.
![Mod Support](docs/img/ModsMenu.png)


## Atleast one change to every week:
### Week 1:
  * New Dad Left sing sprite
  * Unused stage lights are now used
  * Dad Battle has a spotlight effect for the breakdown
### Week 2:
  * Both BF and Skid & Pump does "Hey!" animations
  * Thunders does a quick light flash and zooms the camera in slightly
  * Added a quick transition/cutscene to Monster
### Week 3:
  * BF does "Hey!" during Philly Nice
  * Blammed has a cool new colors flash during that sick part of the song
### Week 4:
  * Better hair physics for Mom/Boyfriend (Maybe even slightly better than Week 7's :eyes:)
  * Henchmen die during all songs. Yeah :(
### Week 5:
  * Bottom Boppers and GF does "Hey!" animations during Cocoa and Eggnog
  * On Winter Horrorland, GF bops her head slower in some parts of the song.
### Week 6:
  * On Thorns, the HUD is hidden during the cutscene
  * Also there's the Background girls being spooky during the "Hey!" parts of the Instrumental

## Cool new Chart Editor changes and countless bug fixes
![Chart Editor](docs/img/chart.png)
* You can now chart "Event" notes, which are bookmarks that trigger specific actions that usually were hardcoded on the vanilla version of the game.
* Your song's BPM can now have decimal values
* You can manually adjust a Note's strum time if you're really going for milisecond precision
* You can change a note's type on the Editor, it comes with five example types:
  * Alt Animation: Forces an alt animation to play, useful for songs like Ugh/Stress
  * Hey: Forces a "Hey" animation instead of the base Sing animation, if Boyfriend hits this note, Girlfriend will do a "Hey!" too.
  * Hurt Notes: If Boyfriend hits this note, he plays a miss animation and loses some health.
  * GF Sing: Rather than the character hitting the note and singing, Girlfriend sings instead.
  * No Animation: Character just hits the note, no animation plays.

## Multiple editors to assist you in making your own Mod
![Master Editor Menu](docs/img/editors.png)
* Working both for Source code modding and Downloaded builds!

## Story mode menu rework:
![Story Mode Menu](docs/img/storymode.png)
* Added a different BG to every song (less Tutorial)
* All menu characters are now in individual spritesheets, makes modding it easier.

## Credits menu
![Credits Menu](docs/img/credits.png)
* You can add a head icon, name, description and a Redirect link for when the player presses Enter while the item is currently selected.

## Awards/Achievements
* The engine comes with 16 example achievements that you can mess with and learn how it works (Check Achievements.hx and search for "checkForAchievement" on PlayState.hx)
![Achievements](docs/img/Achievements.png)

## Options menu:
* You can change Note colors, Delay and Combo Offset, Controls and Preferences there.
 * On Preferences you can toggle Downscroll, Middlescroll, Anti-Aliasing, Framerate, Low Quality, Note Splashes, Flashing Lights, etc.
![Options](docs/img/Options.png)

## Other gameplay features:
* When the enemy hits a note, their strum note also glows.
* Lag doesn't impact the camera movement and player icon scaling anymore.
* Some stuff based on Week 7's changes has been put in (Background colors on Freeplay, Note splashes)
* You can reset your Score on Freeplay/Story Mode by pressing Reset button.
* You can listen to a song or adjust Scroll Speed/Damage taken/etc. on Freeplay by pressing Space.
* You can enable "Combo Stacking" in Gameplay Options. This causes the combo sprites to just be one sprite with an animation rather than sprites spawning each note hit.


#### Psych Engine by ShadowMario, Friday Night Funkin' by ninjamuffin99
