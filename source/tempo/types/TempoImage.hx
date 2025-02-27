package tempo.types;

typedef TempoImage =
{
	path:String,
	?color:FlxColor,
	?cache:Bool,
	?animated:Bool,
	?frameWidth:Int,
	?frameHeight:Int,
	?animations:Array<Dynamic>,
	?width:Float,
	?height:Float
}
