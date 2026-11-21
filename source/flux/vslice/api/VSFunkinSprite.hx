package flux.vslice.api;

#if FLUX_VSLICE_SCRIPTS
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flux.vslice.api.VSliceApi.VSPaths;

/**
 * FunkinSprite de V-Slice (lo más usado en módulos): create, loadTexture,
 * loadSparrow, makeSolidColor... Las imágenes se buscan con VSPaths.
 */
@:keep
class VSFunkinSprite extends FlxSprite
{
	public function new(x:Float = 0, y:Float = 0, ?graphic:Dynamic)
	{
		super(x, y);
		if (graphic != null)
		{
			// en V-Slice suele ser Paths.image('x'); en Flux eso ya es la imagen
			if (Std.isOfType(graphic, String))
				loadTexture(graphic);
			else
				loadGraphic(graphic);
		}
	}

	/** Precarga una imagen (en Psych las imágenes ya quedan guardadas al cargarlas). */
	public static function cacheTexture(key:Dynamic):Void
		flux.vslice.api.VSliceApi.VSFunkinMemory.cacheTexture(key);

	public static function cacheSparrow(key:Dynamic):Void
		flux.vslice.api.VSliceApi.VSFunkinMemory.cacheTexture(key);

	public static function cachePacker(key:Dynamic):Void
		flux.vslice.api.VSliceApi.VSFunkinMemory.cacheTexture(key);

	public static function isTextureCached(key:Dynamic):Bool
		return key != null;

	public static function create(x:Float = 0, y:Float = 0, ?key:String):VSFunkinSprite
	{
		var sprite:VSFunkinSprite = new VSFunkinSprite(x, y);
		if (key != null)
			sprite.loadTexture(key);
		return sprite;
	}

	public static function createSparrow(x:Float = 0, y:Float = 0, key:String):VSFunkinSprite
	{
		var sprite:VSFunkinSprite = new VSFunkinSprite(x, y);
		sprite.loadSparrow(key);
		return sprite;
	}

	public static function createPacker(x:Float = 0, y:Float = 0, key:String):VSFunkinSprite
	{
		var sprite:VSFunkinSprite = new VSFunkinSprite(x, y);
		sprite.loadPacker(key);
		return sprite;
	}

	public function loadTexture(key:String):VSFunkinSprite
	{
		var graphic:Dynamic = VSPaths.image(key);
		if (graphic != null)
			loadGraphic(graphic);
		return this;
	}

	public function loadSparrow(key:String):VSFunkinSprite
	{
		var atlas:Dynamic = VSPaths.getSparrowAtlas(key);
		if (atlas != null)
			frames = atlas;
		return this;
	}

	public function loadPacker(key:String):VSFunkinSprite
	{
		var atlas:Dynamic = VSPaths.getPackerAtlas(key);
		if (atlas != null)
			frames = atlas;
		return this;
	}

	public function makeSolidColor(width:Int, height:Int, color:FlxColor = FlxColor.WHITE):VSFunkinSprite
	{
		makeGraphic(1, 1, color);
		scale.set(width, height);
		updateHitbox();
		return this;
	}

	public function hasAnimation(id:String):Bool
		return animation.getByName(id) != null;

	public function getCurrentAnimation():String
		return animation.curAnim != null ? animation.curAnim.name : '';

	public function isAnimationFinished():Bool
		return animation.finished;
}
#end
