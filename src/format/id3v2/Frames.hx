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

class Timestamp
{
	public function new () {}
	public var year : Null<Int>;
	public var month : Null<Int>;
	public var day : Null<Int>;
	public var hours : Null<Int>;
	public var minutes : Null<Int>;
	public var seconds : Null<Int>;
}

class TimestampFrame extends Frame
{
	var timestamp : Timestamp;
	static var yearRegex 	= ~/^([0-9]{4})/;
	static var monthRegex 	= ~/^[0-9]{4}-([0-9]{2})/;
	static var dayRegex 	= ~/^[0-9]{4}-[0-9]{2}-([0-9]{2})/;
	static var hoursRegex 	= ~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T([0-9]{2})/;
	static var minutesRegex = ~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:([0-9]{2})/;
	static var secondsRegex = ~/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:([0-9]{2})/;
	public function new (data : Bytes)
	{
		super();
		timestamp = new Timestamp();
		var encoding : TextEncoding = TextEncoding.createByIndex(data.get(0));
		var read = readText(encoding, data, 1);
		if (read == null)
			return;
		if (yearRegex.match(read.text))
		{
			timestamp.year = Std.parseInt(yearRegex.matched(1));
			if (monthRegex.match(read.text))
			{
				timestamp.month = Std.parseInt(monthRegex.matched(1));
				if (dayRegex.match(read.text))
				{
					timestamp.day = Std.parseInt(dayRegex.matched(1));
					if (hoursRegex.match(read.text))
					{
						timestamp.hours = Std.parseInt(hoursRegex.matched(1));
						if (minutesRegex.match(read.text))
						{
							timestamp.minutes = Std.parseInt(minutesRegex.matched(1));
							if (secondsRegex.match(read.text))
							{
								timestamp.seconds = Std.parseInt(secondsRegex.matched(1));
							}
						}
					}
				}
			}
		}
	}
}
 
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

class FrameTDRC extends TimestampFrame {
	var dateRecorded : Timestamp;
	public function new (data : Bytes)
	{
		super(data);
		dateRecorded = timestamp;
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

class FrameTYER extends TextInformationFrame {
	var yearRecorded : Array<Int>;
	static var yearRegex = ~/^[0-9]+$/;
	public function new (data : Bytes)
	{
		super(data);
		yearRecorded = new Array();
		for (value in values)
		{
			if (yearRegex.match(value))
				yearRecorded.push(Std.parseInt(value));
		}
	}
}