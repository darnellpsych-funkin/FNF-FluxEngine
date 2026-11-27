package flux.codename;

#if FLUX_CODENAME
import objects.Character;
import substates.GameOverSubstate;

/**
 * Personajes de Codename Engine (data/characters/<nombre>.xml).
 *
 * Character.changeCharacter los usa cuando no hay un personaje de Psych (ni de V-Slice)
 * con ese nombre: el XML se pasa a un JSON de personaje de Psych (ver CodenameData.character).
 */
class CodenameCharacters
{
	/** personaje -> personaje de la pantalla de game over (gameOverChar del XML) */
	static var deathChars:Map<String, String> = new Map();

	/** El personaje de Codename como {json, interval, gameOverChar, centerCam}, o null si no hay XML. */
	public static function find(name:String, isPlayer:Bool):Dynamic
	{
		if (name == null || name.length == 0) return null;
		var info:Dynamic = CodenameData.character(FluxCodename.readXml('data/characters/$name.xml'), name, isPlayer);
		if (info != null)
		{
			if (info.gameOverChar != null) deathChars.set(name, info.gameOverChar);
			else deathChars.remove(name);
		}
		return info;
	}

	/** Lo que el JSON de Psych no tiene: el intervalo de baile y la cámara de los personajes escalados. */
	public static function afterLoad(char:Character, info:Dynamic):Void
	{
		if (char == null || info == null) return;

		var interval:Null<Int> = info.interval;
		if (interval != null) char.danceEveryNumBeats = Std.int(Math.max(1, interval));

		// Codename mide el centro del personaje sin la escala (o la esquina con centercam="false"),
		// Psych con la escala: se corrige la cámara para que apunte al mismo lugar
		var scale:Float = char.jsonScale != 0 ? char.jsonScale : 1;
		var centerCam:Bool = info.centerCam != false;
		if (scale == 1 && centerCam) return;
		var dx:Float = centerCam ? (char.width - char.width / scale) / 2 : char.width / 2;
		var dy:Float = centerCam ? (char.height - char.height / scale) / 2 : char.height / 2;
		if (char.cameraPosition == null || char.cameraPosition.length < 2) char.cameraPosition = [0, 0];
		// Psych suma cameraPosition[0] al oponente y se la resta al jugador
		char.cameraPosition[0] += char.isPlayer ? dx : -dx;
		char.cameraPosition[1] -= dy;
	}

	/** gameOverChar del personaje del jugador (si la canción no pide otro). */
	public static function setupDeath(boyfriend:Character):Void
	{
		if (boyfriend == null || !deathChars.exists(boyfriend.curCharacter)) return;
		var song = PlayState.SONG;
		if (song != null && song.gameOverChar != null && song.gameOverChar.trim().length > 0) return;
		GameOverSubstate.characterName = deathChars.get(boyfriend.curCharacter);
	}
}
#end
