package flux.scripting;

#if FLUX_SCRIPTS_ALLOWED
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint.FlxBasePoint;
import flixel.math.FlxRect;
import flixel.tweens.FlxTween;
import flixel.util.FlxAxes;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import psychlua.CustomSubstate;
import psychlua.LuaUtils;

using StringTools;

/**
 * Lo que trae cada .hxs (y cada .luau) además del preset normal de Flux (game, add, setVar...).
 *
 * Clases listas para usar sin `import`: casi todo Flixel (sprites, grupos,
 * texto, tweens, timers, cámaras, sonido, barras, backdrop, trail...), cosas de
 * OpenFL (BitmapData, filtros, geometría), las clases de Psych (Paths,
 * Conductor, ClientPrefs, Character, Note, HealthIcon, estados y substates...)
 * y las de Haxe (Json, Reflect, Lambda, Date, EReg...).
 *
 * Funciones extra (resumen, ver README):
 *   getProperty('boyfriend.alpha') / setProperty('dad.visible', false)
 *   makeSprite(x, y, 'imagen'), makeAnimatedSprite(x, y, 'atlas'), makeText(x, y, ancho, 'texto', 24)
 *   addAnim(sprite, 'idle', 'prefijo', 24, true), playAnim(sprite, 'idle', true)
 *   tween(obj, {alpha: 0}, 1, 'quadOut', fin), tweenColor(obj, 1, desde, hasta), cancelTweens(obj)
 *   timer(1.5, function(t) {...}, 1), wait(1, funcion)
 *   playSound('nombre'), playMusic('nombre'), precacheImage('nombre')...
 *   getCamera('hud'), cameraShake('game', 0.01, 0.2), cameraFlash('hud', 0xFFFFFFFF, 0.5)
 *   color('#FF0000'), lerp(a, b, t), clamp(v, min, max), randomInt(0, 10), randomFloat(), randomBool(50)
 *   fileExists('data/x.json'), readFile('data/x.txt'), parseJson(texto), toJson(valor, true)
 *   callOnScripts('func', [args]), setOnScripts('var', valor), triggerEvent('Hey!', 'bf', '0.6')
 *   switchState('MiMenu'), resetState(), openCustomSubstate('nombre', true)
 *   importScript('scripts/utilidades')  // corre otro .hxs (o .luau) dentro de este
 *   mouseX(), mouseY(), mouseClicked(), mousePressed(), mouseOverlaps(sprite)
 */
