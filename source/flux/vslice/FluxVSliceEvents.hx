package flux.vslice;

#if FLUX_VSLICE
import haxe.Json;
import flixel.tweens.FlxTween;
import psychlua.LuaUtils;

/**
 * Eventos de chart de V-Slice que Psych no tiene:
 *   ZoomCamera        {zoom, duration (steps), ease, mode: "stage" | "direct"}
 *   SetCameraBop      {rate (beats), intensity}
 *   SetHealthIcon     {char: 0 | 1, id}
 *   SetTargetBopSpeed {target, rate (beats)}
 * PlayAnimation, ScrollSpeed y los cambios de personaje (ChangeCharacter...) se
 * convierten a "Play Animation", "Change Scroll Speed" y "Change Character" al
 * cargar el chart (ver FluxVSlice).
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

			case 'SetHealthIcon':
				// {char: 0 (jugador) | 1 (oponente), id: "tankman-bloody"}
				var v:Dynamic = parse(value1);
				if (v == null || v.id == null) return;
				var opponent:Bool = Std.string(v.char) == '1';
				var icon:objects.HealthIcon = opponent ? game.iconP2 : game.iconP1;
				if (icon != null) icon.changeIcon(Std.string(v.id));

			case 'SetTargetBopSpeed':
				// {target: "boyfriend" | "dad" | "gf" | nombre de un prop, rate: cada cuántos beats baila}
				var v:Dynamic = parse(value1);
				if (v == null) return;
				var target:String = v.target != null ? Std.string(v.target).toLowerCase() : 'boyfriend';
				var rate:Float = v.rate != null ? v.rate : 1;
				var character:objects.Character = switch (target)
				{
					case 'boyfriend' | 'bf' | 'player': game.boyfriend;
					case 'dad' | 'opponent': game.dad;
					case 'girlfriend' | 'gf': game.gf;
					default: null;
				}
				if (character != null)
				{
					character.skipDance = rate <= 0;
					if (rate > 0) character.danceEveryNumBeats = Std.int(Math.max(1, Math.round(rate)));
				}
				else if (FluxVSliceStage.current != null)
				{
					var prop:VSliceProp = FluxVSliceStage.current.getNamedProp(v.target != null ? Std.string(v.target) : '');
					if (prop != null) prop.danceEvery = rate;
				}
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
