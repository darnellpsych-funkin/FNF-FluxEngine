package flux.codename;

#if FLUX_CODENAME
import backend.BaseStage;
import backend.StageData.StageFile;
import psychlua.LuaUtils;
import psychlua.ModchartSprite;

/**
 * Escenarios de Codename Engine (data/stages/<nombre>.xml).
 *
 * PlayState lo usa cuando no hay un escenario de Psych (stages/<nombre>.json) ni de V-Slice.
 * Arma los sprites como Codename: sin updateHitbox (salvo `updateHitbox="true"`), los offsets
 * de las animaciones escalados, `type="beat"` (baila en el beat) o `"loop"`, los grupos
 * `high-memory`/`low-memory` (con "Low Quality") y los personajes en el orden del XML.
 * Cada sprite queda en `game.variables` con su nombre (getProperty('bg') en Lua).
 */
class CodenameStage extends BaseStage
{
	/** El escenario de Codename de la canción actual (null si no es de Codename). */
	public static var current(default, null):CodenameStage = null;

	public var id(default, null):String;
	public var data(default, null):Dynamic;
	public var stageFile(default, null):StageFile;

	/** Los sprites del escenario por nombre. */
	public var sprites(default, null):Map<String, FlxSprite> = new Map();

	var beatSprites:Array<Dynamic> = [];

	/** El escenario de Codename con ese nombre, o null (si hay uno de Psych, se usa ese). */
	public static function load(id:String):CodenameStage
	{
		current = null;
		if (id == null || id.length == 0 || Paths.fileExists('stages/$id.json', TEXT)) return null;
		var data:Dynamic = CodenameData.stage(FluxCodename.readXml('data/stages/$id.xml'));
		if (data == null) return null;
		var stage:CodenameStage = new CodenameStage();
		stage.id = id;
		stage.data = data;
		stage.stageFile = stage.makeStageFile();
		trace('[Flux Codename] escenario $id');
		return current = stage;
	}

	function makeStageFile():StageFile
	{
		var bf:Dynamic = roleNode('boyfriend');
		var gf:Dynamic = roleNode('girlfriend');
		var dad:Dynamic = roleNode('dad');
		return {
			directory: '',
			defaultZoom: data.zoom,
			isPixelStage: false,
			stageUI: 'normal',
			boyfriend: [bf.x, bf.y],
			girlfriend: [gf.x, gf.y],
			opponent: [dad.x, dad.y],
			hide_girlfriend: false,
			camera_boyfriend: [bf.camX, bf.camY],
			camera_opponent: [dad.camX, dad.camY],
			camera_girlfriend: [gf.camX, gf.camY],
			camera_speed: null
		};
	}

	function roleNode(role:String):Dynamic
	{
		for (node in (data.nodes : Array<Dynamic>))
			if (node.kind == role) return node;
		return {x: 0, y: 0, camX: 0, camY: 0};
	}

	/** Agrega los sprites y los grupos de personajes al PlayState en el orden del XML. */
	public function build(game:PlayState):Void
	{
		for (node in (data.nodes : Array<Dynamic>))
		{
			if (node.quality == 'high' && ClientPrefs.data.lowQuality) continue;
			if (node.quality == 'low' && !ClientPrefs.data.lowQuality) continue;
			switch (node.kind)
			{
				case 'sprite', 'box':
					var spr:FlxSprite = node.kind == 'sprite' ? makeSprite(node) : makeBox(node);
					if (spr == null) continue;
					game.add(spr);
					sprites.set(node.name, spr);
					game.variables.set(node.name, spr);
				case 'boyfriend':
					game.add(game.boyfriendGroup);
					applyCharNode(game.boyfriendGroup, node);
				case 'girlfriend':
					game.add(game.gfGroup);
					applyCharNode(game.gfGroup, node);
				case 'dad':
					game.add(game.dadGroup);
					applyCharNode(game.dadGroup, node);
			}
		}
	}

	function applyCharNode(group:FlxSpriteGroup, node:Dynamic):Void
	{
		group.scrollFactor.set(node.scrollX, node.scrollY);
		if (node.alpha != null) group.alpha = node.alpha;
	}

