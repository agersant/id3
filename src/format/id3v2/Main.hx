package format.id3v2;

import format.id3v2.Reader;
import haxe.io.Path;
import haxe.macro.Format;
import sys.FileSystem;
import sys.io.File;

/**
 * ...
 * @author agersant
 */

class Main 
{
	
	static function main() 
	{
		for (fileName in FileSystem.readDirectory(Sys.getCwd()))
		{
			var path = new Path(fileName);
			if (path.ext != "mp3")
				continue;
			trace(path);
			var file = File.read(path.toString(), true);
			var id3v2 = new Reader(file);
		}
		
	}
	
}