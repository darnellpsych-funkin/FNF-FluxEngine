package flux.vslice;

#if FLUX_VSLICE
import haxe.Json;
import flixel.tweens.FlxTween;
import psychlua.LuaUtils;

/**
 * Eventos de chart de V-Slice que Psych no tiene:
 *   ZoomCamera   {zoom, duration (steps), ease, mode: "stage" | "direct"}
 *   SetCameraBop {rate (beats), intensity}
 * PlayAnimation y ScrollSpeed se convierten a "Play Animation" y
 * "Change Scroll Speed" al cargar el chart (ver FluxVSlice).
 * Cualquier otro evento llega a onEvent de los scripts, con el valor1 en JSON.
 */
class FluxVSliceEvents
{
	static var zoomTween:FlxTween;
	static var stageZoomFor:PlayState;
	static var stageZoom:Float = 1;

	public static function trigger(game:PlayState, eventName:String, value1:String, value2:String)
	{
		switch (eventName)
		{
			case 'ZoomCamera':
				var v:Dynamic = parse(value1);
				if (v == null) return;
				if (stageZoomFor != game)
				{
					stageZoomFor = game;
					stageZoom = game.defaultCamZoom;
				}
				var zoom:Float = v.zoom != null ? v.zoom : 1;
				// "direct" (por defecto en V-Slice) = zoom absoluto; "stage" = relativo al zoom del escenario
				var target:Float = (v.mode == 'stage') ? stageZoom * zoom : zoom;
				var steps:Float = v.duration != null ? v.duration : 4;
				var ease:String = v.ease != null ? Std.string(v.ease) : 'linear';

				if (zoomTween != null) zoomTween.cancel();
				if (ease.toUpperCase() == 'INSTANT' || steps <= 0)
				{
					game.defaultCamZoom = target;
					FlxG.camera.zoom = target;
				}
				else
				{
					var seconds:Float = steps * Conductor.stepCrochet / 1000 / game.playbackRate;
					zoomTween = FlxTween.tween(game, {defaultCamZoom: target}, seconds, {
						ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(_) zoomTween = null
					});
				}

			case 'SetCameraBop':
				var v:Dynamic = parse(value1);
				if (v == null) return;
				var rate:Float = v.rate != null ? v.rate : 4;
				var intensity:Float = v.intensity != null ? v.intensity : 1.015;
				// Psych hace el "bop" en cada sección; se ajusta la fuerza (rate 0 = sin bop)
				game.camZoomingMult = rate <= 0 ? 0 : Math.max(0, (intensity - 1) / 0.015);
		}
	}

	static function parse(value:String):Dynamic
	{
		if (value == null || value.length == 0) return null;
		try
		{
			return Json.parse(value);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
}
#end
