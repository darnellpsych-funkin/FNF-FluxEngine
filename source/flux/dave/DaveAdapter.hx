package flux.dave;

#if FLUX_DAVE_SCRIPTS
import backend.ClientPrefs;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flux.dave.api.DaveApi;
import flux.vslice.modules.VSliceAdapter;
import objects.Bar;
import objects.Character;
import objects.HealthIcon;
import objects.Note;
import objects.StrumNote;
import states.PlayState;

using StringTools;

/**
 * Lo que el PlayState de Dave Engine tiene y el de Psych no (o tiene con otro nombre), para
 * los scripts de Dave (módulos, escenarios y personajes): `game.switchDad(...)`,
 * `game.ghostTapping`, `game.dadStrums`, `game.camGameZoom`, `game.iconP2.char`,
 * `game.healthBar.updateColors(...)`...
 *
 * Solo lo usan los scripts de Dave (FluxVSliceInterp con `dave`); antes que VSliceAdapter.
 */
class DaveAdapter
{
	/** El PlayState de los objetos de abajo (se crean de nuevo en cada canción). */
	static var game:PlayState = null;

	static var gameZoom:DaveCamZoom = null;
	static var hudZoom:DaveCamZoom = null;
	static var dadStrums:DaveStrumline = null;
	static var playerStrums:DaveStrumline = null;
	static var timer:DaveHudTimer = null;
	static var crazyZooming:Bool = false;
	static var camMoveOnNoteAllowed:Bool = true;
	static var preferenceSignal:DaveSignal = null;
	static var warned:Array<String> = [];

	public static function getField(o:Dynamic, f:String):Dynamic
	{
		if (o == null)
			return VSliceAdapter.UNHANDLED;
		if (Std.isOfType(o, PlayState))
			return playStateGet(cast o, f);
		if (Std.isOfType(o, HealthIcon) && f == 'char')
			return (o : HealthIcon).getCharacter();
		if (Std.isOfType(o, Bar))
			return barGet(cast o, f);
		if (Std.isOfType(o, Character))
			return characterGet(cast o, f);
		return VSliceAdapter.UNHANDLED;
	}

	/** Devuelve true si escribió el valor. */
	public static function setField(o:Dynamic, f:String, value:Dynamic):Bool
	{
		if (o == null)
			return false;
		if (Std.isOfType(o, PlayState))
			return playStateSet(cast o, f, value);
		if (Std.isOfType(o, HealthIcon) && f == 'char')
		{
			// en Psych "char" es privado: hay que cambiar el ícono de verdad
			if (value != null)
				(o : HealthIcon).changeIcon(Std.string(value));
			return true;
		}
		return false;
	}

	/** Lo llama FluxDaveStage al terminar la canción. */
	public static function clear():Void
		check(null);

	static function check(g:PlayState):Void
	{
		if (game == g)
			return;
		game = g;
		gameZoom = null;
		hudZoom = null;
		dadStrums = null;
		playerStrums = null;
		timer = null;
		crazyZooming = false;
		camMoveOnNoteAllowed = true;
	}

	// ----- PlayState -----

