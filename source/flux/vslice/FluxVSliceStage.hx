package flux.vslice;

#if FLUX_VSLICE
import backend.Song.SwagSong;
import flixel.FlxBasic;
import backend.StageData.StageFile;
import haxe.ds.ObjectMap;
import objects.Character;
import openfl.display.BlendMode;
import states.PlayState;

using StringTools;

/**
 * Escenarios de mods de V-Slice (data/stages/<id>.json).
 *
 * PlayState lo usa cuando la canción pide un escenario que no existe en Psych
 * (stages/<id>.json). Hace lo mismo que Stage.buildStage y Stage.addCharacter de
 * V-Slice 0.8.5: crea los props, pone a los personajes parados en su posición
 * (el centro de abajo del personaje), con la escala, el scroll y el zIndex del
 * escenario, y ordena todo por zIndex.
 */
class FluxVSliceStage
{
	/** El escenario de V-Slice de la canción actual (null si es de Psych) */
	public static var current(default, null):FluxVSliceStage = null;

	public var id(default, null):String;
	public var data(default, null):Dynamic;
	public var props(default, null):Array<VSliceProp> = [];
	public var namedProps(default, null):Map<String, VSliceProp> = new Map();
	public var game(default, null):PlayState = null;

	var zIndexes:ObjectMap<FlxBasic, Int> = new ObjectMap();

	/** El escenario de V-Slice con ese id, o null si hay uno de Psych o no existe. */
	public static function load(id:String):FluxVSliceStage
	{
		current = null;
		if (id == null || id.length == 0)
			return null;
		if (Paths.fileExists('stages/$id.json', TEXT)) // si hay uno de Psych, se usa ese
			return null;
		var data:Dynamic = FluxVSliceAssets.readJson(FluxVSliceAssets.findData('data/stages/$id.json'));
		if (data == null || !Std.isOfType(data.props, Array))
			return null;
		current = new FluxVSliceStage(id, data);
		return current;
	}

	function new(id:String, data:Dynamic)
	{
		this.id = id;
		this.data = data;
	}

	/** Lo que PlayState necesita de un escenario de Psych. Las posiciones las pone placeCharacter. */
	public function stageFile(song:SwagSong):StageFile
	{
		var noGirlfriend:Bool = song == null || song.gfVersion == null || song.gfVersion.trim().length == 0 || roleData('gf') == null;
		return {
			directory: data.directory != null ? Std.string(data.directory) : '',
			defaultZoom: data.cameraZoom != null ? data.cameraZoom : 1.0,
			isPixelStage: false,
			stageUI: 'normal',
			boyfriend: [0, 0],
			girlfriend: [0, 0],
			opponent: [0, 0],
			hide_girlfriend: noGirlfriend,
			camera_boyfriend: cameraOffsetsOf('bf'),
			camera_opponent: cameraOffsetsOf('dad'),
			camera_girlfriend: cameraOffsetsOf('gf'),
			camera_speed: null
		};
	}

	/**
	 * Stage.addCharacter de V-Slice. `role`: "bf", "dad" o "gf".
	 * Se llama desde PlayState.startCharacterPos (también al cambiar de personaje).
	 */
	public function placeCharacter(char:Character, role:String):Void
	{
		var charData:Dynamic = roleData(role);
		if (char == null || charData == null)
			return;

		// resetCharacter: la animación de baile desde el principio y el hitbox medido con ella
		var start:String = (char.danceIdle ? 'danceLeft' : 'idle') + char.idleSuffix;
		if (char.hasAnimation(start))
			char.playAnim(start, true);
		char.updateHitbox();
		if (char.vsliceData != null)
			char.refreshVSliceOffsets();

		// parado sobre la posición del escenario (el centro de abajo del personaje)
		var position:Array<Float> = floats(charData.position, [0, 0]);
		char.x = position[0] - char.width / 2;
		char.y = position[1] - char.height;

		var stageScale:Float = charData.scale != null ? charData.scale : 1.0;
		FluxVSliceCharacters.setScale(char, char.jsonScale * stageScale);

		var scroll:Array<Float> = floats(charData.scroll, [1, 1]);
		char.scrollFactor.set(scroll[0], scroll[1]);
		if (charData.alpha != null)
			char.alpha = charData.alpha;
		if (charData.angle != null)
			char.angle = charData.angle;
		setZIndex(char, zIndexOfRole(role));

		// V-Slice enfoca el centro del personaje + sus cameraOffsets + los del escenario
		// (los del escenario van en el StageFile). Esto deja las cuentas de Psych iguales.
		if (char.vsliceData != null)
		{
			var camera:Array<Float> = floats(char.vsliceData.cameraOffsets, [0, 0]);
			char.cameraPosition = switch (role)
			{
				case 'bf': [-100 - camera[0], camera[1] + 100];
				case 'dad': [camera[0] - 150, camera[1] + 100];
				default: [camera[0], camera[1]];
			}
		}
	}