class FluxHxsPreset
{
	/** Equivalentes de clases de otros engines y de tipos que en Haxe no existen en tiempo de ejecución. */
	public static function resolveImport(path:String):Dynamic
	{
		if (path == null)
			return null;
		switch (path)
		{
			// tipos de Flixel/OpenFL que no son clases en tiempo de ejecución
			case 'flixel.util.FlxColor':
				#if HSCRIPT_ALLOWED return psychlua.HScript.CustomFlxColor; #else return null; #end
			case 'flixel.math.FlxPoint':
				return FlxBasePoint;
			case 'flixel.group.FlxGroup':
				return flixel.group.FlxGroup.FlxTypedGroup;
			case 'flixel.group.FlxSpriteGroup':
				return flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
			case 'flixel.system.FlxSound':
				return flixel.sound.FlxSound;
			case 'flixel.util.FlxAxes':
				return axes();
			case 'flixel.text.FlxTextAlign' | 'flixel.text.FlxText.FlxTextAlign':
				return textAlign();
			case 'flixel.tweens.FlxTweenType' | 'flixel.tweens.FlxTween.FlxTweenType':
				return tweenType();
			case 'openfl.display.BlendMode':
				return blendModes();

			// Codename Engine -> Psych
			case 'funkin.game.PlayState' | 'funkin.play.PlayState':
				return states.PlayState;
			case 'funkin.backend.assets.Paths' | 'funkin.Paths':
				return backend.Paths;
			case 'funkin.backend.system.Conductor' | 'funkin.Conductor':
				return backend.Conductor;
			case 'funkin.backend.utils.CoolUtil' | 'funkin.util.CoolUtil':
				return backend.CoolUtil;
			case 'funkin.game.Character' | 'funkin.play.character.BaseCharacter':
				return objects.Character;
			case 'funkin.game.HealthIcon' | 'funkin.play.components.HealthIcon':
				return objects.HealthIcon;
			case 'funkin.game.Note' | 'funkin.play.notes.NoteSprite':
				return objects.Note;
			case 'funkin.game.Strum' | 'funkin.play.notes.StrumlineNote':
				return objects.StrumNote;
			case 'funkin.backend.MusicBeatState' | 'funkin.ui.MusicBeatState':
				return backend.MusicBeatState;
			case 'funkin.backend.MusicBeatSubstate' | 'funkin.ui.MusicBeatSubState':
				return backend.MusicBeatSubstate;
			case 'funkin.backend.FunkinSprite' | 'funkin.graphics.FunkinSprite':
				return flixel.FlxSprite;
			case 'funkin.backend.FunkinText':
				return flixel.text.FlxText;
			case 'funkin.menus.MainMenuState' | 'funkin.ui.mainmenu.MainMenuState':
				return states.MainMenuState;
			case 'funkin.menus.FreeplayState' | 'funkin.ui.freeplay.FreeplayState':
				return states.FreeplayState;
			case 'funkin.menus.StoryMenuState' | 'funkin.ui.story.StoryMenuState':
				return states.StoryMenuState;
			case 'funkin.menus.TitleState' | 'funkin.ui.title.TitleState':
				return states.TitleState;
			case 'funkin.options.OptionsMenu' | 'funkin.ui.options.OptionsState':
				return options.OptionsState;
			case 'funkin.backend.system.Controls':
				return backend.Controls;
			default:
		}
		return null;
	}

