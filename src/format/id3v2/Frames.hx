package format.id3v2;
import format.id3v2.Constants.ID3v1;
import format.id3v2.Data.Frame;
import format.id3v2.Data.ParseError;
import format.id3v2.Data.TextEncoding;
import haxe.io.Bytes;
import unifill.CodePoint;

/**
 * ...
 * @author agersant
 */

class TextInformationFrame extends Frame
{
	var values : Array<String>;
	public function new (data : Bytes)
	{
		super();
		values = new Array();
		var encoding : TextEncoding = TextEncoding.createByIndex(data.get(0));
		var pos = 1;
		while (true)
		{
			var nextValue = readText(encoding, data, pos);
			if (nextValue == null)
				break;
			values.push(nextValue.text);
			pos += nextValue.bytesRead;
		}
	}
}

class FrameTALB extends TextInformationFrame {
	var album : Array<String>;
	public function new (data : Bytes)
	{
		super(data);
		album = values;
	}
}

class FrameTCON extends TextInformationFrame {
	var genre : Array<String>;
	public function new (data : Bytes)
	{
		super(data);
		var regex = ~/^[0-9]+$/;
		for (i in 0...values.length)
		{
			var genreText = values[i];
			if (regex.match(genreText))
			{
				var genreNumber = Std.parseInt(regex.matched(0));
				if (genreNumber < ID3v1.GENRES.length)
					values[i] = ID3v1.GENRES[genreNumber];
			}
		}
		genre = values;
	}
}

class FrameTIT2 extends TextInformationFrame {
	var title : Array<String>;
	public function new (data : Bytes)
	{
		super(data);
		title = values;
	}
}

class FrameTPE1 extends TextInformationFrame {
	var artist : Array<String>;
	public function new (data : Bytes)
	{
		super(data);
		artist = values;
	}
}

class FrameTXXX extends TextInformationFrame {
	var description : String;
	var value : String;
	public function new (data : Bytes)
	{
		super(data);
		description = values[0];
		value = values[1];
	}
}
 
class FrameTRCK extends TextInformationFrame
{

	var trackNumber : Null<Int>;
	var tracksInSet : Null<Int>;
	
	public function new (data : Bytes)
	{
		super(data);
		var text = values[0];
		
		var trackNumberRegex = ~/^[0-9]+/;
		if (trackNumberRegex.match(text))
		{
			trackNumber = Std.parseInt(trackNumberRegex.matched(0));
		}
		else
		{
			trackNumber = null;
		}
		
		var tracksInSetRegex = ~/\/([0-9]+)$/ ;
		if (tracksInSetRegex.match(text))
		{
			tracksInSet = Std.parseInt(tracksInSetRegex.matched(1));
		}
		else
		{
			tracksInSet = null;
		}
	}
	
}