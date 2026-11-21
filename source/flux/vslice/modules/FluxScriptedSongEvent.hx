package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
/**
 * Evento de V-Slice cuyo código viene de un .hxc (`extends SongEvent` o
 * `extends ScriptedSongEvent`). Igual que FluxScriptedModule: la macro de
 * RuleScript genera el constructor y los overrides que llaman al script.
 */
class FluxScriptedSongEvent extends flux.vslice.api.SongEvent implements rulescript.scriptedClass.RuleScriptedClass {}
#end
