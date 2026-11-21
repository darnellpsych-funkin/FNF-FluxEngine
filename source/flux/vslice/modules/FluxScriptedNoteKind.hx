package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
/**
 * Tipo de nota de V-Slice cuyo código viene de un .hxc (`extends NoteKind` o
 * `extends ScriptedNoteKind`). Como FluxScriptedModule: la macro de RuleScript
 * genera el constructor y los overrides que llaman a las funciones del script.
 */
class FluxScriptedNoteKind extends flux.vslice.api.NoteKind implements rulescript.scriptedClass.RuleScriptedClass {}
#end
