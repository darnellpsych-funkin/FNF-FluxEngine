package flux.vslice;

#if FLUX_VSLICE
/**
 * Un prop de un escenario de V-Slice (StageProp / Bopper).
 *
 * Igual que en V-Slice, el offset de cada animación no reemplaza a `offset`:
 * se resta al dibujar, multiplicado por la escala (ver getScreenPosition).
 */
class VSliceProp extends FlxSprite
{
	/** Nombre del prop en el JSON del escenario (getNamedProp) */
	public var name:String = null;

	/** Orden de dibujo: los números más altos van adelante */
	public var zIndex:Int = 0;

	/** Baila cada cuántos beats (0 = nunca). Acepta fracciones de 0.25. */
	public var danceEvery:Float = 0;

	/** Si es true, reinicia la animación cada vez que baila (como los props de V-Slice) */
	public var shouldBop:Bool = true;

	/** Si es null se decide solo: danceLeft/danceRight si existen, si no idle */
	public var shouldAlternate:Null<Bool> = null;

	public var idleSuffix:String = '';

	/** Offsets de V-Slice por animación */
	public var animOffsets:Map<String, Array<Float>> = new Map();

	public var currentOffsets(default, null):Array<Float> = [0, 0];

	var hasDanced:Bool = false;

	public function setAnimationOffsets(name:String, x:Float, y:Float):Void
	{
		animOffsets.set(name, [x, y]);
		if (animation.curAnim != null && animation.curAnim.name == name)
			currentOffsets = [x, y];
	}

	public function hasAnimation(name:String):Bool
		return animation.exists(name);

	public function getCurrentAnimation():String
		return animation.curAnim != null ? animation.curAnim.name : '';

	public function playAnimation(name:String, restart:Bool = false, ignoreOther:Bool = false, reversed:Bool = false):Void
	{
		if (!animation.exists(name))
			return;
		animation.play(name, restart, reversed, 0);
		var offsets:Array<Float> = animOffsets.get(name);
		currentOffsets = offsets != null ? offsets : [0, 0];
	}

	public function dance(forceRestart:Bool = false):Void
	{
		if (shouldAlternate == null)
			shouldAlternate = animation.exists('danceLeft$idleSuffix') && animation.exists('danceRight$idleSuffix');

		if (shouldAlternate)
		{
			playAnimation(hasDanced ? 'danceRight$idleSuffix' : 'danceLeft$idleSuffix', forceRestart);
			hasDanced = !hasDanced;
		}
		else
			playAnimation('idle$idleSuffix', forceRestart);
	}

	/** Bopper.onStepHit de V-Slice */
	public function stepHit(step:Int):Void
	{
		if (danceEvery > 0 && (step % (danceEvery * 4)) == 0)
			dance(shouldBop);
	}

	override public function getScreenPosition(?result:FlxPoint, ?camera:FlxCamera):FlxPoint
	{
		var output:FlxPoint = super.getScreenPosition(result, camera);
		output.x -= currentOffsets[0] * scale.x;
		output.y -= currentOffsets[1] * scale.y;
		return output;
	}
}
#end