	public static function apply(script:FluxScript):Void
	{
		#if MODCHARTS_ALLOWED
		// ---------- Modcharts (FunkinModchart) ----------
		script.set('startModchart', flux.modchart.FluxModchart.start); // devuelve el modchart.Manager de la canción
		script.set('ModchartConfig', modchart.Config);
		#end

		// ---------- Haxe ----------
		script.set('Reflect', Reflect);
		script.set('Lambda', Lambda);
		script.set('Date', Date);
		script.set('DateTools', DateTools);
		script.set('EReg', EReg);
		script.set('Json', haxe.Json);
		script.set('Timer', haxe.Timer);
		script.set('StringMap', haxe.ds.StringMap);
		script.set('IntMap', haxe.ds.IntMap);
		script.set('ObjectMap', haxe.ds.ObjectMap);

		// ---------- Flixel ----------
		script.set('FlxBasic', FlxBasic);
		script.set('FlxObject', FlxObject);
		script.set('FlxState', FlxState);
		script.set('FlxSubState', FlxSubState);
		script.set('FlxSound', flixel.sound.FlxSound);
		script.set('FlxGroup', flixel.group.FlxGroup.FlxTypedGroup);
		script.set('FlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
		script.set('FlxSpriteGroup', flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup);
		script.set('FlxTypedSpriteGroup', flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup);
		script.set('FlxPoint', FlxBasePoint);
		script.set('FlxRect', FlxRect);
		script.set('FlxAngle', FlxAngle);
		script.set('FlxVelocity', flixel.math.FlxVelocity);
		script.set('FlxTextBorderStyle', flixel.text.FlxText.FlxTextBorderStyle);
		script.set('FlxGraphic', flixel.graphics.FlxGraphic);
		script.set('FlxAtlasFrames', flixel.graphics.frames.FlxAtlasFrames);
		script.set('FlxGradient', flixel.util.FlxGradient);
		script.set('FlxStringUtil', FlxStringUtil);
		script.set('FlxSort', FlxSort);
		script.set('FlxSave', flixel.util.FlxSave);
		script.set('FlxSpriteUtil', flixel.util.FlxSpriteUtil);
		script.set('FlxDestroyUtil', flixel.util.FlxDestroyUtil);
		script.set('FlxBar', flixel.ui.FlxBar);
		script.set('FlxBackdrop', flixel.addons.display.FlxBackdrop);
		script.set('FlxTrail', flixel.addons.effects.FlxTrail);
		script.set('FlxSkewedSprite', flixel.addons.effects.FlxSkewedSprite);
		script.set('FlxTransitionableState', flixel.addons.transition.FlxTransitionableState);
		script.set('FlxAxes', axes());
		script.set('FlxTextAlign', textAlign());
		script.set('FlxTweenType', tweenType());
		script.set('BlendMode', blendModes());

		// ---------- OpenFL ----------
		script.set('BitmapData', openfl.display.BitmapData);
		script.set('Lib', openfl.Lib);
		script.set('Assets', openfl.utils.Assets);
		script.set('Sound', openfl.media.Sound);
		script.set('BlurFilter', openfl.filters.BlurFilter);
		script.set('GlowFilter', openfl.filters.GlowFilter);
		script.set('ColorMatrixFilter', openfl.filters.ColorMatrixFilter);
		script.set('Rectangle', openfl.geom.Rectangle);
		script.set('Matrix', openfl.geom.Matrix);
		script.set('ColorTransform', openfl.geom.ColorTransform);

		// ---------- Psych ----------
		script.set('Controls', Controls);
		script.set('CoolUtil', CoolUtil);
		script.set('Difficulty', Difficulty);
		script.set('Mods', Mods);
		script.set('Highscore', backend.Highscore);
		script.set('Song', backend.Song);
		script.set('WeekData', backend.WeekData);
		script.set('StageData', backend.StageData);
		script.set('Language', Language);
		script.set('Rating', backend.Rating);
		script.set('MusicBeatState', MusicBeatState);
		script.set('MusicBeatSubstate', MusicBeatSubstate);
		script.set('CustomFadeTransition', CustomFadeTransition);
		script.set('BaseStage', BaseStage);
		script.set('LuaUtils', LuaUtils);
		script.set('StrumNote', objects.StrumNote);
		script.set('NoteSplash', objects.NoteSplash);
		script.set('HealthIcon', objects.HealthIcon);
		script.set('Bar', objects.Bar);
		script.set('BGSprite', BGSprite);
		script.set('AttachedSprite', objects.AttachedSprite);
		script.set('AttachedText', objects.AttachedText);
		script.set('TypedAlphabet', objects.TypedAlphabet);
		script.set('MenuItem', objects.MenuItem);
		script.set('MenuCharacter', objects.MenuCharacter);
		script.set('ModchartSprite', psychlua.ModchartSprite);
		#if VIDEOS_ALLOWED
		script.set('VideoSprite', objects.VideoSprite);
		#end
		script.set('TitleState', states.TitleState);
		script.set('MainMenuState', states.MainMenuState);
		script.set('StoryMenuState', states.StoryMenuState);
		script.set('FreeplayState', states.FreeplayState);
		script.set('OptionsState', options.OptionsState);
		script.set('LoadingState', LoadingState);
		script.set('PauseSubState', substates.PauseSubState);
		script.set('GameOverSubstate', substates.GameOverSubstate);
		#if DISCORD_ALLOWED
		script.set('DiscordClient', backend.Discord.DiscordClient);
		#end

		// ---------- Propiedades por texto (como en Lua) ----------
		script.set('getProperty', function(path:String):Dynamic return getPath(FlxG.state, path));
		script.set('setProperty', function(path:String, value:Dynamic):Dynamic return setPath(FlxG.state, path, value));
		script.set('getPropertyFromClass', function(classPath:String, path:String):Dynamic return getPath(resolveClass(classPath), path));
		script.set('setPropertyFromClass', function(classPath:String, path:String, value:Dynamic):Dynamic
			return setPath(resolveClass(classPath), path, value));

		// ---------- Sprites y texto ----------
		script.set('makeSprite', function(?x:Float = 0, ?y:Float = 0, ?image:String):FlxSprite {
			var sprite:FlxSprite = new FlxSprite(x, y);
			if (image != null && image.length > 0)
				sprite.loadGraphic(Paths.image(image));
			sprite.antialiasing = ClientPrefs.data.antialiasing;
			return sprite;
		});
		script.set('makeAnimatedSprite', function(?x:Float = 0, ?y:Float = 0, image:String):FlxSprite {
			var sprite:FlxSprite = new FlxSprite(x, y);
			sprite.frames = Paths.getAtlas(image);
			sprite.antialiasing = ClientPrefs.data.antialiasing;
			return sprite;
		});
		script.set('makeText', function(?x:Float = 0, ?y:Float = 0, ?width:Float = 0, ?text:String = '', ?size:Int = 24):FlxText {
			var txt:FlxText = new FlxText(x, y, width, text, size);
			txt.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			txt.borderSize = 1.25;
			return txt;
		});
		script.set('addAnim', function(sprite:FlxSprite, name:String, prefix:String, ?fps:Float = 24, ?loop:Bool = true, ?indices:Dynamic) {
			if (sprite == null)
				return;
			if (indices != null)
			{
				var list:Array<Int> = Std.isOfType(indices, String) ? [for (part in Std.string(indices).split(',')) Std.parseInt(part.trim())] : indices;
				sprite.animation.addByIndices(name, prefix, list, '', fps, loop);
			}
			else
				sprite.animation.addByPrefix(name, prefix, fps, loop);
		});
		script.set('playAnim', function(object:Dynamic, name:String, ?force:Bool = false) {
			if (object == null)
				return;
			if (Std.isOfType(object, objects.Character))
				(object : objects.Character).playAnim(name, force);
			else if (Reflect.getProperty(object, 'animation') != null)
				(object : FlxSprite).animation.play(name, force);
		});
		script.set('screenCenter', function(object:FlxObject, ?axes:String = 'xy') {
			if (object != null)
				object.screenCenter(switch (axes.toLowerCase())
				{
					case 'x': FlxAxes.X;
					case 'y': FlxAxes.Y;
					default: FlxAxes.XY;
				});
		});

		// ---------- Tweens y timers ----------
		script.set('tween', function(object:Dynamic, values:Dynamic, duration:Float, ?ease:Dynamic, ?onComplete:Dynamic):FlxTween {
			if (object == null)
				return null;
			return FlxTween.tween(object, values, duration, {ease: easeOf(ease), onComplete: completeOf(onComplete)});
		});
		script.set('tweenColor', function(object:FlxSprite, duration:Float, from:Int, to:Int, ?ease:Dynamic, ?onComplete:Dynamic):FlxTween {
			if (object == null)
				return null;
			return FlxTween.color(object, duration, from, to, {ease: easeOf(ease), onComplete: completeOf(onComplete)});
		});
		script.set('cancelTweens', function(object:Dynamic) FlxTween.cancelTweensOf(object));
		script.set('timer', function(seconds:Float, callback:Dynamic, ?loops:Int = 1):FlxTimer {
			return new FlxTimer().start(seconds, function(tmr:FlxTimer) callFunction(callback, [tmr]), loops);
		});
		script.set('wait', function(seconds:Float, callback:Dynamic):FlxTimer {
			return new FlxTimer().start(seconds, function(_) callFunction(callback, []));
		});

		// ---------- Sonido ----------
		script.set('playSound', function(name:String, ?volume:Float = 1, ?onComplete:Dynamic):FlxSound {
			return FlxG.sound.play(Paths.sound(name), volume, false, null, true, onComplete != null ? function() callFunction(onComplete, []) : null);
		});
		script.set('playMusic', function(name:String, ?volume:Float = 1, ?loop:Bool = true) FlxG.sound.playMusic(Paths.music(name), volume, loop));
		script.set('precacheImage', function(name:String) Paths.image(name));
		script.set('precacheSound', function(name:String) Paths.sound(name));
		script.set('precacheMusic', function(name:String) Paths.music(name));

		// ---------- Cámaras ----------
		script.set('getCamera', function(?name:String = 'game'):FlxCamera return cameraOf(name));
		script.set('cameraShake', function(camera:Dynamic, intensity:Float, duration:Float) {
			var cam:FlxCamera = cameraOf(camera);
			if (cam != null)
				cam.shake(intensity, duration);
		});
		script.set('cameraFlash', function(camera:Dynamic, ?flashColor:Int = 0xFFFFFFFF, ?duration:Float = 0.5, ?force:Bool = false) {
			var cam:FlxCamera = cameraOf(camera);
			if (cam != null)
				cam.flash(flashColor, duration, null, force);
		});
		script.set('cameraFade', function(camera:Dynamic, ?fadeColor:Int = 0xFF000000, ?duration:Float = 0.5, ?fadeIn:Bool = false, ?force:Bool = false) {
			var cam:FlxCamera = cameraOf(camera);
			if (cam != null)
				cam.fade(fadeColor, duration, fadeIn, null, force);
		});

		// ---------- Números y colores ----------
		script.set('color', function(value:Dynamic):FlxColor {
			if (Std.isOfType(value, String))
				return CoolUtil.colorFromString(value);
			return FlxColor.fromInt(Std.int(value));
		});
		script.set('lerp', function(a:Float, b:Float, ratio:Float):Float return FlxMath.lerp(a, b, ratio));
		script.set('clamp', function(value:Float, min:Float, max:Float):Float return FlxMath.bound(value, min, max));
		script.set('randomInt', function(?min:Int = 0, ?max:Int = 100):Int return FlxG.random.int(min, max));
		script.set('randomFloat', function(?min:Float = 0, ?max:Float = 1):Float return FlxG.random.float(min, max));
		script.set('randomBool', function(?chance:Float = 50):Bool return FlxG.random.bool(chance));

		// ---------- Archivos y JSON ----------
		script.set('fileExists', function(path:String):Bool return findFile(path) != null);
		script.set('readFile', function(path:String):String {
			var file:String = findFile(path);
			return file != null ? File.getContent(file) : null;
		});
		script.set('parseJson', function(text:String):Dynamic return haxe.Json.parse(text));
		script.set('toJson', function(value:Dynamic, ?pretty:Bool = false):String return haxe.Json.stringify(value, null, pretty ? '\t' : null));

		// ---------- Otros scripts y eventos ----------
		script.set('callOnScripts', function(name:String, ?args:Array<Dynamic>):Dynamic {
			var game:PlayState = PlayState.instance;
			return (game != null && FlxG.state == game) ? game.callOnScripts(name, args) : null;
		});
		script.set('callOnLuas', function(name:String, ?args:Array<Dynamic>):Dynamic {
			var game:PlayState = PlayState.instance;
			return (game != null && FlxG.state == game) ? game.callOnLuas(name, args) : null;
		});
		script.set('setOnScripts', function(name:String, value:Dynamic) {
			var game:PlayState = PlayState.instance;
			if (game != null && FlxG.state == game)
				game.setOnScripts(name, value);
		});
		script.set('triggerEvent', function(name:String, ?value1:String = '', ?value2:String = '') {
			var game:PlayState = PlayState.instance;
			if (game != null && FlxG.state == game)
				game.triggerEvent(name, value1, value2, Conductor.songPosition);
		});
		script.set('importScript', function(path:String):Bool {
			var ext:String = switch (script.language)
			{
				case 'Luau': '.luau';
				case 'SScript': '.ss';
				default: '.hxs';
			};
			var file:String = findFile(path);
			if (file == null && !path.endsWith(ext))
				file = findFile(path + ext);
			if (file == null)
			{
				FluxScript.onWarning(script, 'importScript: no existe "$path"');
				return false;
			}
			return script.executeCode(File.getContent(file));
		});

		// ---------- Estados ----------
		script.set('switchState', function(target:Dynamic) {
			var state:FlxState = stateOf(target);
			if (state != null)
				MusicBeatState.switchState(state);
			else
				FluxScript.onWarning(script, 'switchState: no existe el estado "$target"');
		});
		script.set('resetState', function() MusicBeatState.resetState());
		script.set('openCustomSubstate', function(name:String, ?pauseGame:Bool = false) CustomSubstate.openCustomSubstate(name, pauseGame));
		script.set('closeCustomSubstate', function() return CustomSubstate.closeCustomSubstate());

		// ---------- Mouse ----------
		script.set('mouseX', function():Float return FlxG.mouse.screenX);
		script.set('mouseY', function():Float return FlxG.mouse.screenY);
		script.set('mouseClicked', function(?button:String = 'left'):Bool {
			return switch (button.toLowerCase())
			{
				case 'right': FlxG.mouse.justPressedRight;
				case 'middle': FlxG.mouse.justPressedMiddle;
				default: FlxG.mouse.justPressed;
			}
		});
		script.set('mousePressed', function(?button:String = 'left'):Bool {
			return switch (button.toLowerCase())
			{
				case 'right': FlxG.mouse.pressedRight;
				case 'middle': FlxG.mouse.pressedMiddle;
				default: FlxG.mouse.pressed;
			}
		});
		script.set('mouseReleased', function(?button:String = 'left'):Bool {
			return switch (button.toLowerCase())
			{
				case 'right': FlxG.mouse.justReleasedRight;
				case 'middle': FlxG.mouse.justReleasedMiddle;
				default: FlxG.mouse.justReleased;
			}
		});
		script.set('mouseOverlaps', function(object:FlxObject, ?camera:FlxCamera):Bool {
			return object != null && FlxG.mouse.overlaps(object, camera);
		});
	}

	// ----- utilidades -----

	static function callFunction(fn:Dynamic, args:Array<Dynamic>):Dynamic
		return (fn != null && Reflect.isFunction(fn)) ? Reflect.callMethod(null, fn, args) : null;

	static function easeOf(ease:Dynamic):Float->Float
	{
		if (ease == null)
			return FlxEase.linear;
		if (Std.isOfType(ease, String))
			return LuaUtils.getTweenEaseByString(ease);
		return ease;
	}

	static function completeOf(onComplete:Dynamic):FlxTween->Void
	{
		if (onComplete == null || !Reflect.isFunction(onComplete))
			return null;
		return function(twn:FlxTween) callFunction(onComplete, [twn]);
	}

	static function cameraOf(camera:Dynamic):FlxCamera
	{
		if (camera == null)
			return FlxG.camera;
		if (Std.isOfType(camera, FlxCamera))
			return camera;
		var name:String = Std.string(camera).toLowerCase();
		if (PlayState.instance != null && FlxG.state == PlayState.instance)
			return LuaUtils.cameraFromString(name);
		return FlxG.camera;
	}

	static function resolveClass(path:String):Dynamic
	{
		var cls:Dynamic = Type.resolveClass(path);
		if (cls == null)
			cls = resolveImport(path);
		return cls;
	}

	/** Un estado por nombre ("MainMenuState", "options.OptionsState" o un menú hecho con script). */
	public static function stateOf(target:Dynamic):FlxState
	{
		if (target == null)
			return null;
		if (Std.isOfType(target, FlxState))
			return target;
		var name:String = Std.string(target);
		var cls:Dynamic = Type.resolveClass(name);
		if (cls == null)
			for (pack in ['states.', 'options.', 'states.editors.'])
			{
				cls = Type.resolveClass(pack + name);
				if (cls != null)
					break;
			}
		if (cls != null)
			return Type.createInstance(cls, []);
		// un estado hecho con un script (states/<nombre>.hxs)
		if (FluxStateScripts.stateFileExists(name))
			return new FluxScriptedState(name);
		return null;
	}

	/** Busca un archivo en los mods (actual y globales) y en assets. */
	public static function findFile(path:String):String
	{
		if (path == null || path.length == 0)
			return null;
		#if MODS_ALLOWED
		var modded:String = Paths.modFolders(path);
		if (FileSystem.exists(modded))
			return modded;
		#end
		var shared:String = Paths.getSharedPath(path);
		if (FileSystem.exists(shared))
			return shared;
		if (FileSystem.exists('assets/$path'))
			return 'assets/$path';
		return FileSystem.exists(path) ? path : null;
	}

	/** "boyfriend.scale.x" o "notes.members[0].alpha" -> valor. */
	public static function getPath(root:Dynamic, path:String):Dynamic
	{
		var target:Dynamic = root;
		for (part in splitPath(path))
		{
			if (target == null)
				return null;
			target = getPart(target, part);
		}
		return target;
	}

	public static function setPath(root:Dynamic, path:String, value:Dynamic):Dynamic
	{
		var parts:Array<String> = splitPath(path);
		if (parts.length == 0)
			return null;
		var last:String = parts.pop();
		var target:Dynamic = root;
		for (part in parts)
		{
			if (target == null)
				return null;
			target = getPart(target, part);
		}
		if (target == null)
			return null;
		var index:Null<Int> = Std.parseInt(last);
		if (index != null && Std.isOfType(target, Array))
			(target : Array<Dynamic>)[index] = value;
		else if (Std.isOfType(target, haxe.Constraints.IMap))
			(target : haxe.Constraints.IMap<Dynamic, Dynamic>).set(last, value);
		else
			Reflect.setProperty(target, last, value);
		return value;
	}

	static function getPart(target:Dynamic, part:String):Dynamic
	{
		var index:Null<Int> = Std.parseInt(part);
		if (index != null && Std.isOfType(target, Array))
			return (target : Array<Dynamic>)[index];
		if (Std.isOfType(target, haxe.Constraints.IMap))
			return (target : haxe.Constraints.IMap<Dynamic, Dynamic>).get(part);
		var value:Dynamic = Reflect.getProperty(target, part);
		// las variables de setVar/Lua (game.variables) también valen
		if (value == null && Std.isOfType(target, MusicBeatState))
		{
			var vars:Map<String, Dynamic> = (target : MusicBeatState).variables;
			if (vars != null && vars.exists(part))
				return vars.get(part);
		}
		return value;
	}

	static function splitPath(path:String):Array<String>
	{
		var result:Array<String> = [];
		if (path == null)
			return result;
		for (part in path.replace('[', '.').replace(']', '').split('.'))
			if (part.trim().length > 0)
				result.push(part.trim());
		return result;
	}

	static function axes():Dynamic
		return {X: FlxAxes.X, Y: FlxAxes.Y, XY: FlxAxes.XY, NONE: FlxAxes.NONE};

	static function textAlign():Dynamic
		return {LEFT: 'left', CENTER: 'center', RIGHT: 'right', JUSTIFY: 'justify'};

	static function tweenType():Dynamic
		return {
			PERSIST: FlxTweenType.PERSIST,
			LOOPING: FlxTweenType.LOOPING,
			PINGPONG: FlxTweenType.PINGPONG,
			ONESHOT: FlxTweenType.ONESHOT,
			BACKWARD: FlxTweenType.BACKWARD
		};

	static function blendModes():Dynamic
	{
		var modes:Dynamic = {};
		for (name in ['ADD', 'ALPHA', 'DARKEN', 'DIFFERENCE', 'ERASE', 'HARDLIGHT', 'INVERT', 'LAYER', 'LIGHTEN', 'MULTIPLY', 'NORMAL', 'OVERLAY', 'SCREEN', 'SHADER', 'SUBTRACT'])
			Reflect.setField(modes, name, LuaUtils.blendModeFromString(name.toLowerCase()));
		return modes;
	}
}
#end
