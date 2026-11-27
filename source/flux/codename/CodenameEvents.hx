package flux.codename;

#if FLUX_CODENAME
import backend.BaseStage;
import backend.Song.SwagSong;
import haxe.Json;
import psychlua.LuaUtils;

/**
 * Eventos de los charts de Codename Engine.
 *
 * Al cargar la canción (FluxMoonchart) los eventos del chart y de songs/<canción>/events.json
 * se pasan a eventos de Psych (ver CodenameData.events). Los que Psych no tiene los hace Flux
 * aquí, con todos los parámetros en el valor 1 (JSON):
 *   Camera Zoom, Camera Flash, Camera Modulo Change, HScript Call y Alt Animation Toggle.
 */
class CodenameEvents
{
	public static final BUILT_IN:Array<String> = ['Camera Zoom', 'Camera Flash', 'Camera Modulo Change', 'HScript Call', 'Alt Animation Toggle'];

	static var zoomTween:FlxTween;
	static var stageZoomFor:PlayState;
	static var stageZoom:Float = 1;
	static var bopper:CodenameBopper;
	static var bopperFor:PlayState;

	/** Cambia los eventos de la canción por los de Codename (chart + events.json) y marca las notas con animación alterna. */
	public static function applyToSong(song:SwagSong, chart:Dynamic, eventsPath:String):Void
	{
		if (song == null || chart == null) return;
		var list:Array<Dynamic> = Std.isOfType(chart.events, Array) ? (chart.events : Array<Dynamic>).copy() : [];
		if (eventsPath != null && FileSystem.exists(eventsPath))
		{
			try
			{
				var extra:Dynamic = Json.parse(File.getContent(eventsPath));
				if (extra != null && Std.isOfType(extra.events, Array))
					for (e in (extra.events : Array<Dynamic>)) list.push(e);
			}
			catch (e:Dynamic)
			{
				trace('[Flux Codename] events.json inválido: $eventsPath ($e)');
			}
		}
		var lines:Array<Dynamic> = Std.isOfType(chart.strumLines, Array) ? chart.strumLines : [];
		var speed:Float = chart.scrollSpeed != null ? chart.scrollSpeed : song.speed;
		var result:Dynamic = CodenameData.events(list, lines, speed, song.bpm);
		song.events = result.events;
		markAltNotes(song, result.alt, lines);
	}

	/** "Alt Animation Toggle": las notas de esa strumLine usan las animaciones -alt mientras está activo. */
	static function markAltNotes(song:SwagSong, toggles:Array<Dynamic>, lines:Array<Dynamic>):Void
	{
		if (toggles == null || toggles.length == 0 || song.notes == null) return;
		var keys:Int = flux.keys.FluxKeysData.chartKeys(song);
		for (section in song.notes)
		{
			if (section == null || section.sectionNotes == null) continue;
			for (raw in section.sectionNotes)
			{
				var note:Array<Dynamic> = raw;
				if (note == null || note.length < 2) continue;
				var lane:Int = Std.int(note[1]);
				if (lane < 0) continue;
				var role:String = lane < keys ? 'bf' : 'dad';
				var time:Float = note[0];
				var enabled:Bool = false;
				for (toggle in toggles)
				{
					if (toggle.time > time + 1) break;
					if (CodenameData.roleOf(lines, toggle.line) == role) enabled = toggle.enabled == true;
				}
				if (!enabled) continue;
				while (note.length < 4) note.push(0);
				var type:Dynamic = note[3];
				if (type == null || type == '' || type == 0) note[3] = 'Alt Animation';
			}
		}
	}

