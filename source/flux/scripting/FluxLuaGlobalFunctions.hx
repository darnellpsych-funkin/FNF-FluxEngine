package flux.scripting;

#if LUA_GLOBAL_ALLOWED
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.FlxState;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxSave;
import flixel.util.FlxTimer;
import backend.WeekData;
import psychlua.LuaUtils;
import psychlua.ModchartSprite;
import substates.GameOverSubstate;

using StringTools;

/**
 * Las funciones de los `.luag`. Tienen los mismos nombres y argumentos que las de
 * Psych, pero funcionan en cualquier menú: donde Psych usa la canción, acá se usa
 * el estado actual ("game" es el menú, o la canción si estás jugando).
 *
 * En las canciones, lo propio de la canción se hace con getProperty/setProperty/
 * callMethod (por ejemplo setProperty('health', 2)).
 */
class FluxLuaGlobalFunctions
{
	public static function implement(script:FluxLuaGlobal):Void
	{
		defaults(script);
		reflection(script);
		sprites(script);
		texts(script);
		tweensAndTimers(script);
		sounds(script);
		input(script);
		other(script);
	}

	// ------------------------------------------------------------------
	// Ayudas
	// ------------------------------------------------------------------

	/** Lo que en Psych es "game": la canción (o el game over) o el menú actual. */
	public static function target():Dynamic
	{
		if (inSong())
			return (PlayState.instance.isDead && GameOverSubstate.instance != null) ? GameOverSubstate.instance : PlayState.instance;
		return FlxG.state;
	}

	public static inline function inSong():Bool
		return PlayState.instance != null && FlxG.state == PlayState.instance;

	/** setVar/getVar y los tags de los sprites viven en el estado actual (como en Psych). */
	public static function variables(script:FluxLuaGlobal):Map<String, Dynamic>
	{
		if (Std.isOfType(FlxG.state, MusicBeatState))
			return MusicBeatState.getVariables();
		return script.looseVariables;
	}

	static function getIn(instance:Dynamic, field:String, allowMaps:Bool = false):Dynamic
	{
		if (instance == null)
			return null;
		if (Std.isOfType(FlxG.state, MusicBeatState))
			return LuaUtils.getVarInArray(instance, field, allowMaps);
		return Reflect.getProperty(instance, field);
	}

	static function setIn(instance:Dynamic, field:String, value:Dynamic, allowMaps:Bool = false):Void
	{
		if (Std.isOfType(FlxG.state, MusicBeatState))
			LuaUtils.setVarInArray(instance, field, value, allowMaps);
		else
			Reflect.setProperty(instance, field, value);
	}

	/** Un nombre suelto: un tag (makeLuaSprite, createInstance...) o un campo del estado. */
	public static function objectDirectly(script:FluxLuaGlobal, name:String):Dynamic
	{
		switch (name)
		{
			case 'this' | 'instance' | 'game':
				return target();
			default:
				var obj:Dynamic = variables(script).get(name);
				if (obj == null)
					obj = getIn(FlxG.state, name);
				return obj;
		}
	}

	/** El objeto que tiene el último campo de "a.b.c" (o sea "a.b"). */
	static function owner(script:FluxLuaGlobal, split:Array<String>, allowMaps:Bool = false):Dynamic
	{
		var obj:Dynamic = objectDirectly(script, split[0]);
		for (i in 1...split.length - 1)
		{
			if (obj == null)
				return null;
			obj = getIn(obj, split[i], allowMaps);
		}
		return obj;
	}

	/** "boyfriend.scale" -> el objeto (también tags y "game"). */
	public static function objectOf(script:FluxLuaGlobal, path:String):Dynamic
	{
		var split:Array<String> = path.split('.');
		if (split.length > 1)
			return getIn(owner(script, split), split[split.length - 1]);
		return objectDirectly(script, split[0]);
	}

	public static function getProperty(script:FluxLuaGlobal, variable:String, allowMaps:Bool = false):Dynamic
	{
		var split:Array<String> = variable.split('.');
		if (split.length > 1)
			return getIn(owner(script, split, allowMaps), split[split.length - 1], allowMaps);
		var vars = variables(script);
		if (vars.exists(variable))
			return vars.get(variable);
		return getIn(target(), variable, allowMaps);
	}

	public static function setProperty(script:FluxLuaGlobal, variable:String, value:Dynamic, allowMaps:Bool = false):Dynamic
	{
		var split:Array<String> = variable.split('.');
		var obj:Dynamic = split.length > 1 ? owner(script, split, allowMaps) : target();
		if (obj == null)
			throw 'no existe "$variable"';
		setIn(obj, split[split.length - 1], value, allowMaps);
		return value;
	}

	public static function cameraOf(name:String):FlxCamera
	{
		if (name == null)
			name = 'game';
		if (inSong())
			return LuaUtils.cameraFromString(name);
		if (Std.isOfType(FlxG.state, MusicBeatState))
		{
			var cam:Dynamic = MusicBeatState.getVariables().get(name);
			if (cam != null && Std.isOfType(cam, FlxCamera))
				return cam;
		}
		return FlxG.camera;
	}

	/** debugPrint: en las canciones sale en pantalla; en los menús, en la consola. */
	public static function print(text:String, color:FlxColor = FlxColor.WHITE):Void
	{
		if (inSong())
			PlayState.instance.addTextToDebug(text, color);
		else
			trace(text);
	}

	/** Avisos de las funciones (solo si el script puso luaDebugMode = true, como en Psych). */
	static function warn(script:FluxLuaGlobal, text:String):Void
	{
		if (script.get('luaDebugMode') == true)
			print(text, FlxColor.RED);
	}

	static function textOf(script:FluxLuaGlobal, tag:String, func:String):FlxText
	{
		var obj:Dynamic = objectOf(script, tag);
		if (obj != null && Std.isOfType(obj, FlxText))
			return obj;
		warn(script, '$func: no existe el texto "$tag"');
		return null;
	}

	static function spriteOf(script:FluxLuaGlobal, tag:String, func:String):FlxSprite
	{
		var obj:Dynamic = objectOf(script, tag);
		if (obj != null && Std.isOfType(obj, FlxSprite))
			return obj;
		warn(script, '$func: no existe el objeto "$tag"');
		return null;
	}

