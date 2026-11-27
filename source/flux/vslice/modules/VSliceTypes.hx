package flux.vslice.modules;

#if FLUX_VSLICE_SCRIPTS
import flux.vslice.api.Module;
import flux.vslice.api.ScriptEvent;
import flux.vslice.api.VSFunkinSprite;
import flux.vslice.api.VSliceApi;
import flux.vslice.modules.VSliceProxies;

using StringTools;

/**
 * Qué clase de Flux/Psych usa cada `import funkin...` de un módulo .hxc.
 * Lo que no está aquí se busca normal (flixel.*, openfl.*, etc.) y si no
 * existe queda como VSMissing (el módulo carga igual y avisa en la consola).
 */
class VSliceTypes
{
	static var aliases:Map<String, Dynamic>;

	public static function resolve(path:String):Dynamic
	{
		if (aliases == null)
			init();
		if (path == null)
			return null;
		var type:Dynamic = aliases.get(path);
		if (type != null)
			return type;

		// "funkin.modding.events.ScriptEvent.HitNoteScriptEvent" -> "funkin.modding.events.HitNoteScriptEvent"
		var parts:Array<String> = path.split('.');
		if (parts.length > 2)
		{
			var module:String = parts[parts.length - 2];
			if (module.length > 0 && module.charAt(0) == module.charAt(0).toUpperCase())
			{
				parts.splice(parts.length - 2, 1);
				return aliases.get(parts.join('.'));
			}
		}
		return null;
	}

	/** `import funkin.modding.events.*;` -> todas las clases conocidas de ese paquete. */
	public static function expandStar(pack:String):Array<String>
	{
		if (aliases == null)
			init();
		var result:Array<String> = [];
		var prefix:String = pack + '.';
		for (key in aliases.keys())
			if (key.startsWith(prefix) && key.indexOf('.', prefix.length) < 0)
				result.push(key);
		return result;
	}

	/** Variables que todo módulo tiene sin importar nada (los "default imports" de V-Slice). */
	public static function applyGlobals(variables:Map<String, Dynamic>):Void
	{
		variables.set('Reflect', VSReflectUtil);
		var defaults:Map<String, Dynamic> = new Map<String, Dynamic>();
		defaults.set('Paths', VSPaths);
		defaults.set('Assets', VSAssets);
		defaults.set('Preferences', VSPreferences);
		defaults.set('Constants', VSConstants);
		defaults.set('FlxG', flixel.FlxG);
		for (name => type in defaults)
			if (!variables.exists(name))
				variables.set(name, type);
	}

