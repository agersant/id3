package format.id3v2;

import format.id3v2.Reader;
import haxe.macro.Format;
import neko.Lib;
import sys.io.File;

/**
 * ...
 * @author agersant
 */

class Main 
{
	
	static function main() 
	{
		var file = File.read("test.mp3", true);
		var id3v2 = new Reader(file);
	}
	
}