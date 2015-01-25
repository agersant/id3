package format.id3v2;
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
		
		if (encoding == TextEncoding.ISO_8859_1 || encoding == TextEncoding.UTF_8)
		{
			var stringStart = 1;
			var stringEnd = 1;
			while (stringStart < data.length)
			{
				if (stringEnd == data.length || data.get(stringEnd) == 0)
				{
					var value = data.getString(stringStart, stringEnd - stringStart);
					values.push(value);
					stringStart = stringEnd + 1;
					stringEnd = stringStart;
				}
				stringEnd++;
			}
		}
		
		if (encoding == TextEncoding.UTF_16_WITH_BOM || encoding == TextEncoding.UTF_16_WITHOUT_BOM)
		{
			var bigEndian = true;
			bigEndian = data.get(1) == 0xFE && data.get(2) == 0xFF;
			var string = "";
			var currentByteIndex = 3;
			var unicodePoint : UInt;
			// TODO dont read BOM when encoding says no BOM (also, pick the correct endian-ness when that happens)
			// TODO support crappy UTF-16 encoding for characters outside of the BMP
			while (currentByteIndex < data.length)
			{
				var firstByte = data.get(currentByteIndex); currentByteIndex++;
				var secondByte = data.get(currentByteIndex); currentByteIndex++;
				if (bigEndian)
				{
					unicodePoint = (firstByte << 8) + secondByte;
				}
				else
				{
					unicodePoint = (secondByte << 8) + firstByte;
				}
				if (unicodePoint != 0)
				{
					var char = new CodePoint(unicodePoint).toString();
					string += char;
				}
				if (unicodePoint == 0 || currentByteIndex >= data.length)
				{
					values.push(string);
					string = "";
				}
			}
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

	var trackNumber : Int;
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
			throw ParseError.INVALID_FRAME_DATA_TRCK;
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