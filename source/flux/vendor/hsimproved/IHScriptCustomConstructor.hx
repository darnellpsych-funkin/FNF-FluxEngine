package flux.vendor.hsimproved;

/**
 * Special Interface for handling new instances of an object.
 */
interface IHScriptCustomConstructor {
	public function hnew(args:Array<Dynamic>):Dynamic;
}