	static function playStateGet(g:PlayState, f:String):Dynamic
	{
		switch (f)
		{
			case 'switchDad' | 'switchBF' | 'switchGF':
				var role:String = f == 'switchDad' ? 'dad' : (f == 'switchBF' ? 'bf' : 'gf');
				return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
					DaveCharacters.switchCharacter(g, role, args.length > 0 && args[0] != null ? Std.string(args[0]) : null, args.length > 1 ? args[1] : null,
						args.length < 3 || args[2] != false, args.length < 4 || args[3] != false);
					return null;
				});
			case 'ghostTapping':
				return g.ghostTappingOverride != null ? g.ghostTappingOverride : ClientPrefs.data.ghostTapping;
			case 'dadStrums':
				check(g);
				if (dadStrums == null)
					dadStrums = new DaveStrumline(g, false);
				return dadStrums;
			case 'playerStrums':
				check(g);
				if (playerStrums == null)
					playerStrums = new DaveStrumline(g, true);
				return playerStrums;
			case 'camGameZoom':
				makeZooms(g);
				return gameZoom;
			case 'camHUDZoom':
				makeZooms(g);
				return hudZoom;
			case 'crazyZooming':
				check(g);
				return crazyZooming;
			case 'forceFocusOnChar':
				return @:privateAccess g.isCameraOnForcedPos;
			case 'focusOnDadGlobal':
				return FluxDaveStage.focusOnDad;
			case 'camMoveOnNoteAllowed':
				check(g);
				return camMoveOnNoteAllowed;
			case 'defaultHUDZoom':
				return 1.0;
			case 'scoreDisplay' | 'missesDisplay' | 'accuracyDisplay':
				// Psych muestra el puntaje, los fallos y la precisión en un solo texto
				return g.scoreTxt;
			case 'timer':
				check(g);
				if (timer == null)
					timer = new DaveHudTimer(g);
				return timer;
			case 'ratings':
				return g.comboGroup;
			case 'scrollType':
				return ClientPrefs.data.downScroll ? 'downscroll' : 'upscroll';
			case 'dadOverride':
				return FluxDaveStage.dadOverride;
			case 'bfOverride':
				return FluxDaveStage.bfOverride;
			case 'shapeNoteSongs':
				return [];
			case 'onPreferenceChangedPost':
				if (preferenceSignal == null)
					preferenceSignal = new DaveSignal();
				return preferenceSignal;
			case 'currentStage':
				if (FluxDaveStage.current != null)
					return FluxDaveStage.current.facade();
			case 'makeInvisibleNotes':
				return function(invisible:Bool):Void makeInvisibleNotes(g, invisible);
			case 'ZoomCam':
				return function(focusOnDad:Bool):Void g.moveCamera(focusOnDad);
			case 'opponentSing':
				return function(char:Character, note:Note):Void opponentSing(g, char, note);
			case 'beginStartDialogue':
				// los diálogos de Dave todavía no: sigue directo (onComplete o la cuenta regresiva)
				return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
					var onComplete:Dynamic = args.length > 1 ? args[1] : null;
					if (onComplete != null && Reflect.isFunction(onComplete))
						Reflect.callMethod(null, onComplete, []);
					else
						g.startCountdown();
					return null;
				});
			case 'endSongDialogue':
				return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
					var onComplete:Dynamic = args.length > 1 ? args[1] : null;
					if (onComplete != null && Reflect.isFunction(onComplete))
						Reflect.callMethod(null, onComplete, []);
					else
						g.endSong();
					return null;
				});
			case 'nextSong':
				// en Psych endSong ya pasa a la siguiente canción del modo historia
				return function():Void g.endSong();
			case 'loadStage' | 'removeStage':
				return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
					warnOnce(f, 'PlayState.$f de Dave Engine todavía no está en Flux (cambiar de escenario en la canción)');
					return null;
				});
			default:
		}
		return VSliceAdapter.UNHANDLED;
	}

	static function playStateSet(g:PlayState, f:String, value:Dynamic):Bool
	{
		switch (f)
		{
			case 'ghostTapping':
				g.ghostTappingOverride = value == true;
				return true;
			case 'crazyZooming':
				makeZooms(g);
				crazyZooming = value == true;
				gameZoom.timeSnap = crazyZooming ? 1 : 4;
				hudZoom.timeSnap = crazyZooming ? 1 : 4;
				return true;
			case 'camZooming':
				// como el setter de Dave: también prende o apaga los CamZoomManager
				g.camZooming = value == true;
				if (game == g && gameZoom != null)
				{
					gameZoom.canZoom = g.camZooming;
					hudZoom.canZoom = g.camZooming;
				}
				return true;
			case 'forceFocusOnChar':
				@:privateAccess g.isCameraOnForcedPos = value == true;
				return true;
			case 'focusOnDadGlobal':
				FluxDaveStage.focusOnDad = value == true;
				return true;
			case 'camMoveOnNoteAllowed':
				check(g);
				camMoveOnNoteAllowed = value == true;
				return true;
			case 'dadOverride':
				FluxDaveStage.dadOverride = value != null ? Std.string(value) : null;
				return true;
			case 'bfOverride':
				FluxDaveStage.bfOverride = value != null ? Std.string(value) : null;
				return true;
			case 'scrollType' | 'defaultHUDZoom':
				return true;
			default:
		}
		return false;
	}

	static function warnOnce(key:String, message:String):Void
	{
		if (warned.contains(key))
			return;
		warned.push(key);
		trace('[Flux Dave Engine] $message');
	}

	/** makeInvisibleNotes de Dave: las flechas de los dos lados aparecen o desaparecen. */
	static function makeInvisibleNotes(g:PlayState, invisible:Bool):Void
	{
		for (group in [g.playerStrums, g.opponentStrums])
		{
			if (group == null)
				continue;
			for (strum in group.members)
			{
				if (strum == null)
					continue;
				FlxTween.cancelTweensOf(strum);
				FlxTween.tween(strum, {alpha: invisible ? 0 : 1}, 1);
			}
		}
	}

	/** opponentSing de Dave: el personaje canta la nota (como un oponente de Psych). */
	static function opponentSing(g:PlayState, char:Character, note:Note):Void
	{
		if (char == null || note == null)
			return;
		var anims:Array<String> = @:privateAccess g.singAnimations;
		if (anims == null || anims.length == 0)
			return;
		var anim:String = anims[Std.int(Math.abs(Math.min(anims.length - 1, note.noteData)))] + note.animSuffix;
		char.playAnim(anim, true);
		char.holdTimer = 0;
	}

	// ----- El zoom de la cámara (CamZoomManager de Dave) -----

	static function makeZooms(g:PlayState):Void
	{
		check(g);
		if (gameZoom != null)
			return;
		gameZoom = new DaveCamZoom(FlxG.camera, 0.015);
		hudZoom = new DaveCamZoom(g.camHUD, 0.03);
		gameZoom.canZoom = hudZoom.canZoom = true;
	}

	/**
	 * Si los scripts de Dave manejan los saltos de zoom con el ritmo (usaron game.camGameZoom,
	 * camHUDZoom o crazyZooming): entonces el de Psych (cada sección) no va.
	 */
	public static function handlesZoomBop(g:PlayState):Bool
		return g != null && game == g && gameZoom != null;

	/** canWorldZoom de Dave: si la cámara vuelve sola a su zoom (sin los scripts de Dave, siempre). */
	public static function worldZoom(g:PlayState, isGame:Bool):Bool
	{
		if (!handlesZoomBop(g))
			return true;
		return isGame ? gameZoom.canWorldZoom : hudZoom.canWorldZoom;
	}

	/** Los saltos de zoom de Dave: cada `timeSnap` beats (o steps con useSteps). Lo llama FluxDaveStage. */
	public static function zoomBop(g:PlayState, time:Int, onStep:Bool):Void
	{
		if (!handlesZoomBop(g) || !g.camZooming || !ClientPrefs.data.camZooms)
			return;
		for (zoom in [gameZoom, hudZoom])
		{
			if (zoom == null || !zoom.canZoom || zoom.useSteps != onStep || zoom.timeSnap <= 0 || zoom.camera == null)
				continue;
			if (time % zoom.timeSnap == 0)
				zoom.camera.zoom += zoom.zoomValue;
		}
	}

	// ----- Barra de vida -----

	static function barGet(bar:Bar, f:String):Dynamic
	{
		switch (f)
		{
			case 'updateColors':
				// HealthBar.updateColors(dad, bf) de Dave
				return Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic {
					var dad:Dynamic = args.length > 0 ? args[0] : null;
					var bf:Dynamic = args.length > 1 ? args[1] : null;
					if (Std.isOfType(dad, Character) && Std.isOfType(bf, Character))
						bar.setColors(DaveCharacters.colorOf(cast dad), DaveCharacters.colorOf(cast bf));
					else if (game != null && bar == game.healthBar)
						game.reloadHealthBarColors();
					return null;
				});
			case 'bar':
				// la FlxBar de la HealthBar de Dave (createFilledBar, createGradientBar, updateBar)
				return new DaveFlxBar(bar);
			default:
		}
		return VSliceAdapter.UNHANDLED;
	}

	// ----- Personajes de Psych en los scripts de Dave -----

	static function characterGet(char:Character, f:String):Dynamic
	{
		if (char.daveScript != null)
			return VSliceAdapter.UNHANDLED; // los de Dave: DaveCharacters.getField
		switch (f)
		{
			case 'id' | 'characterName':
				return char.curCharacter;
			case 'characterIcon':
				return char.healthIcon;
			case 'characterColor':
				return DaveCharacters.colorOf(char);
			case 'globalOffset':
				return char.positionArray;
			case 'reposition':
				return function():Void {
					char.x += char.positionArray[0];
					char.y += char.positionArray[1];
				};
			default:
		}
		return VSliceAdapter.UNHANDLED;
	}
}