	/** Crea los props y agrega todo al PlayState ordenado por zIndex (en lugar de add(gfGroup)...). */
	public function build(game:PlayState):Void
	{
		this.game = game;
		var entries:Array<{z:Int, object:FlxBasic}> = [];

		for (propData in (data.props : Array<Dynamic>))
		{
			var prop:VSliceProp = makeProp(propData);
			if (prop == null)
				continue;
			props.push(prop);
			if (prop.name != null && prop.name.length > 0)
			{
				namedProps.set(prop.name, prop);
				game.variables.set(prop.name, prop); // getProperty('bg.alpha') desde Lua/HScript
			}
			setZIndex(prop, prop.zIndex);
			entries.push({z: prop.zIndex, object: prop});
		}

		for (role in ['gf', 'dad', 'bf'])
		{
			var group:FlxSpriteGroup = groupOf(role);
			zIndexes.set(group, zIndexOfRole(role));
			entries.push({z: zIndexOfRole(role), object: group});
			// el grupo le pasa su scroll a los personajes que se agreguen después
			var charData:Dynamic = roleData(role);
			var scroll:Array<Float> = floats(charData != null ? charData.scroll : null, [1, 1]);
			group.scrollFactor.set(scroll[0], scroll[1]);
		}

		// con el mismo zIndex queda el orden del JSON y los personajes después de los props (como V-Slice)
		haxe.ds.ArraySort.sort(entries, function(a, b) return a.z - b.z);
		for (entry in entries)
			game.add(entry.object);
	}

	/** Los props bailan como en V-Slice (Bopper.onStepHit). */
	public function stepHit(step:Int):Void
	{
		for (prop in props)
			if (prop != null && prop.exists)
				prop.stepHit(step);
	}

	public function getNamedProp(name:String):VSliceProp
		return namedProps.get(name);

	// ----- zIndex -----

	public function zIndexOf(object:FlxBasic):Int
	{
		if (object == null)
			return 0;
		if (zIndexes.exists(object))
			return zIndexes.get(object);
		if (Std.isOfType(object, VSliceProp))
			return (cast object : VSliceProp).zIndex;
		return 0;
	}

	public function setZIndex(object:FlxBasic, value:Int):Void
	{
		if (object == null)
			return;
		zIndexes.set(object, value);
		if (Std.isOfType(object, VSliceProp))
			(cast object : VSliceProp).zIndex = value;
		// los personajes de Psych están dentro de un grupo: el grupo es el que se ordena
		if (game != null && Std.isOfType(object, Character))
			for (role in ['gf', 'dad', 'bf'])
			{
				var group:FlxSpriteGroup = groupOf(role);
				if (group != null && group.members.contains(cast object))
					zIndexes.set(group, value);
			}
	}

	public function hasZIndex(object:FlxBasic):Bool
		return object != null && zIndexes.exists(object);

	/**
	 * Stage.refresh de V-Slice: ordena por zIndex los objetos del escenario.
	 * Lo demás del PlayState (HUD, sprites de Lua...) se queda en su lugar.
	 */
	public function refresh():Void
	{
		if (game == null)
			return;
		var members:Array<FlxBasic> = game.members;
		var slots:Array<Int> = [];
		var objects:Array<FlxBasic> = [];
		for (i in 0...members.length)
		{
			var member:FlxBasic = members[i];
			if (member != null && zIndexes.exists(member))
			{
				slots.push(i);
				objects.push(member);
			}
		}
		haxe.ds.ArraySort.sort(objects, function(a, b) return zIndexOf(a) - zIndexOf(b));
		for (i in 0...slots.length)
			members[slots[i]] = objects[i];
	}

	public function destroy():Void
	{
		props = [];
		namedProps.clear();
		zIndexes = new ObjectMap();
		game = null;
		if (current == this)
			current = null;
	}

	// ------------------------------------------------------------------

