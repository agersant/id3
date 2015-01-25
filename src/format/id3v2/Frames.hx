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
				else
				{
					stringEnd++;
				}
			}
		}
		
		if (encoding == TextEncoding.UTF_16_WITH_BOM || encoding == TextEncoding.UTF_16_BE)
		{
			var bigEndian = true;
			var currentByteIndex = 1;
			if (encoding == TextEncoding.UTF_16_WITH_BOM)
			{
				bigEndian = data.get(currentByteIndex) == 0xFE && data.get(currentByteIndex + 1) == 0xFF;
				currentByteIndex += 2;
			}
			var string = "";
			
			var unicodePoint : UInt;
			while (currentByteIndex < data.length)
			{
				var read = readUTF16Character(bigEndian, data, currentByteIndex);
				var unicodePoint = read.codePoint;
				currentByteIndex += read.bytesRead;
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
	
	static function readUTF16Character(bigEndian : Bool, data : Bytes, pos : Int) : { codePoint : Int, bytesRead : Int }
	{
		var codePoint : Int;
		var currentPos = pos;
		var firstPair = readUTF16BytesPair(bigEndian, data, currentPos);
		currentPos += 2;
		if (firstPair >= 0xD800 && firstPair <= 0xDBFF)
		{
			var secondPair = readUTF16BytesPair(bigEndian, data, currentPos);
			currentPos += 2;
			if (secondPair < 0xDC00 || secondPair > 0xDFFF)
				throw ParseError.BAD_UTF16_ENCODING;
			var topTenBits = firstPair - 0xD800;
			var lowTenBits = secondPair - 0xDC00;
			codePoint = 0x010000 + (topTenBits << 10) + lowTenBits;
		}
		else
		{
			codePoint = firstPair;
		}
		return { codePoint: codePoint, bytesRead: (currentPos - pos) };
	}
	
	static function readUTF16BytesPair(bigEndian : Bool, data : Bytes, pos : Int) : Int
	{
		var firstByte = data.get(pos);
		var secondByte = data.get(pos + 1);
		var msByte : Int;
		var lsByte : Int;
		if (bigEndian)
		{
			msByte = firstByte;
			lsByte = secondByte;
		}
		else
		{
			msByte = secondByte;
			lsByte = firstByte;
		}
		return ((msByte << 8) + lsByte);
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