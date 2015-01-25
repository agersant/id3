package format.id3v2;

import format.id3v2.Data.ParseError;
import format.id3v2.Reader;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;

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
			var file : FileInput;
			var path = new Path(fileName);
			
			try {
				if (FileSystem.isDirectory(path.toString()))
					continue;
			}
			catch (d : Dynamic)
			{
				if (d == "std@sys_file_type")
				{
					Sys.println("Cannot open: " + fileName);
					continue;
				}
				throw d;
			}
			
			if (path.ext != "mp3")
				continue;
			
			file = File.read(path.toString(), true);
			try
			{
				trace("Analyzing " + fileName);
				var id3v2 = new Reader(file);
			}
			catch (e : ParseError)
			{
				if (e == ParseError.INVALID_HEADER_FILE_IDENTIFIER)
				{
					Sys.println("No ID3v2 tag: " + fileName);
					continue;
				}
				throw e;
			}
			file.close();
		}
		
	}
	
}