package format.id3v2;
import format.id3v2.Constants.ID3v1;
import format.id3v2.Data.Frame;
import format.id3v2.Data.ParseError;
import format.id3v2.Data.TextEncoding;
import format.id3v2.Data.TrackPosition;
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
	public function getAlbumName() : String
	{
		return album[0];
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
	public function getGenres() : Array<String>
	{
		return genre.copy();
	}
}

class FrameTDRC extends TimestampFrame {
	var dateRecorded : Timestamp;
	public function new (data : Bytes)
	{
		super(data);
		dateRecorded = timestamp;
	}
	public function getYear() : Null<Int>
	{
		return dateRecorded.year;
	}
}

class FrameTIT2 extends TextInformationFrame {
	var title : Array<String>;
	public function new (data : Bytes)
	{
		super(data);
		title = values;
	}
	public function getTrackTitle() : String {
		return title[0];
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
	public function getDescription() : String
	{
		return description;
	}
	public function getValue() : String
	{
		return value;
	}
}
 
class FrameTRCK extends TextInformationFrame
{
	static var trackNumberRegex = ~/^[0-9]+/;
	var tracksInSetRegex = ~/^[0-9]+\/([0-9]+)$/;
	var trackPosition : Array<TrackPosition>;
	public function new (data : Bytes)
	{
		super(data);
		trackPosition = new Array();
		for (value in values)
		{
			var newPosition = new TrackPosition();
			if (trackNumberRegex.match(value))
				newPosition.trackNumber = Std.parseInt(trackNumberRegex.matched(0));
			if (tracksInSetRegex.match(value))
				newPosition.tracksInSet = Std.parseInt(tracksInSetRegex.matched(1));
			if (newPosition.trackNumber != null || newPosition.tracksInSet != null)
				trackPosition.push(newPosition);
		}
	}
	public function getTrackNumber() : Null<Int>
	{
		if (trackPosition.length > 0)
			return trackPosition[0].trackNumber;
		return null;
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
	public function getYear() : Null<Int>
	{
		return yearRecorded[0];
	}
}