	static function soundOf(script:FluxLuaGlobal, tag:String):FlxSound
	{
		if (tag == null || tag.length < 1)
			return FlxG.sound.music;
		return script.sounds.get(tag);
	}

	static function destroyTag(script:FluxLuaGlobal, tag:String):Void
	{
		var vars = variables(script);
		var obj:Dynamic = vars.get(tag);
		if (obj == null || !Std.isOfType(obj, FlxBasic))
			return;
		var basic:FlxBasic = obj;
		var instance:Dynamic = target();
		if (instance != null && instance.remove != null)
			instance.remove(basic, true);
		basic.destroy();
		vars.remove(tag);
	}

	static function addToState(obj:FlxBasic, inFront:Bool):Void
	{
		var instance:Dynamic = target();
		if (inFront || !inSong())
		{
			instance.add(obj);
			return;
		}
		if (!PlayState.instance.isDead)
			instance.insert(instance.members.indexOf(LuaUtils.getLowestCharacterGroup()), obj);
		else
			GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), obj);
	}

	public static function updateStateVariables(script:FluxLuaGlobal, state:Dynamic):Void
	{
		var name:String = Std.isOfType(state, FlxState) ? FluxStateScripts.stateNameOf(state) : Std.string(state);
		var song:Bool = Std.isOfType(state, PlayState);
		script.set('curState', name);
		script.set('inSong', song);
		if (!song || PlayState.SONG == null)
			return;
		script.set('songName', PlayState.SONG.song);
		script.set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
		script.set('bpm', PlayState.SONG.bpm);
		script.set('scrollSpeed', PlayState.SONG.speed);
		script.set('curStage', PlayState.SONG.stage);
		script.set('hasVocals', PlayState.SONG.needsVoices);
		script.set('isStoryMode', PlayState.isStoryMode);
		script.set('difficulty', PlayState.storyDifficulty);
		script.set('difficultyName', Difficulty.getString(false));
		script.set('weekRaw', PlayState.storyWeek);
		script.set('week', WeekData.weeksList[PlayState.storyWeek]);
		script.set('seenCutscene', PlayState.seenCutscene);
		script.set('deaths', PlayState.deathCounter);
	}

	/** Flixel borra los tweens y los sonidos al cambiar de estado; acá se olvidan sus tags. */
	public static function onStateSwitch(script:FluxLuaGlobal):Void
	{
		script.tweens.clear();
		script.sounds.clear();
	}

	// ------------------------------------------------------------------
	// Variables
	// ------------------------------------------------------------------

	static function defaults(script:FluxLuaGlobal):Void
	{
		script.set('Function_StopLua', LuaUtils.Function_StopLua);
		script.set('Function_StopHScript', LuaUtils.Function_StopHScript);
		script.set('Function_StopAll', LuaUtils.Function_StopAll);
		script.set('Function_Stop', LuaUtils.Function_Stop);
		script.set('Function_Continue', LuaUtils.Function_Continue);
		script.set('luaDebugMode', false);
		script.set('luaDeprecatedWarnings', true);
		script.set('version', states.MainMenuState.psychEngineVersion.trim());
		script.set('scriptName', script.origin);
		script.set('screenWidth', FlxG.width);
		script.set('screenHeight', FlxG.height);
		script.set('buildTarget', LuaUtils.getBuildTarget());
		script.set('inSong', false);
		script.set('curState', '');
		script.set('isGlobalScript', true);

		script.set('downscroll', ClientPrefs.data.downScroll);
		script.set('middlescroll', ClientPrefs.data.middleScroll);
		script.set('framerate', ClientPrefs.data.framerate);
		script.set('ghostTapping', ClientPrefs.data.ghostTapping);
		script.set('hideHud', ClientPrefs.data.hideHud);
		script.set('timeBarType', ClientPrefs.data.timeBarType);
		script.set('scoreZoom', ClientPrefs.data.scoreZoom);
		script.set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
		script.set('flashingLights', ClientPrefs.data.flashing);
		script.set('noteOffset', ClientPrefs.data.noteOffset);
		script.set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
		script.set('noResetButton', ClientPrefs.data.noReset);
		script.set('lowQuality', ClientPrefs.data.lowQuality);
		script.set('shadersEnabled', ClientPrefs.data.shaders);
	}

	// ------------------------------------------------------------------
	// Propiedades y métodos
	// ------------------------------------------------------------------

	static function reflection(script:FluxLuaGlobal):Void
	{
		script.addCallback('getProperty', function(variable:String, ?allowMaps:Bool = false) {
			return getProperty(script, variable, allowMaps);
		});
		script.addCallback('setProperty', function(variable:String, value:Dynamic, ?allowMaps:Bool = false) {
			return setProperty(script, variable, value, allowMaps);
		});
		script.addCallback('getPropertyFromClass', function(classVar:String, variable:String, ?allowMaps:Bool = false) {
			var cls:Dynamic = resolveClass(classVar);
			if (cls == null)
				throw 'no existe la clase $classVar';
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = cls;
			for (i in 0...split.length - 1)
				obj = getIn(obj, split[i], allowMaps);
			return getIn(obj, split[split.length - 1], allowMaps);
		});
		script.addCallback('setPropertyFromClass', function(classVar:String, variable:String, value:Dynamic, ?allowMaps:Bool = false) {
			var cls:Dynamic = resolveClass(classVar);
			if (cls == null)
				throw 'no existe la clase $classVar';
			var split:Array<String> = variable.split('.');
			var obj:Dynamic = cls;
			for (i in 0...split.length - 1)
				obj = getIn(obj, split[i], allowMaps);
			setIn(obj, split[split.length - 1], value, allowMaps);
			return value;
		});
		script.addCallback('getPropertyFromGroup', function(group:String, index:Int, variable:Dynamic, ?allowMaps:Bool = false) {
			var item:Dynamic = groupItem(script, group, index);
			if (item == null)
				return null;
			if (Type.typeof(variable) == TInt)
				return item[variable];
			return LuaUtils.getGroupStuff(item, variable, allowMaps);
		});
		script.addCallback('setPropertyFromGroup', function(group:String, index:Int, variable:Dynamic, value:Dynamic, ?allowMaps:Bool = false) {
			var item:Dynamic = groupItem(script, group, index);
			if (item == null)
				return value;
			if (Type.typeof(variable) == TInt)
				item[variable] = value;
			else
				LuaUtils.setGroupStuff(item, variable, value, allowMaps);
			return value;
		});
		script.addCallback('callMethod', function(funcToRun:String, ?args:Array<Dynamic>) {
			var parent:Dynamic = target();
			var split:Array<String> = funcToRun.split('.');
			var saved:Dynamic = variables(script).get(split[0].trim());
			if (saved != null)
			{
				split.shift();
				parent = saved;
			}
			if (split.length == 0)
				return Reflect.callMethod(null, parent, args != null ? args : []);
			return callPath(parent, split, args);
		});
		script.addCallback('callMethodFromClass', function(className:String, funcToRun:String, ?args:Array<Dynamic>) {
			var cls:Dynamic = resolveClass(className);
			if (cls == null)
				throw 'no existe la clase $className';
			return callPath(cls, funcToRun.split('.'), args);
		});
		script.addCallback('createInstance', function(variableToSave:String, className:String, ?args:Array<Dynamic>) {
			variableToSave = variableToSave.trim().replace('.', '');
			var cls:Dynamic = resolveClass(className);
			if (cls == null)
				throw 'no existe la clase $className';
			var obj:Dynamic = Type.createInstance(cls, args != null ? args : []);
			if (obj == null)
				return false;
			variables(script).set(variableToSave, obj);
			return true;
		});
		script.addCallback('addInstance', function(objectName:String, ?inFront:Bool = false) {
			var obj:Dynamic = variables(script).get(objectName);
			if (obj == null || !Std.isOfType(obj, FlxBasic))
				throw 'no existe "$objectName"';
			addToState(obj, inFront);
		});
		script.addCallback('getObjectOrder', function(obj:String, ?group:String = null) {
			var basic:Dynamic = objectOf(script, obj);
			var container:Dynamic = group != null ? objectOf(script, group) : target();
			if (basic == null || container == null)
				return -1;
			var list:Dynamic = Std.isOfType(container, Array) ? container : Reflect.getProperty(container, 'members');
			return list != null ? list.indexOf(basic) : -1;
		});
		script.addCallback('setObjectOrder', function(obj:String, position:Int, ?group:String = null) {
			var basic:Dynamic = objectOf(script, obj);
			var container:Dynamic = group != null ? objectOf(script, group) : target();
			if (basic == null || container == null)
				return;
			if (Std.isOfType(container, Array))
			{
				container.remove(basic);
				container.insert(position, basic);
			}
			else
			{
				container.remove(basic, true);
				container.insert(position, basic);
			}
		});
		script.addCallback('objectsOverlap', function(obj1:String, obj2:String) {
			var a:Dynamic = objectOf(script, obj1);
			var b:Dynamic = objectOf(script, obj2);
			return a != null && b != null && FlxG.overlap(a, b);
		});
	}

	static function resolveClass(name:String):Dynamic
	{
		var cls:Dynamic = Type.resolveClass(name);
		if (cls == null)
			cls = Type.resolveEnum(name);
		#if FLUX_SCRIPTS_ALLOWED
		if (cls == null)
			cls = FluxHxsPreset.resolveImport(name);
		#end
		return cls;
	}

	static function groupItem(script:FluxLuaGlobal, group:String, index:Int):Dynamic
	{
		var obj:Dynamic = objectOf(script, group);
		if (obj == null)
			throw 'no existe el grupo "$group"';
		if (Std.isOfType(obj, Array))
			return obj[index];
		var members:Dynamic = Reflect.getProperty(obj, 'members');
		return members != null ? members[index] : null;
	}

	static function callPath(parent:Dynamic, split:Array<String>, args:Array<Dynamic>):Dynamic
	{
		var obj:Dynamic = parent;
		var owner:Dynamic = null;
		for (part in split)
		{
			if (obj == null)
				return null;
			owner = obj;
			obj = getIn(obj, part.trim());
		}
		if (obj == null || !Reflect.isFunction(obj))
			throw 'no existe la función "${split.join('.')}"';
		return Reflect.callMethod(owner, obj, args != null ? args : []);
	}

	// ------------------------------------------------------------------
	// Sprites
	// ------------------------------------------------------------------

	static function sprites(script:FluxLuaGlobal):Void
	{
		script.addCallback('makeLuaSprite', function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			destroyTag(script, tag);
			var spr:ModchartSprite = new ModchartSprite(x, y);
			if (image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image));
			variables(script).set(tag, spr);
			spr.active = true;
		});
		script.addCallback('makeAnimatedLuaSprite', function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			destroyTag(script, tag);
			var spr:ModchartSprite = new ModchartSprite(x, y);
			if (image != null && image.length > 0)
				LuaUtils.loadFrames(spr, image, spriteType);
			variables(script).set(tag, spr);
		});
		script.addCallback('makeGraphic', function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = spriteOf(script, obj, 'makeGraphic');
			if (spr != null)
				spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		script.addCallback('loadGraphic', function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var spr:FlxSprite = spriteOf(script, variable, 'loadGraphic');
			if (spr != null && image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image), gridX != 0 || gridY != 0, gridX, gridY);
		});
		script.addCallback('loadFrames', function(variable:String, image:String, spriteType:String = 'auto') {
			var spr:FlxSprite = spriteOf(script, variable, 'loadFrames');
			if (spr != null && image != null && image.length > 0)
				LuaUtils.loadFrames(spr, image, spriteType);
		});
		script.addCallback('addAnimationByPrefix', function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var spr:FlxSprite = spriteOf(script, obj, 'addAnimationByPrefix');
			if (spr == null || spr.animation == null)
				return false;
			spr.animation.addByPrefix(name, prefix, framerate, loop);
			if (spr.animation.curAnim == null)
				playOn(spr, name, true);
			return true;
		});
		script.addCallback('addAnimation', function(obj:String, name:String, frames:Dynamic, framerate:Float = 24, loop:Bool = true) {
			return addAnimByIndices(script, 'addAnimation', obj, name, null, frames, framerate, loop);
		});
		script.addCallback('addAnimationByIndices', function(obj:String, name:String, prefix:String, indices:Dynamic, framerate:Float = 24, loop:Bool = false) {
			return addAnimByIndices(script, 'addAnimationByIndices', obj, name, prefix, indices, framerate, loop);
		});
		script.addCallback('playAnim', function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			var target:Dynamic = objectOf(script, obj);
			if (target == null)
				return false;
			if (target.playAnim != null)
				target.playAnim(name, forced, reverse, startFrame);
			else if (target.anim != null) // FlxAnimate
				target.anim.play(name, forced, reverse, startFrame);
			else if (target.animation != null)
				target.animation.play(name, forced, reverse, startFrame);
			return true;
		});
		script.addCallback('addOffset', function(obj:String, anim:String, x:Float, y:Float) {
			var target:Dynamic = objectOf(script, obj);
			if (target == null || target.addOffset == null)
				return false;
			target.addOffset(anim, x, y);
			return true;
		});
		script.addCallback('addLuaSprite', function(tag:String, ?inFront:Bool = false) {
			var spr:Dynamic = variables(script).get(tag);
			if (spr != null && Std.isOfType(spr, FlxBasic))
				addToState(spr, inFront);
		});
		script.addCallback('removeLuaSprite', function(tag:String, destroy:Bool = true, ?group:String = null) {
			var obj:Dynamic = objectOf(script, tag);
			if (obj == null || !Std.isOfType(obj, FlxBasic))
				return;
			var container:Dynamic = group != null ? objectOf(script, group) : target();
			if (container != null)
				container.remove(obj, true);
			if (destroy)
			{
				variables(script).remove(tag);
				(obj : FlxBasic).destroy();
			}
		});
		script.addCallback('luaSpriteExists', function(tag:String) {
			var obj:Dynamic = variables(script).get(tag);
			return obj != null && Std.isOfType(obj, FlxSprite);
		});
		script.addCallback('setScrollFactor', function(obj:String, scrollX:Float, scrollY:Float) {
			var object:Dynamic = objectOf(script, obj);
			if (object != null && Std.isOfType(object, FlxObject))
				(object : FlxObject).scrollFactor.set(scrollX, scrollY);
		});
		script.addCallback('scaleObject', function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var spr:FlxSprite = spriteOf(script, obj, 'scaleObject');
			if (spr == null)
				return;
			spr.scale.set(x, y);
			if (updateHitbox)
				spr.updateHitbox();
		});
		script.addCallback('setGraphicSize', function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var spr:FlxSprite = spriteOf(script, obj, 'setGraphicSize');
			if (spr == null)
				return;
			spr.setGraphicSize(x, y);
			if (updateHitbox)
				spr.updateHitbox();
		});
		script.addCallback('updateHitbox', function(obj:String) {
			var spr:FlxSprite = spriteOf(script, obj, 'updateHitbox');
			if (spr != null)
				spr.updateHitbox();
		});
		script.addCallback('screenCenter', function(obj:String, pos:String = 'xy') {
			var object:Dynamic = objectOf(script, obj);
			if (object == null || !Std.isOfType(object, FlxObject))
				return;
			switch (pos.trim().toLowerCase())
			{
				case 'x':
					(object : FlxObject).screenCenter(X);
				case 'y':
					(object : FlxObject).screenCenter(Y);
				default:
					(object : FlxObject).screenCenter(XY);
			}
		});
		script.addCallback('setObjectCamera', function(obj:String, camera:String = 'game') {
			var object:Dynamic = objectOf(script, obj);
			if (object == null || !Std.isOfType(object, FlxBasic))
				return false;
			(object : FlxBasic).cameras = [cameraOf(camera)];
			return true;
		});
		script.addCallback('setBlendMode', function(obj:String, blend:String = '') {
			var spr:FlxSprite = spriteOf(script, obj, 'setBlendMode');
			if (spr == null)
				return false;
			spr.blend = LuaUtils.blendModeFromString(blend);
			return true;
		});
		script.addCallback('getMidpointX', function(variable:String) {
			var object:Dynamic = objectOf(script, variable);
			return (object != null && Std.isOfType(object, FlxObject)) ? (object : FlxObject).getMidpoint().x : 0.0;
		});
		script.addCallback('getMidpointY', function(variable:String) {
			var object:Dynamic = objectOf(script, variable);
			return (object != null && Std.isOfType(object, FlxObject)) ? (object : FlxObject).getMidpoint().y : 0.0;
		});
		script.addCallback('getGraphicMidpointX', function(variable:String) {
			var spr:FlxSprite = spriteOf(script, variable, 'getGraphicMidpointX');
			return spr != null ? spr.getGraphicMidpoint().x : 0.0;
		});
		script.addCallback('getGraphicMidpointY', function(variable:String) {
			var spr:FlxSprite = spriteOf(script, variable, 'getGraphicMidpointY');
			return spr != null ? spr.getGraphicMidpoint().y : 0.0;
		});
		script.addCallback('getScreenPositionX', function(variable:String, ?camera:String = 'game') {
			var object:Dynamic = objectOf(script, variable);
			return (object != null && Std.isOfType(object, FlxObject)) ? (object : FlxObject).getScreenPosition(cameraOf(camera)).x : 0.0;
		});
		script.addCallback('getScreenPositionY', function(variable:String, ?camera:String = 'game') {
			var object:Dynamic = objectOf(script, variable);
			return (object != null && Std.isOfType(object, FlxObject)) ? (object : FlxObject).getScreenPosition(cameraOf(camera)).y : 0.0;
		});
		script.addCallback('getPixelColor', function(obj:String, x:Int, y:Int) {
			var spr:FlxSprite = spriteOf(script, obj, 'getPixelColor');
			return spr != null ? spr.pixels.getPixel32(x, y) : FlxColor.BLACK;
		});
	}

	/** Como LuaUtils.addAnimByIndices: los índices pueden ser "0,1,2" o una tabla {0, 1, 2}. */
	static function addAnimByIndices(script:FluxLuaGlobal, func:String, obj:String, name:String, prefix:String, indices:Dynamic, framerate:Float,
			loop:Bool):Bool
	{
		var spr:FlxSprite = spriteOf(script, obj, func);
		if (spr == null || spr.animation == null)
			return false;
		var list:Array<Int> = [];
		if (indices == null)
			list = [0];
		else if (Std.isOfType(indices, String))
		{
			for (part in (indices : String).trim().split(','))
				list.push(Std.parseInt(part.trim()));
		}
		else if (Std.isOfType(indices, Array))
			for (value in (indices : Array<Dynamic>))
				list.push(Std.int(value));
		if (prefix != null)
			spr.animation.addByIndices(name, prefix, list, '', framerate, loop);
		else
			spr.animation.add(name, list, framerate, loop);
		if (spr.animation.curAnim == null)
			playOn(spr, name, true);
		return true;
	}

	static function playOn(spr:Dynamic, name:String, forced:Bool):Void
	{
		if (spr.playAnim != null)
			spr.playAnim(name, forced);
		else
			spr.animation.play(name, forced);
	}

	// ------------------------------------------------------------------
	// Textos
	// ------------------------------------------------------------------

	static function texts(script:FluxLuaGlobal):Void
	{
		script.addCallback('makeLuaText', function(tag:String, ?text:String = '', ?width:Int = 0, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			destroyTag(script, tag);
			var txt:FlxText = new FlxText(x, y, width, text, 16);
			txt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			if (inSong())
				txt.cameras = [PlayState.instance.camHUD];
			txt.scrollFactor.set();
			txt.borderSize = 2;
			variables(script).set(tag, txt);
		});
		script.addCallback('addLuaText', function(tag:String) {
			var txt:Dynamic = variables(script).get(tag);
			if (txt != null && Std.isOfType(txt, FlxText))
				target().add(txt);
		});
		script.addCallback('removeLuaText', function(tag:String, destroy:Bool = true) {
			var txt:Dynamic = variables(script).get(tag);
			if (txt == null || !Std.isOfType(txt, FlxText))
				return;
			target().remove(txt, true);
			if (destroy)
			{
				(txt : FlxText).destroy();
				variables(script).remove(tag);
			}
		});
		script.addCallback('luaTextExists', function(tag:String) {
			var txt:Dynamic = variables(script).get(tag);
			return txt != null && Std.isOfType(txt, FlxText);
		});
		script.addCallback('setTextString', function(tag:String, text:String) {
			var txt:FlxText = textOf(script, tag, 'setTextString');
			if (txt != null)
				txt.text = text;
			return txt != null;
		});
		script.addCallback('setTextSize', function(tag:String, size:Int) {
			var txt:FlxText = textOf(script, tag, 'setTextSize');
			if (txt != null)
				txt.size = size;
			return txt != null;
		});
		script.addCallback('setTextWidth', function(tag:String, width:Float) {
			var txt:FlxText = textOf(script, tag, 'setTextWidth');
			if (txt != null)
				txt.fieldWidth = width;
			return txt != null;
		});
		script.addCallback('setTextHeight', function(tag:String, height:Float) {
			var txt:FlxText = textOf(script, tag, 'setTextHeight');
			if (txt != null)
				txt.fieldHeight = height;
			return txt != null;
		});
		script.addCallback('setTextAutoSize', function(tag:String, value:Bool) {
			var txt:FlxText = textOf(script, tag, 'setTextAutoSize');
			if (txt != null)
				txt.autoSize = value;
			return txt != null;
		});
		script.addCallback('setTextBorder', function(tag:String, size:Float, color:String, ?style:String = 'outline') {
			var txt:FlxText = textOf(script, tag, 'setTextBorder');
			if (txt == null)
				return false;
			CoolUtil.setTextBorderFromString(txt, size > 0 ? style : 'none');
			if (size > 0)
				txt.borderSize = size;
			txt.borderColor = CoolUtil.colorFromString(color);
			return true;
		});
		script.addCallback('setTextColor', function(tag:String, color:String) {
			var txt:FlxText = textOf(script, tag, 'setTextColor');
			if (txt != null)
				txt.color = CoolUtil.colorFromString(color);
			return txt != null;
		});
		script.addCallback('setTextFont', function(tag:String, newFont:String) {
			var txt:FlxText = textOf(script, tag, 'setTextFont');
			if (txt != null)
				txt.font = Paths.font(newFont);
			return txt != null;
		});
		script.addCallback('setTextItalic', function(tag:String, italic:Bool) {
			var txt:FlxText = textOf(script, tag, 'setTextItalic');
			if (txt != null)
				txt.italic = italic;
			return txt != null;
		});
		script.addCallback('setTextAlignment', function(tag:String, alignment:String = 'left') {
			var txt:FlxText = textOf(script, tag, 'setTextAlignment');
			if (txt == null)
				return false;
			txt.alignment = switch (alignment.trim().toLowerCase())
			{
				case 'right': RIGHT;
				case 'center': CENTER;
				case 'justify': JUSTIFY;
				default: LEFT;
			}
			return true;
		});
		script.addCallback('getTextString', function(tag:String) {
			var txt:FlxText = textOf(script, tag, 'getTextString');
			return (txt != null && txt.text != null && txt.text.length > 0) ? txt.text : null;
		});
		script.addCallback('getTextSize', function(tag:String) {
			var txt:FlxText = textOf(script, tag, 'getTextSize');
			return txt != null ? txt.size : -1;
		});
		script.addCallback('getTextFont', function(tag:String) {
			var txt:FlxText = textOf(script, tag, 'getTextFont');
			return txt != null ? txt.font : null;
		});
		script.addCallback('getTextWidth', function(tag:String) {
			var txt:FlxText = textOf(script, tag, 'getTextWidth');
			return txt != null ? txt.fieldWidth : 0.0;
		});
	}

	// ------------------------------------------------------------------
	// Tweens y timers
	// ------------------------------------------------------------------

	static function tweensAndTimers(script:FluxLuaGlobal):Void
	{
		script.addCallback('doTweenX', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenTo(script, tag, vars, objectOf(script, vars), {x: value}, duration, ease, 'doTweenX');
		});
		script.addCallback('doTweenY', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenTo(script, tag, vars, objectOf(script, vars), {y: value}, duration, ease, 'doTweenY');
		});
		script.addCallback('doTweenAngle', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenTo(script, tag, vars, objectOf(script, vars), {angle: value}, duration, ease, 'doTweenAngle');
		});
		script.addCallback('doTweenAlpha', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenTo(script, tag, vars, objectOf(script, vars), {alpha: value}, duration, ease, 'doTweenAlpha');
		});
		script.addCallback('doTweenZoom', function(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return tweenTo(script, tag, camera, cameraOf(camera), {zoom: value}, duration, ease, 'doTweenZoom');
		});
		script.addCallback('doTweenColor', function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			var obj:Dynamic = objectOf(script, vars);
			if (obj == null || !Std.isOfType(obj, FlxSprite))
			{
				warn(script, 'doTweenColor: no existe el objeto "$vars"');
				return null;
			}
			if (tag != null)
				cancelTween(script, tag);
			var spr:FlxSprite = obj;
			var current:FlxColor = spr.color;
			current.alphaFloat = spr.alpha;
			var tween:FlxTween = FlxTween.color(spr, duration, current, CoolUtil.colorFromString(targetColor), {
				ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(_) tweenFinished(script, tag, vars)
			});
			if (tag != null)
				script.tweens.set(tag, tween);
			return tag;
		});
		script.addCallback('startTween', function(tag:String, vars:String, values:Dynamic = null, duration:Float, ?options:Dynamic = null) {
			var obj:Dynamic = objectOf(script, vars);
			if (obj == null || values == null)
			{
				warn(script, 'startTween: no existe el objeto "$vars"');
				return null;
			}
			if (tag != null)
				cancelTween(script, tag);
			var myOptions = LuaUtils.getLuaTween(options);
			var tween:FlxTween = FlxTween.tween(obj, values, duration, myOptions != null ? {
				type: myOptions.type,
				ease: myOptions.ease,
				startDelay: myOptions.startDelay,
				loopDelay: myOptions.loopDelay,
				onUpdate: function(_) if (myOptions.onUpdate != null) script.call(myOptions.onUpdate, [tag, vars]),
				onStart: function(_) if (myOptions.onStart != null) script.call(myOptions.onStart, [tag, vars]),
				onComplete: function(twn:FlxTween) {
					if (tag != null && (twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD))
						script.tweens.remove(tag);
					if (myOptions.onComplete != null)
						script.call(myOptions.onComplete, [tag, vars]);
				}
			} : {onComplete: function(_) if (tag != null) script.tweens.remove(tag)}); // sin opciones no avisa a Lua, como en Psych
			if (tag != null)
				script.tweens.set(tag, tween);
			return tag;
		});
		script.addCallback('cancelTween', function(tag:String) cancelTween(script, tag));

		script.addCallback('runTimer', function(tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(script, tag);
			var timer:FlxTimer = new FlxTimer(FluxLuaGlobal.timerManager).start(time, function(tmr:FlxTimer) {
				if (tmr.finished && tag != null)
					script.timers.remove(tag);
				script.call('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
			}, loops);
			if (tag != null)
				script.timers.set(tag, timer);
			return tag;
		});
		script.addCallback('cancelTimer', function(tag:String) cancelTimer(script, tag));
	}

	static function tweenTo(script:FluxLuaGlobal, tag:String, vars:String, obj:Dynamic, values:Dynamic, duration:Float, ease:String, func:String):String
	{
		if (obj == null)
		{
			warn(script, '$func: no existe el objeto "$vars"');
			return null;
		}
		if (tag != null)
			cancelTween(script, tag);
		var tween:FlxTween = FlxTween.tween(obj, values, duration, {
			ease: LuaUtils.getTweenEaseByString(ease),
			onComplete: function(_) tweenFinished(script, tag, vars)
		});
		if (tag != null)
			script.tweens.set(tag, tween);
		return tag;
	}

	static function tweenFinished(script:FluxLuaGlobal, tag:String, vars:String):Void
	{
		if (tag == null)
			return;
		script.tweens.remove(tag);
		script.call('onTweenCompleted', [tag, vars]);
	}

	static function cancelTween(script:FluxLuaGlobal, tag:String):Void
	{
		var tween:FlxTween = script.tweens.get(tag);
		if (tween != null)
		{
			tween.cancel();
			tween.destroy();
		}
		script.tweens.remove(tag);
	}

	static function cancelTimer(script:FluxLuaGlobal, tag:String):Void
	{
		if (tag == null)
			return;
		var timer:FlxTimer = script.timers.get(tag);
		if (timer != null)
		{
			timer.cancel();
			timer.destroy();
		}
		script.timers.remove(tag);
	}

	// ------------------------------------------------------------------
	// Sonido y cámaras
	// ------------------------------------------------------------------

	static function sounds(script:FluxLuaGlobal):Void
	{
		script.addCallback('playMusic', function(sound:String, ?volume:Float = 1, ?loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		script.addCallback('playSound', function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false) {
			if (tag == null || tag.length == 0)
			{
				FlxG.sound.play(Paths.sound(sound), volume);
				return null;
			}
			var old:FlxSound = script.sounds.get(tag);
			if (old != null)
			{
				old.stop();
				old.destroy();
			}
			script.sounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, function() {
				if (!loop)
					script.sounds.remove(tag);
				script.call('onSoundFinished', [tag]);
			}));
			return tag;
		});
		script.addCallback('stopSound', function(tag:String) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.stop();
			if (tag != null && tag.length > 0)
				script.sounds.remove(tag);
		});
		script.addCallback('pauseSound', function(tag:String) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.pause();
		});
		script.addCallback('resumeSound', function(tag:String) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.play();
		});
		script.addCallback('luaSoundExists', function(tag:String) return script.sounds.get(tag) != null);
		script.addCallback('soundFadeIn', function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.fadeIn(duration, fromValue, toValue);
		});
		script.addCallback('soundFadeOut', function(tag:String, duration:Float, toValue:Float = 0) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.fadeOut(duration, toValue);
		});
		script.addCallback('soundFadeCancel', function(tag:String) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null && snd.fadeTween != null)
				snd.fadeTween.cancel();
		});
		script.addCallback('musicFadeIn', function(duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if (FlxG.sound.music != null)
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
		});
		script.addCallback('musicFadeOut', function(duration:Float, toValue:Float = 0) {
			if (FlxG.sound.music != null)
				FlxG.sound.music.fadeOut(duration, toValue);
		});
		script.addCallback('getSoundVolume', function(tag:String) {
			var snd:FlxSound = soundOf(script, tag);
			return snd != null ? snd.volume : 0.0;
		});
		script.addCallback('setSoundVolume', function(tag:String, value:Float) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.volume = value;
		});
		script.addCallback('getSoundTime', function(tag:String) {
			var snd:FlxSound = soundOf(script, tag);
			return snd != null ? snd.time : 0.0;
		});
		script.addCallback('setSoundTime', function(tag:String, value:Float) {
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.time = value;
		});
		script.addCallback('getSoundPitch', function(tag:String) {
			#if FLX_PITCH
			var snd:FlxSound = soundOf(script, tag);
			return snd != null ? snd.pitch : 1.0;
			#else
			return 1.0;
			#end
		});
		script.addCallback('setSoundPitch', function(tag:String, value:Float) {
			#if FLX_PITCH
			var snd:FlxSound = soundOf(script, tag);
			if (snd != null)
				snd.pitch = value;
			#end
		});
		script.addCallback('precacheImage', function(name:String, ?allowGPU:Bool = true) Paths.image(name, null, allowGPU));
		script.addCallback('precacheSound', function(name:String) Paths.sound(name));
		script.addCallback('precacheMusic', function(name:String) Paths.music(name));

		script.addCallback('cameraShake', function(camera:String, intensity:Float, duration:Float) {
			cameraOf(camera).shake(intensity, duration);
		});
		script.addCallback('cameraFlash', function(camera:String, color:String, duration:Float, forced:Bool) {
			cameraOf(camera).flash(CoolUtil.colorFromString(color), duration, null, forced);
		});
		script.addCallback('cameraFade', function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) {
			cameraOf(camera).fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced);
		});
	}

	// ------------------------------------------------------------------
	// Teclado y mouse
	// ------------------------------------------------------------------

	static function input(script:FluxLuaGlobal):Void
	{
		script.addCallback('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		script.addCallback('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		script.addCallback('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		script.addCallback('keyJustPressed', function(name:String = '') {
			var controls:Controls = Controls.instance;
			return switch (name.toLowerCase().trim())
			{
				case 'left': controls.NOTE_LEFT_P;
				case 'down': controls.NOTE_DOWN_P;
				case 'up': controls.NOTE_UP_P;
				case 'right': controls.NOTE_RIGHT_P;
				case other: controls.justPressed(other);
			}
		});
		script.addCallback('keyPressed', function(name:String = '') {
			var controls:Controls = Controls.instance;
			return switch (name.toLowerCase().trim())
			{
				case 'left': controls.NOTE_LEFT;
				case 'down': controls.NOTE_DOWN;
				case 'up': controls.NOTE_UP;
				case 'right': controls.NOTE_RIGHT;
				case other: controls.pressed(other);
			}
		});
		script.addCallback('keyReleased', function(name:String = '') {
			var controls:Controls = Controls.instance;
			return switch (name.toLowerCase().trim())
			{
				case 'left': controls.NOTE_LEFT_R;
				case 'down': controls.NOTE_DOWN_R;
				case 'up': controls.NOTE_UP_R;
				case 'right': controls.NOTE_RIGHT_R;
				case other: controls.justReleased(other);
			}
		});

		script.addCallback('mouseClicked', function(?button:String = 'left') {
			return switch (button.trim().toLowerCase())
			{
				case 'middle': FlxG.mouse.justPressedMiddle;
				case 'right': FlxG.mouse.justPressedRight;
				default: FlxG.mouse.justPressed;
			}
		});
		script.addCallback('mousePressed', function(?button:String = 'left') {
			return switch (button.trim().toLowerCase())
			{
				case 'middle': FlxG.mouse.pressedMiddle;
				case 'right': FlxG.mouse.pressedRight;
				default: FlxG.mouse.pressed;
			}
		});
		script.addCallback('mouseReleased', function(?button:String = 'left') {
			return switch (button.trim().toLowerCase())
			{
				case 'middle': FlxG.mouse.justReleasedMiddle;
				case 'right': FlxG.mouse.justReleasedRight;
				default: FlxG.mouse.justReleased;
			}
		});
		script.addCallback('getMouseX', function(?camera:String = 'game') return FlxG.mouse.getScreenPosition(cameraOf(camera)).x);
		script.addCallback('getMouseY', function(?camera:String = 'game') return FlxG.mouse.getScreenPosition(cameraOf(camera)).y);
	}

	// ------------------------------------------------------------------
	// Variables, archivos, guardado, estados y Haxe
	// ------------------------------------------------------------------

	static function other(script:FluxLuaGlobal):Void
	{
		script.addCallback('setVar', function(varName:String, value:Dynamic) {
			variables(script).set(varName, value);
			return value;
		});
		script.addCallback('getVar', function(varName:String) return variables(script).get(varName));
		script.addCallback('removeVar', function(varName:String) return variables(script).remove(varName));

		script.addCallback('debugPrint', function(text:Dynamic = '', color:String = 'WHITE') {
			print(Std.string(text), CoolUtil.colorFromString(color));
		});
		script.addCallback('close', function() {
			script.requestClose();
			return true;
		});

		script.addCallback('getColorFromHex', function(color:String) return FlxColor.fromString('#$color'));
		script.addCallback('getColorFromName', function(color:String) return FlxColor.fromString(color));
		script.addCallback('getColorFromString', function(color:String) return FlxColor.fromString(color));
		script.addCallback('FlxColor', function(color:String) return FlxColor.fromString(color));

		script.addCallback('getRandomInt', function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var toExclude:Array<Int> = [];
			if (exclude != null && exclude.length > 0)
				for (part in exclude.split(','))
					toExclude.push(Std.parseInt(part.trim()));
			return FlxG.random.int(min, max, toExclude);
		});
		script.addCallback('getRandomFloat', function(min:Float, max:Float = 1, exclude:String = '') {
			var toExclude:Array<Float> = [];
			if (exclude != null && exclude.length > 0)
				for (part in exclude.split(','))
					toExclude.push(Std.parseFloat(part.trim()));
			return FlxG.random.float(min, max, toExclude);
		});
		script.addCallback('getRandomBool', function(chance:Float = 50) return FlxG.random.bool(chance));

		script.addCallback('stringStartsWith', function(str:String, start:String) return str.startsWith(start));
		script.addCallback('stringEndsWith', function(str:String, end:String) return str.endsWith(end));
		script.addCallback('stringSplit', function(str:String, split:String) return str.split(split));
		script.addCallback('stringTrim', function(str:String) return str.trim());

		script.addCallback('checkFileExists', function(filename:String, ?absolute:Bool = false) {
			if (absolute)
				return FileSystem.exists(filename);
			return FileSystem.exists(Paths.getPath(filename, TEXT));
		});
		script.addCallback('getTextFromFile', function(path:String, ?ignoreModFolders:Bool = false) return Paths.getTextFromFile(path, ignoreModFolders));
		script.addCallback('directoryFileList', function(folder:String) {
			var list:Array<String> = [];
			if (FileSystem.exists(folder) && FileSystem.isDirectory(folder))
				for (entry in FileSystem.readDirectory(folder))
					if (!list.contains(entry))
						list.push(entry);
			return list;
		});
		script.addCallback('saveFile', function(path:String, content:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			File.saveContent(absolute ? path : Paths.mods(path), content);
			#else
			File.saveContent(path, content);
			#end
			return true;
		});

		// guardado propio del script (no se pierde al cambiar de menú)
		script.addCallback('initSaveData', function(name:String, ?folder:String = 'psychenginemods') {
			if (script.saves.exists(name))
				return;
			var save:FlxSave = new FlxSave();
			save.bind(name, CoolUtil.getSavePath() + '/' + folder);
			script.saves.set(name, save);
		});
		script.addCallback('flushSaveData', function(name:String) {
			var save:FlxSave = script.saves.get(name);
			if (save == null)
				throw 'flushSaveData: primero usa initSaveData("$name")';
			save.flush();
		});
		script.addCallback('getDataFromSave', function(name:String, field:String, ?defaultValue:Dynamic = null) {
			var save:FlxSave = script.saves.get(name);
			if (save == null || !Reflect.hasField(save.data, field))
				return defaultValue;
			return Reflect.field(save.data, field);
		});
		script.addCallback('setDataFromSave', function(name:String, field:String, value:Dynamic) {
			var save:FlxSave = script.saves.get(name);
			if (save == null)
				throw 'setDataFromSave: primero usa initSaveData("$name")';
			Reflect.setField(save.data, field, value);
		});
		script.addCallback('eraseSaveData', function(name:String) {
			var save:FlxSave = script.saves.get(name);
			if (save != null)
				save.erase();
		});
		script.addCallback('getModSetting', function(saveTag:String, ?modName:String = null) {
			if (modName == null)
				modName = script.modFolder;
			if (modName == null)
				throw 'getModSetting: el script no está dentro de una carpeta de mod';
			return modSetting(saveTag, modName);
		});

		script.addCallback('getSongPosition', function() return Conductor.songPosition);

		// Flux: cambiar de menú (también a menús hechos con script, states/<nombre>)
		script.addCallback('switchState', function(name:String) {
			var state:FlxState = FluxHxsPreset.stateOf(name);
			if (state == null)
				throw 'switchState: no existe el estado "$name"';
			MusicBeatState.switchState(state);
		});
		script.addCallback('resetState', function() MusicBeatState.resetState());

		#if HSCRIPT_IMPROVED_ALLOWED
		// Haxe dentro del Lua (corre como un .hxs)
		script.addCallback('runHaxeCode', function(codeToRun:String, ?varsToBring:Dynamic = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null) {
			var haxeScript:FluxScript = script.haxeScript;
			if (haxeScript == null || !haxeScript.active)
			{
				haxeScript = FluxScriptHandler.createFromCode(script.origin + ' (runHaxeCode)', '.hxs', codeToRun, script.modFolder, varsOf(varsToBring));
				script.haxeScript = haxeScript;
				if (haxeScript == null)
					return null;
			}
			else
			{
				for (name => value in varsOf(varsToBring))
					haxeScript.set(name, value);
				if (!haxeScript.executeCode(codeToRun))
					return null;
			}
			var result:Dynamic = (funcToRun != null && funcToRun.length > 0) ? haxeScript.call(funcToRun, funcArgs) : haxeScript.returnValue;
			return LuaUtils.isLuaSupported(result) ? result : null;
		});
		script.addCallback('runHaxeFunction', function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			if (script.haxeScript == null)
				throw 'runHaxeFunction: primero usa runHaxeCode';
			var result:Dynamic = script.haxeScript.call(funcToRun, funcArgs);
			return LuaUtils.isLuaSupported(result) ? result : null;
		});
		#end
	}

	/** Como el getModSetting de Psych, pero sin usar la canción (en los menús no hay). */
	static function modSetting(saveTag:String, modName:String):Dynamic
	{
		#if MODS_ALLOWED
		var path:String = Paths.mods('$modName/data/settings.json');
		if (!FileSystem.exists(path))
			return null;
		if (inSong())
			return LuaUtils.getModSetting(saveTag, modName);

		if (FlxG.save.data.modSettings != null)
		{
			var saved:Map<String, Dynamic> = FlxG.save.data.modSettings.get(modName);
			if (saved != null && saved.exists(saveTag))
				return saved.get(saveTag);
		}
		var parsed:Dynamic = tjson.TJSON.parse(File.getContent(path));
		for (i in 0...parsed.length)
		{
			var sub:Dynamic = parsed[i];
			if (sub != null && sub.save == saveTag)
				return (sub.type != 'keybind' && sub.type != 'key') ? sub.value : {keyboard: sub.keyboard, gamepad: sub.gamepad};
		}
		#end
		return null;
	}

	static function varsOf(value:Dynamic):Map<String, Dynamic>
	{
		var map:Map<String, Dynamic> = new Map();
		if (value != null && Type.typeof(value) == TObject)
			for (field in Reflect.fields(value))
				map.set(field, Reflect.field(value, field));
		return map;
	}
}
#end
