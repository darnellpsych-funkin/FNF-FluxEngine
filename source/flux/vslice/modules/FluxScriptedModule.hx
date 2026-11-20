package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
/**
 * Módulo de V-Slice cuyo código viene de un .hxc.
 *
 * La macro de RuleScript (RuleScriptedClass) genera:
 *  - el constructor `new(nombreDeLaClase, [args])`, que ejecuta el `new()`
 *    del script (incluido su `super(...)`);
 *  - un override de cada función de Module que llama a la del script si
 *    existe (y `super.onUpdate(event)` en el script llama a la de Module).
 */
class FluxScriptedModule extends flux.vslice.api.Module implements rulescript.scriptedClass.RuleScriptedClass {}
#end