	static function init():Void
	{
		aliases = new Map<String, Dynamic>();
		var add = function(names:Array<String>, type:Dynamic) for (name in names) aliases.set(name, type);

		// Polymod cambia Reflect por ReflectUtil
		add(['Reflect', 'funkin.util.ReflectUtil'], VSReflectUtil);

		// clases estándar (así "import Math;" funciona igual en todas las plataformas)
		add(['Math'], Math);
		add(['Std'], Std);
		add(['StringTools'], StringTools);
		add(['Type'], Type);
		add(['Lambda'], Lambda);
		add(['Date'], Date);
		add(['DateTools'], DateTools);
		add(['haxe.Json'], haxe.Json);
		add(['haxe.ds.StringMap'], haxe.ds.StringMap);
		add(['haxe.ds.IntMap'], haxe.ds.IntMap);
		add(['haxe.ds.ObjectMap'], haxe.ds.ObjectMap);

		// --- módulos y eventos ---
		add(['funkin.modding.module.Module', 'funkin.modding.module.ScriptedModule'], Module);
		add(['funkin.play.event.SongEvent', 'funkin.play.event.ScriptedSongEvent'], flux.vslice.api.SongEvent);
		add(['funkin.data.event.SongEventRegistry'], flux.vslice.api.SongEvent.VSSongEventRegistry);
		add(['funkin.data.stage.StageRegistry'], VSStageRegistry);
		add(['funkin.modding.PolymodErrorHandler'], VSPolymodErrorHandler);
		add(['funkin.play.notes.notekind.NoteKind', 'funkin.play.notes.notekind.ScriptedNoteKind'], flux.vslice.api.NoteKind);
		add(['funkin.play.notes.notekind.NoteKindManager'], flux.vslice.api.NoteKind.VSNoteKindManager);
		add(['funkin.modding.module.ModuleHandler'], VSModuleHandler);
		add(['funkin.modding.ModStore'], VSModStore);
		add(['funkin.modding.events.ScriptEventDispatcher'], VSScriptEventDispatcher);
		add(['funkin.modding.events.ScriptEvent'], ScriptEvent);
		add(['funkin.modding.events.ScriptEventType'], ScriptEventType);
		add(['funkin.modding.events.UpdateScriptEvent'], UpdateScriptEvent);
		add(['funkin.modding.events.NoteScriptEvent'], NoteScriptEvent);
		add(['funkin.modding.events.HitNoteScriptEvent'], HitNoteScriptEvent);
		add(['funkin.modding.events.HoldNoteScriptEvent'], HoldNoteScriptEvent);
		add(['funkin.modding.events.GhostMissNoteScriptEvent'], GhostMissNoteScriptEvent);
		add(['funkin.modding.events.SongEventScriptEvent'], SongEventScriptEvent);
		add(['funkin.modding.events.SongTimeScriptEvent'], SongTimeScriptEvent);
		add(['funkin.modding.events.CountdownScriptEvent'], CountdownScriptEvent);
		add(['funkin.modding.events.SongLoadScriptEvent'], SongLoadScriptEvent);
		add(['funkin.modding.events.StateChangeScriptEvent'], StateChangeScriptEvent);
		add(['funkin.modding.events.SubStateScriptEvent'], SubStateScriptEvent);
		add(['funkin.modding.events.FocusScriptEvent'], FocusScriptEvent);
		add(['funkin.modding.events.PauseScriptEvent'], PauseScriptEvent);
		add(['funkin.modding.events.SongRetryEvent'], SongRetryEvent);
		add(['funkin.play.Countdown.CountdownStep', 'funkin.play.CountdownStep'], CountdownStep);

		// --- juego (Psych) ---
		add(['funkin.play.PlayState'], states.PlayState);
		add(['funkin.play.PauseSubState'], substates.PauseSubState);
		add(['funkin.play.GameOverSubState'], substates.GameOverSubstate);
		add(['funkin.play.PlayStatePlaylist'], VSPlayStatePlaylist);
		add(['funkin.play.scoring.Scoring'], VSScoring);
		add(['funkin.play.notes.NoteSprite'], objects.Note);
		add(['funkin.play.notes.StrumlineNote'], objects.StrumNote);
		add(['funkin.play.notes.Strumline'], VSStrumline);
		add([
			'funkin.play.character.BaseCharacter',
			'funkin.play.character.SparrowCharacter',
			'funkin.play.character.MultiSparrowCharacter',
			'funkin.play.character.PackerCharacter',
			'funkin.play.character.AnimateAtlasCharacter',
			'funkin.play.character.MultiAnimateAtlasCharacter'
		], objects.Character);
		add([
			'funkin.play.character.CharacterDataParser',
			'funkin.data.character.CharacterDataParser',
			'funkin.data.character.CharacterData.CharacterDataParser'
		], VSCharacterDataParser);
		add(['funkin.play.components.HealthIcon'], objects.HealthIcon);
		add(['funkin.play.character.CharacterType', 'funkin.play.character.BaseCharacter.CharacterType'], VSCharacterType);
		add(['funkin.data.song.SongData.SongEventData', 'funkin.data.song.SongEventData'], VSSongEventData);
		add(['funkin.play.stage.Stage'], VSStage);
		add(['funkin.play.song.Song'], VSSong);
		add(['funkin.audio.VoicesGroup'], VSVoices);
		add(['funkin.Conductor'], VSConductor);
		add(['funkin.Highscore', 'funkin.save.Highscore'], VSHighscore);
		add(['funkin.save.Save'], VSSave);
		add(['funkin.Paths', 'funkin.graphics.Paths'], VSPaths);
		// En V-Slice, Polymod pone los archivos de los mods en Assets: aquí se leen del disco
		add(['funkin.Assets', 'openfl.utils.Assets', 'openfl.Assets', 'lime.utils.Assets'], VSAssets);
		add(['funkin.Preferences'], VSPreferences);
		add(['funkin.util.Constants'], VSConstants);
		add(['funkin.graphics.FunkinSprite'], VSFunkinSprite);
		add(['funkin.FunkinMemory'], VSFunkinMemory);
		add(['funkin.util.FlxTweenUtil'], VSFlxTweenUtil);
		add(['flixel.util.FlxColor'], VSFlxColor); // un abstract: el script no lo puede usar directo
		// tipos de datos que solo se usan en anotaciones (así no avisa que faltan)
		add([
			'funkin.data.stage.StageData',
			'funkin.data.event.SongEventSchema',
			'funkin.data.event.SongEventData',
			'funkin.data.song.SongData',
			'funkin.data.song.SongData.SongNoteData',
			'funkin.data.song.SongData.SongMetadata',
			'funkin.data.character.CharacterData',
			'funkin.play.song.Song.SongDifficulty',
			'funkin.play.event.SongEvent.SongEventParams'
		], VSDataType);
		add(['funkin.graphics.FunkinCamera'], flixel.FlxCamera);
		add(['funkin.audio.FunkinSound'], VSFunkinSound);
		add(['funkin.ui.MusicBeatState'], backend.MusicBeatState);
		add(['funkin.ui.MusicBeatSubState'], backend.MusicBeatSubstate);
		add(['funkin.ui.title.TitleState'], states.TitleState);
		add(['funkin.ui.mainmenu.MainMenuState'], states.MainMenuState);
		add(['funkin.ui.story.StoryMenuState'], states.StoryMenuState);
		add(['funkin.ui.freeplay.FreeplayState'], states.FreeplayState);
		// El menú de opciones de V-Slice es muy distinto al de Psych: queda como VSMissing
	}
}
#end