/** CamZoomManager de Dave: cuánto y cada cuánto salta el zoom de una cámara con el ritmo. */
@:keep
class DaveCamZoom
{
	public var camera:FlxCamera;

	/** Si la cámara puede saltar con el ritmo. */
	public var canZoom:Bool = true;

	/** Si el zoom vuelve solo al de siempre (defaultCamZoom en la del juego). */
	public var canWorldZoom:Bool = true;

	/** Cada cuántos beats (o steps con useSteps) salta. */
	public var timeSnap:Float = 4;

	/** Cuánto salta. */
	public var zoomValue:Float;

	public var intensity:Float = 1;
	public var useSteps:Bool = false;
	public var timeSignatureAdjust:Bool = true;

	public function new(camera:FlxCamera, zoomValue:Float)
	{
		this.camera = camera;
		this.zoomValue = zoomValue;
	}
}

/**
 * Strumline de Dave (game.dadStrums / game.playerStrums) con las flechas de Psych:
 * `strums`, `forEachStrum`, `forEachNote`, y x, y, alpha, visible para todas juntas.
 * También sirve como el grupo de Psych (members, forEach, length).
 */
@:keep
class DaveStrumline
{
	public var game(default, null):PlayState;
	public var isPlayer(default, null):Bool;

	public function new(game:PlayState, isPlayer:Bool)
	{
		this.game = game;
		this.isPlayer = isPlayer;
	}

