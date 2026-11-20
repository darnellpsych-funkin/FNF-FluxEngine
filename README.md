# Flux Engine

Fork de **Psych Engine 1.0.4** con más lenguajes de scripting y compatibilidad con mods de **V-Slice**.

## Scripting de Flux Engine

| Lenguaje | Extensión | Librería |
|---|---|---|
| Lua | `.lua` | linc_luajit (Psych) |
| HScript | `.hx` | hscript-iris (Psych) |
| NXScript | `.nx`, `.nxs` | [nxscript 0.5.8](https://github.com/senioritaelizabeth/NxScript) |
| RuleScript | `.rhx` | [rulescript 0.2.0](https://github.com/Kriptel/RuleScript) + hscript 2.6.0 |
| hscript-plus | `.hsp` | [hscript-plus](https://github.com/DleanJeans/hscript-plus) (incluido en `source/flux/vendor/hsplus`) |

Los scripts nuevos se cargan en los mismos lugares que los `.hx`: `scripts/`, `data/<canción>/`, `stages/`, `characters/`, `custom_notetypes/` y `custom_events/`. Reciben los mismos callbacks (`onCreate`, `onCreatePost`, `onUpdate`, `onBeatHit`, `goodNoteHit`, ...) y las mismas variables (`game`, `FlxG`, `FlxSprite`, `FlxTween`, `PlayState`, `setVar`, `debugPrint`, `Function_Stop`, ...). Corren después de HScript y respetan `Function_StopHScript` / `Function_StopAll`. Para cambiar valores del juego usa `game.` (`game.health`, `game.combo`...).

- **NXScript**: sus diccionarios `{...}` y funciones se convierten a `null` al pasarlos a Haxe; usa `toHaxe(valor)` para pasarlos (ej. `FlxTween.tween(spr, toHaxe({"alpha": 0}), 1)`). Las funciones del preset (`setVar`, `debugPrint`...) ya lo hacen solas.
- **RuleScript**: los campos del PlayState (`boyfriend`, `camGame`, `add(...)`...) se pueden leer directo. Soporta `import ... as`, `using`, propiedades, interpolación `'${x}'`, `??=` y clases en script.
- **hscript-plus**: agrega clases con herencia (`class Jefe extends Enemigo`). Es una versión vieja de hscript (2017): no tiene `() -> {}`, `?.` ni `??`. Dentro de una clase usa `campo = campo + 1` en vez de `+=`. Flux corrige un bug del original que evaluaba dos veces el lado derecho de `a = b`.

### Lua usa los otros lenguajes

| Función de Lua | Qué hace |
|---|---|
| `runRuleScript(código, ?función, ?argumentos)` | Ejecuta código RuleScript (las variables y funciones se mantienen entre llamadas) |
| `runNXScript(código, ?función, ?argumentos)` | Igual, con NXScript |
| `runHScriptPlus(código, ?función, ?argumentos)` | Igual, con hscript-plus |
| `runFluxFunction(lenguaje, función, ?argumentos)` | Llama una función creada antes con `run...` (`"rulescript"`, `"nxscript"` o `"hscriptplus"`) |
| `addFluxScript(archivo)` / `removeFluxScript(archivo)` | Carga o quita un script `.rhx`, `.nx`, `.nxs` o `.hsp` (la extensión es opcional) |
| `isFluxScriptRunning(archivo)` / `getRunningFluxScripts()` | Saber qué scripts están corriendo |
| `callFluxScript(archivo, función, ?argumentos)` | Llama una función de un script de archivo |
| `getFluxScriptVar(archivo, variable)` / `setFluxScriptVar(archivo, variable, valor)` | Lee o cambia una variable de un script |
| `callOnFluxScripts(función, ?argumentos)` / `setOnFluxScripts(variable, valor)` | Llama una función o pone una variable en todos los scripts de Flux |

`callOnHScript` y `setOnHScript` de Psych también llegan a los scripts de Flux.

## Mods de V-Slice (fase 1: canciones)

Pon la carpeta del mod de V-Slice dentro de `mods/` (la que tiene `_polymod_meta.json`). Flux lee:

- **Semanas** (`data/levels/*.json`): salen en Story Mode y Freeplay, con el título y el color del level.
- **Canciones** (`data/songs/<canción>/<canción>-metadata.json` y `-chart.json`): todas las dificultades, cambios de BPM, cámara (`FocusCamera`) y tipos de nota comunes.
- **Variaciones**: Erect y Nightmare se suman como dificultades de la canción normal; los mixes que repiten dificultades (Pico Mix, BF Mix...) salen aparte en Freeplay con su nombre.
- **Audio** con los nombres de V-Slice: `Inst.ogg`, `Inst-erect.ogg`, `Voices-bf.ogg`, `Voices-dad-erect.ogg`, `Voices-pico-pico.ogg`...
- **Eventos**: `PlayAnimation`, `ScrollSpeed`, `ZoomCamera` y `SetCameraBop`. Los demás llegan a `onEvent` de los scripts con el valor en JSON.

Todavía no (próximas fases): **personajes** y **escenarios** en formato V-Slice (si el mod no trae versiones de Psych, se usa BF y un escenario vacío), skins de notas (`noteStyle`) y **scripts `.hxc`**. Para desactivar todo esto, comenta `FLUX_VSLICE` en `Project.xml`.

## Compilar

Los scripts de `setup/` instalan todo, incluidos `nxscript`, `rulescript` y `hscript 2.6.0`. Si compilas a mano y ya tenías otra versión de hscript, ejecuta `haxelib set hscript 2.6.0` (RuleScript 0.2.0 no compila con hscript 2.7 o más nuevo). Si tienes librerías de Git de otros engines (por ejemplo el Lime de V-Slice), usa una carpeta de librerías propia para Flux: en la carpeta del proyecto ejecuta `haxelib newrepo` y `haxelib install hxcpp 4.3.2`, y después abre `setup/windows.bat` con doble clic.

Ejemplos: [`docs/flux-examples/`](docs/flux-examples). Para desactivar un lenguaje, comenta `NXSCRIPT_ALLOWED`, `RULESCRIPT_ALLOWED` o `HSCRIPT_PLUS_ALLOWED` en `Project.xml`.

Código: `source/flux/scripting/` (lenguajes y funciones de Lua) y `source/flux/vslice/` (mods de V-Slice).

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
