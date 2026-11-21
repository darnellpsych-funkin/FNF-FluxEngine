package flux.vslice;

#if FLUX_VSLICE
import objects.Character;
import substates.GameOverSubstate;

/**
 * Personajes de mods de V-Slice (data/characters/<id>.json).
 *
 * Character.changeCharacter() los busca acá cuando no existe el personaje de Psych
 * (characters/<id>.json) y los carga con Character.loadVSliceCharacter().
 */
class FluxVSliceCharacters
{
	/** El JSON de V-Slice del personaje, o null si no hay. */
	public static function find(id:String):Dynamic
	{
		if (id == null || id.length == 0)
			return null;
		var data:Dynamic = FluxVSliceAssets.readJson(FluxVSliceAssets.findData('data/characters/$id.json'));
		// un personaje de V-Slice tiene "assetPath" y animaciones con "prefix"
		if (data == null || data.assetPath == null || !Std.isOfType(data.animations, Array))
			return null;
		return data;
	}

	public static inline function isVSlice(id:String):Bool
		return find(id) != null;

	/**
	 * BaseCharacter.setScale de V-Slice: cambia la escala sin mover los pies
	 * (el centro de abajo del hitbox) y suma los "offsets" del personaje.
	 */
	public static function setScale(char:Character, value:Float):Void
	{
		var feetX:Float = char.x + char.width / 2;
		var feetY:Float = char.y + char.height;
		var oldScale:Float = char.scale.x;

		char.scale.set(value, value);
		char.updateHitbox();

		var globalX:Float = char.vsliceData != null ? char.vsliceGlobalOffsets[0] : 0;
		var globalY:Float = char.vsliceData != null ? char.vsliceGlobalOffsets[1] : 0;
		char.x = feetX - char.width / 2 + globalX;
		char.y = feetY - char.height + globalY;

		if (char.vsliceData != null)
			char.refreshVSliceOffsets();
		else if (oldScale != 0 && oldScale != value)
		{
			// personaje de Psych: sus offsets estaban pensados para la escala anterior
			var factor:Float = value / oldScale;
			for (name => offsets in char.animOffsets)
				char.animOffsets.set(name, [offsets[0] * factor, offsets[1] * factor]);
		}
		replayAnimation(char);
	}

	/** Vuelve a poner la animación actual para que tome el offset nuevo. */
	public static function replayAnimation(char:Character):Void
	{
		var name:String = char.getAnimationName();
		if (name == null || !char.hasAnimation(name) || char.isAnimationNull())
			return;
		var frame:Int = char.isAnimateAtlas ? 0 : char.animation.curAnim.curFrame;
		char.playAnim(name, true, false, frame);
	}

	/**
	 * En V-Slice el game over usa el mismo personaje (firstDeath, deathLoop, deathConfirm).
	 * Si el jugador es de V-Slice y tiene esas animaciones, el game over lo usa a él.
	 */
	public static function setupDeath(boyfriend:Character):Void
	{
		if (boyfriend == null || boyfriend.vsliceData == null || !boyfriend.hasAnimation('firstDeath'))
			return;
		if (GameOverSubstate.characterName == 'bf-dead') // la canción no eligió otro
			GameOverSubstate.characterName = boyfriend.curCharacter;
	}

	/** El personaje del game over en el mismo lugar y tamaño que el jugador. */
	public static function makeDeathCharacter(name:String, player:Character):Character
	{
		var char:Character = new Character(0, 0, name, true);
		if (player != null)
		{
			char.scale.set(player.scale.x, player.scale.y);
			char.updateHitbox();
			if (char.vsliceData != null)
				char.refreshVSliceOffsets();
			// el game over pone la cámara en 0, así que va donde se veía en pantalla
			char.x = player.x - FlxG.camera.scroll.x * player.scrollFactor.x;
			char.y = player.y - FlxG.camera.scroll.y * player.scrollFactor.y;
		}
		var death:Dynamic = char.vsliceData != null ? char.vsliceData.death : null;
		var cameraOffsets:Array<Dynamic> = (death != null && Std.isOfType(death.cameraOffsets, Array)) ? death.cameraOffsets : [0, 0];
		char.cameraPosition = [cameraOffsets[0], cameraOffsets[1]];
		return char;
	}
}
#end