	function makeSprite(node:Dynamic):FlxSprite
	{
		var path:String = node.sprite;
		var spr:ModchartSprite = new ModchartSprite(node.x, node.y);
		var atlas:Bool = Paths.fileExists('images/$path.xml', TEXT) || Paths.fileExists('images/$path.txt', TEXT)
			|| Paths.fileExists('images/$path.json', TEXT);
		if (atlas) spr.frames = Paths.getAtlas(path);
		else
		{
			var graphic = Paths.image(path);
			if (graphic == null)
			{
				trace('[Flux Codename] falta la imagen $path del escenario $id');
				return null;
			}
			spr.loadGraphic(graphic);
		}
		spr.antialiasing = ClientPrefs.data.antialiasing && node.antialiasing != false;

		var scaleX:Float = node.scaleX;
		var scaleY:Float = node.scaleY;
		var anims:Array<Dynamic> = node.anims;
		var names:Array<String> = [];
		var forced:Array<Bool> = [];
		for (anim in anims)
		{
			var indices:Array<Int> = anim.indices;
			if (indices != null && indices.length > 0)
			{
				if (anim.prefix == null) spr.animation.add(anim.name, indices, anim.fps, anim.loop);
				else spr.animation.addByIndices(anim.name, anim.prefix, indices, '', anim.fps, anim.loop);
			}
			else if (anim.prefix != null) spr.animation.addByPrefix(anim.name, anim.prefix, anim.fps, anim.loop);
			if (!spr.animation.exists(anim.name)) continue;
			// en Codename los offsets se escalan con el sprite
			spr.addOffset(anim.name, anim.x * scaleX, anim.y * scaleY);
			names.push(anim.name);
			forced.push(anim.forced != false); // en Codename las del beat se fuerzan salvo forced="false"
		}
		if (names.length == 0 && atlas && spr.frames != null && spr.frames.frames.length > 1)
		{
			spr.animation.add('idle', [for (i in 0...spr.frames.frames.length) i], 24, node.animType == 'loop');
			names.push('idle');
			forced.push(true);
		}

		switch (node.animType)
		{
			case 'loop':
				// Codename la arranca al agregarla: queda la última
				if (names.length > 0) spr.playAnim(names[names.length - 1], true);
			case 'beat':
				if (names.length > 0)
				{
					beatSprites.push({
						sprite: spr,
						anims: names,
						forced: forced,
						interval: node.beatInterval,
						offset: node.beatOffset,
						skipNegative: node.skipNegativeBeats == true,
						count: 0
					});
					spr.playAnim(names[0], true);
				}
		}

		spr.scrollFactor.set(node.scrollX, node.scrollY);
		spr.scale.set(scaleX, scaleY);
		if (node.graphicSize != null) spr.setGraphicSize(node.graphicSize, node.graphicSize);
		if (node.flipX != null) spr.flipX = node.flipX;
		if (node.flipY != null) spr.flipY = node.flipY;
		if (node.updateHitbox == true) spr.updateHitbox();
		applyCommon(spr, node);
		return spr;
	}

	function makeBox(node:Dynamic):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(node.x, node.y);
		spr.makeGraphic(Std.int(Math.max(1, node.width)), Std.int(Math.max(1, node.height)), FlxColor.WHITE);
		spr.scrollFactor.set(node.scrollX, node.scrollY);
		applyCommon(spr, node);
		return spr;
	}

	function applyCommon(spr:FlxSprite, node:Dynamic):Void
	{
		if (node.alpha != null) spr.alpha = node.alpha;
		if (node.angle != null) spr.angle = node.angle;
		if (node.color != null)
		{
			var color:Null<FlxColor> = FlxColor.fromString(node.color);
			if (color != null) spr.color = color;
		}
		if (node.blend != null) spr.blend = LuaUtils.blendModeFromString(node.blend);
		var props:Array<Dynamic> = node.properties;
		if (props != null)
			for (prop in props)
			{
				try
				{
					setProperty(spr, prop.name, CodenameData.propertyValue(prop.type, prop.value));
				}
				catch (e:Dynamic)
				{
					trace('[Flux Codename] no se pudo poner ${prop.name} en ${node.name}: $e');
				}
			}
	}

	/** Pone una propiedad (también con puntos: "scale.x"). */
	static function setProperty(target:Dynamic, name:String, value:Dynamic):Void
	{
		var parts:Array<String> = name.split('.');
		for (i in 0...parts.length - 1)
		{
			target = Reflect.getProperty(target, parts[i]);
			if (target == null) return;
		}
		Reflect.setProperty(target, parts[parts.length - 1], value);
	}

	override function createPost()
	{
		// startCamPosX / startCamPosY: dónde arranca la cámara
		if (data.startCamX != null || data.startCamY != null)
		{
			camFollow.setPosition(data.startCamX != null ? data.startCamX : camFollow.x, data.startCamY != null ? data.startCamY : camFollow.y);
			FlxG.camera.snapToTarget();
		}
	}

	override function beatHit()
	{
		for (entry in beatSprites)
		{
			if (entry.skipNegative && curBeat < 0) continue;
			var interval:Int = entry.interval;
			var offset:Int = entry.offset;
			if ((curBeat + offset) % interval != 0) continue;
			var names:Array<String> = entry.anims;
			var count:Int = entry.count;
			entry.count = count + 1;
			var index:Int = count % names.length;
			var spr:ModchartSprite = entry.sprite;
			if (spr.exists) spr.playAnim(names[index], entry.forced[index] != false);
		}
	}

	override function destroy()
	{
		if (current == this) current = null;
		beatSprites = [];
		super.destroy();
	}
}
#end
