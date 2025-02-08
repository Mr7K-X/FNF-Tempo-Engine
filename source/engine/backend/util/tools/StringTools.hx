package engine.backend.util.tools;

/**
 * A static extension which provides utility functions for Strings.
 */
class StringTools
{
	/**
	 * Converts a string to title case. For example, "hello world" becomes "Hello World".
	 	 *
	 * @param value The string to convert.
	 * @return The converted string.
	 */
	public static function toTitleCase(value:String):String
	{
		var words:Array<String> = value.split(' ');
		var result:String = '';
		for (i in 0...words.length)
		{
			var word:String = words[i];
			result += word.charAt(0).toUpperCase() + word.substr(1).toLowerCase();
			if (i < words.length - 1)
			{
				result += ' ';
			}
		}
		return result;
	}

	/**
	 * Converts a string to folder case, for ex: "hello World.4pa" becomes "hello-world.4pa"
	 * @param value The string to convert.
	 * @return Converted string.
	 */
	public static function toFolderCase(value:String):String
	{
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(value, '-'), '').trim().toLowerCase();
	}

	/**
	 * Strip a given prefix from a string.
	 * @param value The string to strip.
	 * @param prefix The prefix to strip. If the prefix isn't found, the original string is returned.
	 * @return The stripped string.
	 */
	public static function stripPrefix(value:String, prefix:String):String
	{
		if (value.startsWith(prefix))
		{
			return value.substr(prefix.length);
		}
		return value;
	}

	/**
	 * Strip a given suffix from a string.
	 * @param value The string to strip.
	 * @param suffix The suffix to strip. If the suffix isn't found, the original string is returned.
	 * @return The stripped string.
	 */
	public static function stripSuffix(value:String, suffix:String):String
	{
		if (value.endsWith(suffix))
		{
			return value.substr(0, value.length - suffix.length);
		}
		return value;
	}

	/**
	 * Converts a string to lower kebab case. For example, "Hello World" becomes "hello-world".
	 *
	 * @param value The string to convert.
	 * @return The converted string.
	 */
	public static function toLowerKebabCase(value:String):String
	{
		return value.toLowerCase().replace(' ', '-');
	}

	/**
	 * Converts a string to upper kebab case, aka screaming kebab case. For example, "Hello World" becomes "HELLO-WORLD".
	 *
	 * @param value The string to convert.
	 * @return The converted string.
	 */
	public static function toUpperKebabCase(value:String):String
	{
		return value.toUpperCase().replace(' ', '-');
	}

	/**
	 * The regular expression to sanitize strings.
	 */
	static final SANTIZE_REGEX:EReg = ~/[^-a-zA-Z0-9]/g;

	/**
	 * Remove all instances of symbols other than alpha-numeric characters (and dashes)from a string.
	 * @param value The string to sanitize.
	 * @return The sanitized string.
	 */
	public static function sanitize(value:String):String
	{
		return SANTIZE_REGEX.replace(value, '');
	}

	/**
	 * Parses the string data as JSON and returns the resulting object.
	 * This is here so you can use `string.parseJSON()` when `using StringTools`.
	 *
	 * @param value The
	 * @return The parsed object.
	 */
	public static function parseJSON(value:String):Dynamic
	{
		return cast tjson.TJSON.parse(value);
	}
}
