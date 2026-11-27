package flux.dave;

#if FLUX_DAVE_SCRIPTS
import flixel.animation.FlxAnimation;
import flux.dave.api.DaveApi;
import flux.dave.api.DaveCharacter;
import flux.vslice.FluxVSliceAssets;
import objects.Character;
import openfl.utils.AssetType;
import states.PlayState;
import substates.GameOverSubstate;

using StringTools;

/**
 * Personajes de Dave Engine (VS Dave and Bambi Volume 1): data/characters/<id>.json
 * (escala, offsets, cámara, color...) + scripts/characters/<id>.hxc (el sprite y las
 * animaciones) + data/offsets/<archivo>.txt.
 *
 * Character.changeCharacter los usa cuando no hay un personaje de Psych con ese nombre
 * (o, en canciones de Dave, cuando el de Psych es del juego base: bf, gf...).
 */
class DaveCharacters
{
	/**
	 * En las canciones de Dave (y con escenarios de Dave) sus personajes van antes que los
	 * de Psych del juego base: el "bf" de Dave tiene otras posiciones que el de Psych.
	 */
	public static var preferDave:Bool = false;

	/** El personaje de Dave con ese id, o null. `psychPath`: el JSON de Psych que buscó Character. */
	public static function find(name:String, psychPath:String):Dynamic
	{
		if (name == null)
			return null;
		var className:String = DaveScripts.characterClasses.get(name);
		if (className == null || !daveWins(psychPath))
			return null;
		var data:Dynamic = readData(name);
		if (data == null)
			return null;
		return {name: name, className: className, data: data};
	}

	/** Si el de Dave le gana al archivo de Psych (que no exista, o que sea del juego base en una canción de Dave). */
	public static function daveWins(psychPath:String):Bool
	{
		#if MODS_ALLOWED
		if (psychPath == null || !FileSystem.exists(psychPath))
			return true;
		return preferDave && !psychPath.startsWith(Paths.mods());
		#else
		return false;
		#end
	}

	/** data/characters/<id>.json de Dave Engine (del mod actual, los globales o shared/), o null. */
	public static function readData(id:String):Dynamic
	{
		if (id == null || id.length == 0)
			return null;
		var data:Dynamic = FluxVSliceAssets.readJson(FluxVSliceAssets.findData('data/characters/$id.json'));
		return DaveData.isCharacter(data) ? data : null;
	}