	function makeProp(propData:Dynamic):VSliceProp
	{
		var assetPath:String = propData.assetPath != null ? Std.string(propData.assetPath) : '';
		var animations:Array<Dynamic> = Std.isOfType(propData.animations, Array) ? propData.animations : [];
		var animType:String = propData.animType != null ? Std.string(propData.animType) : 'sparrow';
		var isSolidColor:Bool = assetPath.startsWith('#');
		var isAnimated:Bool = animations.length > 0;
		var scale:Array<Float> = scaleOf(propData.scale);

		var prop:VSliceProp = new VSliceProp();
		prop.name = propData.name != null ? Std.string(propData.name) : null;
		prop.danceEvery = propData.danceEvery != null ? propData.danceEvery : 0;

		if (isAnimated)
		{
			switch (animType)
			{
				case 'packer':
					prop.frames = Paths.getPackerAtlas(assetPath);
				case 'animateatlas':
					trace('[Flux V-Slice] escenario $id: el prop "${prop.name}" usa animateatlas, que todavía no funciona en Flux');
					return null;
				default:
					prop.frames = Paths.getSparrowAtlas(assetPath);
			}
		}
		else if (isSolidColor)
		{
			var color:Null<FlxColor> = FlxColor.fromString(assetPath);
			prop.makeGraphic(Std.int(Math.max(1, scale[0])), Std.int(Math.max(1, scale[1])), color != null ? color : FlxColor.BLACK);
		}
		else
		{
			var graphic = Paths.image(assetPath);
			if (graphic == null)
			{
				trace('[Flux V-Slice] escenario $id: no se encontró la imagen "$assetPath"');
				return null;
			}
			prop.loadGraphic(graphic);
			prop.active = false; // una imagen quieta no necesita update()
		}
		if (prop.frames == null || prop.frames.numFrames == 0)
		{
			trace('[Flux V-Slice] escenario $id: no se pudo cargar "$assetPath"');
			return null;
		}

		if (!isSolidColor)
			prop.scale.set(scale[0], scale[1]);
		prop.updateHitbox();

		var position:Array<Float> = floats(propData.position, [0, 0]);
		prop.x = position[0];
		prop.y = position[1];
		prop.alpha = propData.alpha != null ? propData.alpha : 1.0;
		prop.antialiasing = ClientPrefs.data.antialiasing && propData.isPixel != true;
		var scroll:Array<Float> = floats(propData.scroll, [1, 1]);
		prop.scrollFactor.set(scroll[0], scroll[1]);
		prop.angle = propData.angle != null ? propData.angle : 0;
		if (!isSolidColor && propData.color != null)
		{
			var color:Null<FlxColor> = FlxColor.fromString(Std.string(propData.color));
			if (color != null)
				prop.color = color;
		}
		prop.blend = blendOf(propData.blend);
		prop.zIndex = propData.zIndex != null ? Std.int(propData.zIndex) : 0;
		prop.flipX = (propData.flipX == true);
		prop.flipY = (propData.flipY == true);

		for (anim in animations)
		{
			if (anim.name == null) continue;
			var name:String = Std.string(anim.name);
			var indices:Array<Int> = [];
			if (Std.isOfType(anim.frameIndices, Array))
				for (index in (anim.frameIndices : Array<Dynamic>)) indices.push(Std.int(index));
			var fps:Int = anim.frameRate != null ? Std.int(anim.frameRate) : 24;
			var looped:Bool = (anim.looped == true);
			if (animType == 'packer')
				prop.animation.add(name, indices);
			else if (anim.prefix != null)
			{
				if (indices.length > 0)
					prop.animation.addByIndices(name, Std.string(anim.prefix), indices, '', fps, looped, anim.flipX == true, anim.flipY == true);
				else
					prop.animation.addByPrefix(name, Std.string(anim.prefix), fps, looped, anim.flipX == true, anim.flipY == true);
			}
			var offsets:Array<Float> = floats(anim.offsets, [0, 0]);
			prop.setAnimationOffsets(name, offsets[0], offsets[1]);
		}

		var startingAnimation:String = propData.startingAnimation != null ? Std.string(propData.startingAnimation) : '';
		if (startingAnimation.length > 0)
			prop.playAnimation(startingAnimation);
		return prop;
	}

	function roleData(role:String):Dynamic
	{
		var characters:Dynamic = data.characters;
		if (characters == null)
			return null;
		return Reflect.field(characters, role);
	}

	function zIndexOfRole(role:String):Int
	{
		var charData:Dynamic = roleData(role);
		return (charData != null && charData.zIndex != null) ? Std.int(charData.zIndex) : 0;
	}

	function cameraOffsetsOf(role:String):Array<Float>
	{
		var charData:Dynamic = roleData(role);
		return floats(charData != null ? charData.cameraOffsets : null, [0, 0]);
	}

	function groupOf(role:String):FlxSpriteGroup
	{
		if (game == null)
			return null;
		return switch (role)
		{
			case 'gf': game.gfGroup;
			case 'dad': game.dadGroup;
			default: game.boyfriendGroup;
		}
	}

	/** "scale" de un prop: un número o [x, y] */
	static function scaleOf(value:Dynamic):Array<Float>
	{
		if (value == null)
			return [1, 1];
		if (Std.isOfType(value, Array))
			return floats(value, [1, 1]);
		var number:Float = value;
		return [number, number];
	}

	static function floats(value:Dynamic, fallback:Array<Float>):Array<Float>
	{
		if (value == null || !Std.isOfType(value, Array))
			return fallback.copy();
		var list:Array<Dynamic> = value;
		var result:Array<Float> = [];
		for (i in 0...fallback.length)
			result.push((i < list.length && list[i] != null) ? (list[i] : Float) : fallback[i]);
		return result;
	}

	static function blendOf(value:Dynamic):BlendMode
	{
		if (value == null)
			return NORMAL;
		return switch (Std.string(value).toLowerCase().trim())
		{
			case 'add': ADD;
			case 'alpha': ALPHA;
			case 'darken': DARKEN;
			case 'difference': DIFFERENCE;
			case 'erase': ERASE;
			case 'hardlight': HARDLIGHT;
			case 'invert': INVERT;
			case 'layer': LAYER;
			case 'lighten': LIGHTEN;
			case 'multiply': MULTIPLY;
			case 'overlay': OVERLAY;
			case 'screen': SCREEN;
			case 'shader': SHADER;
			case 'subtract': SUBTRACT;
			default: NORMAL;
		}
	}
}
#end
