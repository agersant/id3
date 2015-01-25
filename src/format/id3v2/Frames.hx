package format.id3v2;
import format.id3v2.Data.Frame;
import format.id3v2.Data.ParseError;
import haxe.io.Bytes;

/**
 * ...
 * @author agersant
 */

class TextBasedFrame extends Frame
{
	var text : String;
	public function new (data : Bytes)
	{
		super();
		var encoding : Int = data.get(0);
		if (encoding == 0 || encoding == 3)
			// TODO support multi values!
			text = data.getString(1, data.length - 2); // -2 for encoding byte and null termination
		else
			throw ParseError.UNSUPPORTED_TEXT_ENCODING;
	}
}

class FrameTALB extends TextBasedFrame
{
	var albumName : String;
	public function new (data : Bytes)
	{
		super(data);
		albumName = text;
	}
}

class FrameTIT2 extends TextBasedFrame
{
	var title : String;
	public function new (data : Bytes)
	{
		super(data);
		title = text;
	}
}

class FrameTPE1 extends TextBasedFrame
{
	var leadArtist : String;
	public function new (data : Bytes)
	{
		super(data);
		leadArtist = text;
	}
}
 
class FrameTRCK extends TextBasedFrame
{

	var trackNumber : Int;
	var tracksInSet : Null<Int>;
	
	public function new (data : Bytes)
	{
		super(data);
		
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