	/** Las flechas de Psych de este lado. */
	public var strums(get, never):FlxTypedGroup<StrumNote>;

	function get_strums():FlxTypedGroup<StrumNote>
		return isPlayer ? game.playerStrums : game.opponentStrums;

	public var members(get, never):Array<StrumNote>;

	function get_members():Array<StrumNote>
		return strums != null ? strums.members : [];

	public var length(get, never):Int;

	function get_length():Int
		return strums != null ? strums.length : 0;

	public function forEachStrum(func:StrumNote->Void):Void
	{
		for (strum in members.copy())
			if (strum != null && strum.exists)
				func(strum);
	}

	public function forEach(func:StrumNote->Void, recurse:Bool = false):Void
		forEachStrum(func);

	/** Las notas de este lado que están en pantalla. */
	public function forEachNote(func:Note->Void):Void
	{
		if (game.notes == null)
			return;
		for (note in game.notes.members.copy())
			if (note != null && note.alive && note.mustPress == isPlayer)
				func(note);
	}

	function first():StrumNote
	{
		for (strum in members)
			if (strum != null)
				return strum;
		return null;
	}

	public var x(get, set):Float;

	function get_x():Float
		return first() != null ? first().x : 0;

	function set_x(value:Float):Float
	{
		var delta:Float = value - get_x();
		forEachStrum(function(strum) strum.x += delta);
		return value;
	}

	public var y(get, set):Float;

	function get_y():Float
		return first() != null ? first().y : 0;

	function set_y(value:Float):Float
	{
		var delta:Float = value - get_y();
		forEachStrum(function(strum) strum.y += delta);
		return value;
	}

	public var alpha(get, set):Float;

	function get_alpha():Float
		return first() != null ? first().alpha : 1;

	function set_alpha(value:Float):Float
	{
		forEachStrum(function(strum) strum.alpha = value);
		return value;
	}

	public var visible(get, set):Bool;

	function get_visible():Bool
		return first() != null ? first().visible : false;

	function set_visible(value:Bool):Bool
	{
		forEachStrum(function(strum) strum.visible = value);
		return value;
	}

	public var cameras(get, set):Array<FlxCamera>;

	function get_cameras():Array<FlxCamera>
		return first() != null ? first().cameras : [game.camHUD];

	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		forEachStrum(function(strum) strum.cameras = value);
		return value;
	}

	public var scrollType(get, set):String;

	function get_scrollType():String
		return ClientPrefs.data.downScroll ? 'downscroll' : 'upscroll';

	function set_scrollType(value:String):String
		return value;

	public var noteStyle:String = 'normal';

	/** En Dave vuelve a crear las flechas (con otro estilo); en Flux quedan las de Psych. */
	public function regenerate():Void {}
}

/**
 * HudTimer de Dave (game.timer, el reloj de la canción) con la barra de tiempo de Psych:
 * `pieTimer`, `updatePieColor(color)`, y x, y, alpha, visible para la barra y el texto.
 */
@:keep
class DaveHudTimer
{
	var game:PlayState;

	public function new(game:PlayState)
		this.game = game;

	/** La parte llena de la barra de tiempo. */
	public var pieTimer(get, never):FlxSprite;

