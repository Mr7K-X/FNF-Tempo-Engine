package tempo.ui;

class TempoUIList extends FlxGroup
{
	public static final TEXT_BIND_POS:Float = 7.5;

	public var bg:TempoSprite;
	public var listBG:Array<TempoSprite> = [];
	public var listBind:Array<FlxText> = [];
	public var listText:Array<FlxText> = [];

	public var maxWidth:Float = 0;
	public var maxHeight:Float = 0;

	public var addHeight:Float = 0;

	public function new(x:Float, y:Float, data:Array<TempoUIListData>):Void
	{
		super();

		bg = new TempoSprite(x, y);
		add(bg);

		for (i in 0...data.length)
		{
			if (data[i] != null)
			{
				var text:FlxText = new FlxText(x + 5, 0, 500, data[i].text, 16);
				text.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, OUTLINE);
				text.scrollFactor.set();
				text.fieldWidth = text.textField.textWidth + 6.5;

				var bind:FlxText = null;

				if (data[i].bind != null)
				{
					bind = new FlxText(x + 5, 0, 500, data[i].bind, 16);
					bind.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, RIGHT, OUTLINE);
					bind.scrollFactor.set();
					bind.fieldWidth = bind.textField.textWidth + 6.5;
				}

				var bg:TempoSprite = new TempoSprite(x + 2.5, y + 2.5);
				bg.makeGraphic(1, Math.floor(text.textField.textHeight + 5), FlxColor.TRANSPARENT);
				bg.y += (bg.height * (i - addHeight)) + addHeight;
				bg.scrollFactor.set();

				text.y = bg.y + 4;
				if (bind != null)
					bind.y = bg.y + 4;

				listBG.push(bg);
				listText.push(text);
				if (bind != null)
					listBind.push(bind);
			}
			else
			{
				addHeight += 1;
			}
		}

		for (bg in listBG)
		{
			add(bg);
		}

		for (text in listText)
		{
			add(text);

			trace(text.textField.textWidth);

			if (text.textField.textWidth >= maxWidth)
				maxWidth = text.textField.textWidth;

			if (listBind.length != 0)
			{
				for (bind in listBind)
				{
					add(bind);

					if ((bind.textField.textWidth + text.textField.textWidth + TEXT_BIND_POS) >= maxWidth)
						maxWidth = (bind.textField.textWidth + text.textField.textWidth + TEXT_BIND_POS);
				}
			}
		}

		for (bind in listBind)
		{
			bind.x = maxWidth - bind.textField.textWidth;
			bind.alignment = RIGHT;
		}

		for (bg in listBG)
		{
			bg.makeRoundRect({
				width: maxWidth + 5,
				height: bg.height,
				color: Constants.COLOR_EDITOR_LIST_BUTTON,
				roundRect: {elWidth: 10, elHeight: 10}
			});

			maxHeight += bg.height;
		}

		bg.makeRoundRect({
			width: maxWidth + 10,
			height: maxHeight + 2.5 + (addHeight != 0 ? addHeight + 2.5 : 0),
			color: Constants.COLOR_EDITOR_LIST_BOX,
			roundRect: {elWidth: 10, elHeight: 10}
		});

		trace('maxWidth: $maxWidth');
	}

	@:access(flixel.FlxCamera)
	override function draw():Void
	{
		if (_cameras != null)
		{
			if (bg != null)
				bg.cameras = _cameras;

			for (abg in listBG)
				abg.cameras = _cameras;

			for (text in listText)
				text.cameras = _cameras;

			if (listBind.length != 0)
				for (bind in listBind)
					bind.cameras = _cameras;
		}

		super.draw();
	}

	override function update(elapsed:Float):Void
	{
		if (visible)
		{
			for (abg in listBG)
			{
				var overlaped:Bool = TempoInput.cursorOverlaps(abg, this.cameras[this.cameras.length - 1]);

				if (overlaped)
					abg.alpha = .6;
				else
					abg.alpha = .001;
			}
		}

		super.update(elapsed);
	}
}

typedef TempoUIListData =
{
	text:String,
	?bind:String,
	?onClick:TempoUIList->Void
}