	/** Lo llama PlayState.triggerEvent con cada evento. */
	public static function trigger(game:PlayState, name:String, value1:String, value2:String):Void
	{
		if (!BUILT_IN.contains(name)) return;
		var params:Array<Dynamic> = null;
		try
		{
			var parsed:Dynamic = Json.parse(value1);
			if (Std.isOfType(parsed, Array)) params = parsed;
		}
		catch (e:Dynamic) {}
		if (params == null) return; // no es un evento de Codename (otro mod usa el mismo nombre)

		inline function param(i:Int):Dynamic
			return i < params.length ? params[i] : null;
		inline function steps(i:Int, fallback:Float):Float
		{
			var v:Dynamic = param(i);
			var n:Float = (v == null) ? fallback : Std.parseFloat(Std.string(v));
			return (Math.isNaN(n) ? fallback : n) * Conductor.stepCrochet / 1000 / game.playbackRate;
		}

		switch (name)
		{
			case 'Camera Zoom':
				// [tween, zoom, cámara, duración (steps), ease, dirección, "direct"/"stage", multiplicar]
				var hud:Bool = param(2) == 'camHUD';
				if (stageZoomFor != game)
				{
					stageZoomFor = game;
					stageZoom = game.defaultCamZoom;
				}
				var zoom:Float = toFloat(param(1), 1);
				var target:Float = (param(6) == 'direct' || hud) ? zoom : zoom * stageZoom;
				if (param(7) == true) target *= hud ? game.camHUD.zoom : FlxG.camera.zoom;
				if (hud)
				{
					// Psych vuelve el HUD a 1 solo; el cambio dura hasta el próximo bop
					game.camHUD.zoom = target;
					return;
				}
				if (zoomTween != null) zoomTween.cancel();
				if (param(0) == false || param(4) == 'CLASSIC')
				{
					game.defaultCamZoom = target;
					if (param(0) == false) FlxG.camera.zoom = target;
				}
				else
				{
					var ease:String = (param(4) != null ? Std.string(param(4)) : 'linear') + (param(5) != null ? Std.string(param(5)) : '');
					zoomTween = FlxTween.tween(game, {defaultCamZoom: target}, steps(3, 4), {
						ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: (_) -> zoomTween = null
					});
				}

			case 'Camera Flash':
				// [al revés (fade), color, duración (steps), cámara]
				var camera:FlxCamera = param(3) == 'camHUD' ? game.camHUD : game.camGame;
				var color:FlxColor = colorOf(param(1));
				if (param(0) == true) camera.fade(color, steps(2, 4), false, null, true);
				else camera.flash(color, steps(2, 4), null, true);

			case 'Camera Modulo Change':
				// [cada cuántos beats, fuerza, "BEAT"/"STEP"/"MEASURE", desfase]
				if (bopper == null || bopperFor != game)
				{
					bopper = new CodenameBopper(); // se agrega a los escenarios del PlayState y recibe los beats
					bopperFor = game;
				}
				var every:String = param(2) != null ? Std.string(param(2)).toUpperCase() : 'BEAT';
				var interval:Float = toFloat(param(0), 4);
				bopper.intervalBeats = switch (every)
				{
					case 'STEP': interval / 4;
					case 'MEASURE': interval * 4;
					default: interval;
				}
				bopper.strength = toFloat(param(1), 1);
				bopper.offset = Std.int(toFloat(param(3), 0));
				game.camZoomingMult = 0; // los bops los hace el bopper en el beat que pide Codename

			case 'HScript Call':
				// [función, "arg1,arg2"]
				var args:Array<Dynamic> = param(1) != null && Std.string(param(1)).length > 0 ? cast Std.string(param(1)).split(',') : [];
				if (param(0) != null) game.callOnScripts(Std.string(param(0)), args);

			case 'Alt Animation Toggle':
				// [notas -alt, idle -alt, strumLine]; las notas ya vienen marcadas desde el chart
				var char:objects.Character = switch (value2)
				{
					case 'bf': game.boyfriend;
					case 'gf': game.gf;
					default: game.dad;
				}
				if (char != null)
				{
					char.idleSuffix = (param(0) == true && param(1) == true) ? '-alt' : '';
					char.recalculateDanceIdle();
				}
		}
	}

	static function toFloat(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var n:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(n) ? fallback : n;
	}

	static function colorOf(value:Dynamic):FlxColor
	{
		if (value == null) return FlxColor.WHITE;
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return FlxColor.fromInt(Std.int(value));
		var color:Null<FlxColor> = FlxColor.fromString(Std.string(value));
		return color != null ? color : FlxColor.WHITE;
	}
}

/** Los bops de cámara de "Camera Modulo Change" (cada N beats, con la fuerza que pide el chart). */
class CodenameBopper extends BaseStage
{
	public var intervalBeats:Float = 4;
	public var strength:Float = 1;
	public var offset:Int = 0;

	override function beatHit()
	{
		var g:PlayState = PlayState.instance;
		if (g == null || intervalBeats <= 0 || !g.camZooming || !ClientPrefs.data.camZooms || FlxG.camera.zoom >= 1.35) return;
		if (intervalBeats >= 1)
		{
			var every:Int = Std.int(Math.max(1, Math.round(intervalBeats)));
			if ((curBeat + offset) % every != 0) return;
		}
		FlxG.camera.zoom += 0.015 * strength;
		g.camHUD.zoom += 0.03 * strength;
	}
}
#end