	function get_pieTimer():FlxSprite
		return game.timeBar != null ? game.timeBar.leftBar : null;

	public function updatePieColor(color:FlxColor):Void
	{
		if (game.timeBar != null && game.timeBar.leftBar != null)
			game.timeBar.leftBar.color = color;
	}

	/** En Dave cambia el estilo del reloj; en Flux queda la barra de Psych. */
	public function switchType(?type:Dynamic):Void {}

	function parts():Array<FlxSprite>
	{
		var list:Array<FlxSprite> = [];
		if (game.timeBar != null)
			list.push(game.timeBar);
		var text:FlxSprite = @:privateAccess game.timeTxt;
		if (text != null)
			list.push(text);
		return list;
	}

	public var x(get, set):Float;

	function get_x():Float
		return game.timeBar != null ? game.timeBar.x : 0;

	function set_x(value:Float):Float
	{
		var delta:Float = value - get_x();
		for (part in parts())
			part.x += delta;
		return value;
	}

	public var y(get, set):Float;

	function get_y():Float
		return game.timeBar != null ? game.timeBar.y : 0;

	function set_y(value:Float):Float
	{
		var delta:Float = value - get_y();
		for (part in parts())
			part.y += delta;
		return value;
	}

	public var alpha(get, set):Float;

	function get_alpha():Float
		return game.timeBar != null ? game.timeBar.alpha : 0;

	function set_alpha(value:Float):Float
	{
		for (part in parts())
			part.alpha = value;
		return value;
	}

	public var visible(get, set):Bool;

	function get_visible():Bool
		return game.timeBar != null && game.timeBar.visible;

	function set_visible(value:Bool):Bool
	{
		for (part in parts())
			part.visible = value;
		return value;
	}

	public var cameras(get, set):Array<FlxCamera>;

	function get_cameras():Array<FlxCamera>
		return game.timeBar != null ? game.timeBar.cameras : [game.camHUD];

	function set_cameras(value:Array<FlxCamera>):Array<FlxCamera>
	{
		for (part in parts())
			part.cameras = value;
		return value;
	}
}

/** La FlxBar de la HealthBar de Dave (healthBar.bar) con la Bar de Psych (solo colores lisos). */
@:keep
class DaveFlxBar
{
	var bar:Bar;

	public function new(bar:Bar)
		this.bar = bar;

	/** `empty`: el lado del oponente; `fill`: el del jugador. */
	public function createFilledBar(empty:FlxColor, fill:FlxColor, showBorder:Bool = false, border:FlxColor = FlxColor.WHITE):DaveFlxBar
	{
		bar.setColors(empty, fill);
		return this;
	}

	/** Psych no tiene degradés: usa el primer color de cada lado. */
	public function createGradientBar(empty:Array<FlxColor>, fill:Array<FlxColor>, chunkSize:Int = 1, rotation:Int = 180, showBorder:Bool = false,
			border:FlxColor = FlxColor.WHITE):DaveFlxBar
	{
		bar.setColors(empty != null && empty.length > 0 ? empty[0] : null, fill != null && fill.length > 0 ? fill[0] : null);
		return this;
	}

	public function createColoredEmptyBar(empty:FlxColor, showBorder:Bool = false, border:FlxColor = FlxColor.WHITE):DaveFlxBar
	{
		bar.setColors(empty, null);
		return this;
	}

	public function createColoredFilledBar(fill:FlxColor, showBorder:Bool = false, border:FlxColor = FlxColor.WHITE):DaveFlxBar
	{
		bar.setColors(null, fill);
		return this;
	}

	public function updateBar():Void
		bar.updateBar();
}

/** Una señal que nadie dispara (game.onPreferenceChangedPost: Flux no cambia opciones en la canción). */
@:keep
class DaveSignal
{
	var listeners:Array<Dynamic> = [];

	public function new() {}

	public function add(listener:Dynamic):Void
		if (listener != null && !listeners.contains(listener)) listeners.push(listener);

	public function addOnce(listener:Dynamic):Void
		add(listener);

	public function remove(listener:Dynamic):Void
		listeners.remove(listener);

	public function removeAll():Void
		listeners = [];

	public function has(listener:Dynamic):Bool
		return listeners.contains(listener);

	public function dispatch(?a:Dynamic, ?b:Dynamic):Void
		for (listener in listeners.copy())
			Reflect.callMethod(null, listener, [a, b]);
}
#end
