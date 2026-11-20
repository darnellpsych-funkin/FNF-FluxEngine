package flux.scripting;

#if FLUX_SCRIPTS_ALLOWED
/**
 * Un menú hecho solo con un script: `switchState('MiMenu')` (desde un .hxs)
 * abre `states/MiMenu.hxs` del mod. FluxStateScripts le pasa las funciones
 * onCreate, onCreatePost, onUpdate, onBeatHit, onDestroy, etc.
 */
class FluxScriptedState extends MusicBeatState
{
	public var stateName(default, null):String;

	public function new(stateName:String)
	{
		super();
		this.stateName = stateName;
	}
}
#end