	/** data/offsets/<nombre>.txt */
	public static function readOffsets(name:String):Map<String, Array<Float>>
	{
		var path:String = FluxVSliceAssets.findData('data/offsets/$name.txt');
		if (path == null)
			return new Map<String, Array<Float>>();
		try
		{
			return DaveData.parseOffsets(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			return new Map<String, Array<Float>>();
		}
	}

	/** [x, y] de un arreglo del JSON ([] o null = [0, 0]). */
	public static function pair(value:Dynamic, ?fallback:Array<Float>):Array<Float>
	{
		var result:Array<Float> = fallback != null ? fallback.copy() : [0, 0];
		if (Std.isOfType(value, Array))
		{
			var list:Array<Dynamic> = value;
			for (i in 0...Std.int(Math.min(2, list.length)))
				result[i] = DaveData.num(list[i], result[i]);
		}
		return result;
	}

	/**
	 * Carga el personaje de Dave en un personaje de Psych (lo llama Character.loadDaveCharacter):
	 * los datos del JSON, el script (load, escala, offsets) y LEFT/RIGHT dados vuelta si mira al revés.
	 */
	public static function load(char:Character, info:Dynamic):Void
	{
		var data:Dynamic = info.data;
		char.scale.set(1, 1);
		char.updateHitbox();
		char.animation.finishCallback = null;
		char.animation.callback = null;
		#if FLUX_VSLICE_SCRIPTS
		flux.vslice.modules.VSliceAdapter.clearAnimationSignals(char.animation);
		#end

		char.jsonScale = DaveData.num(data.scale, 1);
		char.positionArray = pair(data.globalOffset);
		// Dave enfoca el centro del personaje + sus cameraOffsets (+ los del escenario, en el StageFile)
		var camera:Array<Float> = pair(data.cameraOffsets);
		char.cameraPosition = char.isPlayer ? [-camera[0], camera[1]] : [camera[0], camera[1]];
		char.healthIcon = data.icon != null ? Std.string(data.icon) : info.name;
		char.singDuration = DaveData.num(data.singDuration, 4);
		var rgb:Array<Int> = DaveData.rgb(data.color);
		char.healthColorArray = rgb != null ? rgb : [161, 161, 161];
		char.originalFlipX = data.flipX == true;
		char.noAntialiasing = data.antialiasing == false;
		char.antialiasing = ClientPrefs.data.antialiasing && !char.noAntialiasing;
		char.vocalsFile = '';
		char.editorIsPlayer = null;
		char.animationsArray = [];

		var script:DaveCharacter = DaveScripts.createCharacter(info.className, char);
		char.daveScript = script;
		if (script == null)
			return;
		script.characterType = char.isPlayer ? DaveCharacterType.PLAYER : DaveCharacterType.OPPONENT;
		try
		{
			script.flipX = data.flipX == true; // los offsets del oponente, como el constructor de Dave
			script.onCreate(null);
		}
		catch (e:Dynamic)
		{
			DaveScripts.report(script, e);
		}
		// Dave da vuelta LEFT/RIGHT al cantar si el personaje mira al revés (sprite del otro lado)
		if (char.isPlayer != script.nativelyPlayable)
			swapSides(char, script);
		script.refreshOffsets();
		script.scriptedUpdate = DaveScripts.hasOwn(script, 'update');
	}

	/** Después de que Psych arma el baile: danceSnap de Dave. */
	public static function afterLoad(char:Character):Void
	{
		var script:DaveCharacter = char.daveScript;
		if (script == null)
			return;
		char.danceEveryNumBeats = script.danceSnap;
		char.danceIdle = script.danceTypes != null && script.danceTypes.contains('alternate');
	}

	/** Da vuelta las animaciones de canto LEFT <-> RIGHT (con sus variantes: miss, -alt...). */
	public static function swapSides(char:Character, script:DaveCharacter):Void
	{
		var anims:Map<String, FlxAnimation> = @:privateAccess char.animation._animations;
		if (anims == null)
			return;
		var lefts:Array<String> = [for (name in anims.keys()) if (name.startsWith('singLEFT')) name];
		var rights:Array<String> = [for (name in anims.keys()) if (name.startsWith('singRIGHT')) name];
		var moved:Map<String, FlxAnimation> = new Map<String, FlxAnimation>();
		for (name in lefts.concat(rights))
		{
			var other:String = name.startsWith('singLEFT') ? 'singRIGHT' + name.substr(8) : 'singLEFT' + name.substr(9);
			moved.set(other, anims.get(name));
			anims.remove(name);
			script.swappedAnims.set(other, name);
		}
		for (name => anim in moved)
		{
			anim.name = name;
			anims.set(name, anim);
		}
	}

	/** Cada cuadro: el update del script y, como en Dave, volver a bailar cuando termina "-ease". */
	public static function update(char:Character, elapsed:Float):Void
	{
		var script:DaveCharacter = char.daveScript;
		if (script.scriptedUpdate)
		{
			try
			{
				script.update(elapsed);
			}
			catch (e:Dynamic)
			{
				DaveScripts.report(script, e);
			}
		}
		if (char.debugMode || char.animation.curAnim == null || !char.animation.curAnim.finished)
			return;
		var name:String = char.animation.curAnim.name;
		if (script.waitingCheer && name == 'cheer')
		{
			script.waitingCheer = false;
			script.canDance = true;
		}
		if (name.endsWith('-ease'))
		{
			char.holdTimer = 0;
			callDance(script, true);
		}
	}

	/**
	 * Psych llama dance() en el beat (sin cantar) y cuando el personaje termina de cantar.
	 * Lo segundo en Dave es pasar a la animación "-ease" (si hay) o bailar forzado.
	 */
	public static function dance(char:Character):Void
	{
		var script:DaveCharacter = char.daveScript;
		var current:String = char.animation.curAnim != null ? char.animation.curAnim.name : '';
		try
		{
			if (current.startsWith('sing'))
			{
				var base:String = script.fetchBaseAnimationName(current);
				if (script.hasEase(base))
				{
					if (!script.isEaseAnimation(current))
					{
						char.holdTimer = 0;
						script.playAnim(base + '-ease', true);
					}
					return;
				}
				script.dance(true);
			}
			else
				script.dance(false);
		}
		catch (e:Dynamic)
		{
			DaveScripts.report(script, e);
		}
	}

	static function callDance(script:DaveCharacter, force:Bool):Void
	{
		try
		{
			script.dance(force);
		}
		catch (e:Dynamic)
		{
			DaveScripts.report(script, e);
		}
	}

	/**
	 * playAnim de Dave: canDance / canSing y los sufijos altDanceSuffix / altSingSuffix.
	 * Null si no hay que tocar nada (como en Dave, una animación que no existe no se toca).
	 */
	public static function animationName(char:Character, name:String):String
	{
		var script:DaveCharacter = char.daveScript;
		if (name == null || char.animation == null || !char.animation.exists(name))
			return null;
		var lower:String = name.toLowerCase();
		var dance:Bool = lower.startsWith('idle') || lower.startsWith('dance');
		var sing:Bool = lower.startsWith('sing');
		if ((dance && !script.canDance) || (sing && !script.canSing))
			return null;
		if (dance && script.altDanceSuffix != null && !name.contains(script.altDanceSuffix))
			name += script.altDanceSuffix;
		if (sing && script.altSingSuffix != null && !name.contains(script.altSingSuffix))
			name += script.altSingSuffix;
		return char.animation.exists(name) ? name : null;
	}

	/** El personaje de game over: el deathSkin del jugador de Dave ("generic-death" si no puso otro). */
	public static function setupDeath(boyfriend:Character):Void
	{
		if (boyfriend == null || boyfriend.daveScript == null)
			return;
		DaveGameOver.reset();
		var death:String = boyfriend.daveScript.skins.get('deathSkin');
		if (death != null && death.length > 0 && find(death, Paths.getPath('characters/$death.json', TEXT)) != null)
			GameOverSubstate.characterName = death;
	}

	/**
	 * La GF de Dave: la que pide el escenario (gfOverride) o el gfSkin del jugador.
	 * Psych ya creó la del chart; si es otra, se cambia.
	 */
	public static function fixGirlfriend(game:PlayState):Void
	{
		if (game == null || game.gf == null || (!preferDave && FluxDaveStage.current == null))
			return;
		var wanted:String = FluxDaveStage.gfOverride;
		if (wanted == null && game.boyfriend != null && game.boyfriend.daveScript != null)
			wanted = game.boyfriend.daveScript.skins.get('gfSkin');
		if (wanted == null || wanted.length == 0 || wanted == game.gf.curCharacter || !exists(wanted))
			return;
		var gf:Character = game.gf;
		gf.changeCharacter(wanted);
		gf.setPosition(game.GF_X + gf.positionArray[0], game.GF_Y + gf.positionArray[1]);
		if (FluxDaveStage.current != null)
			FluxDaveStage.current.placeCharacter(gf, 'gf');
	}

	/** Si hay un personaje (de Dave o de Psych) con ese nombre. */
	public static function exists(name:String):Bool
	{
		var psychPath:String = Paths.getPath('characters/$name.json', TEXT);
		return find(name, psychPath) != null #if MODS_ALLOWED || FileSystem.exists(psychPath) #end;
	}

	// ----- Para los scripts (VSliceAdapter): lo de Dave en los personajes del juego -----

	static var FIELDS:Array<String> = [
		'id', 'skins', 'danceTypes', 'altDanceSuffix', 'altSingSuffix', 'canDance', 'canSing', 'danceSnap', 'globalOffset', 'cameraOffset',
		'characterColor', 'nativelyPlayable', 'startsCountdown', 'isDead', 'characterType', 'baseScale', 'offsetScale', 'scaleOffset', 'sheetsInUse',
		'countdownGraphicType', 'countdownSoundType', 'characterName', 'characterIcon', 'cameraFocusPoint', '_data'
	];

	static var METHODS:Array<String> = [
		'sing', 'isSinging', 'isDancing', 'isSingAnimation', 'isDanceAnimation', 'isLoopAnimation', 'isEaseAnimation', 'hasEase', 'hasLoopAnimation',
		'fetchBaseAnimationName', 'playDanceAnimation', 'playLoopingAnimation', 'playComboAnimation', 'addOffset', 'addCharAtlas', 'loadOffsetFile',
		'setScale', 'flip', 'reposition', 'resetCameraFocusPoint', 'refreshOffsets'
	];

	/** `PlayState.instance.dad.skins`, `boyfriend.isDanceAnimation(...)`... (UNHANDLED si no es de Dave). */
	public static function getField(char:Character, field:String, unhandled:Dynamic):Dynamic
	{
		var script:DaveCharacter = char.daveScript;
		if (script == null)
			return unhandled;
		if (FIELDS.contains(field))
			return Reflect.getProperty(script, field);
		if (METHODS.contains(field))
			return Reflect.getProperty(script, field);
		if (field == 'dance')
			return function(?force:Bool) script.dance(force == true);
		return unhandled;
	}

	/** Devuelve true si escribió el valor. */
	public static function setField(char:Character, field:String, value:Dynamic):Bool
	{
		var script:DaveCharacter = char.daveScript;
		if (script == null || field == 'id' || field == 'characterName' || field == 'characterIcon' || field == 'cameraFocusPoint'
			|| !FIELDS.contains(field))
			return false;
		Reflect.setProperty(script, field, value);
		return true;
	}
}
#end
