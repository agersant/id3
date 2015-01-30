package format.id3v2;
import format.id3v2.Frames.FrameTALB;
import format.id3v2.Frames.FrameTCON;
import format.id3v2.Frames.FrameTIT2;
import format.id3v2.Frames.FrameTRCK;
import format.id3v2.Frames.FrameTXXX;
import haxe.io.Bytes;
import unifill.CodePoint;

/**
 * @author agersant
 */

class ID3v2
{
	public function new () {
		frames = new List();
		framesTXXX = new List();
	};
	public var header : Header;
	public var extendedHeader : ExtendedHeader;
	public var footer : Footer;
	public var frames : List<Frame>;
	public var frameTALB : FrameTALB;
	public var frameTCON : FrameTCON;
	public var frameTIT2 : FrameTIT2;
	public var frameTRCK : FrameTRCK;
	public var framesTXXX : List<FrameTXXX>;
}

class VersionNumber
{
	public function new () {};
	public var majorVersion : Int;
	public var revisionNumber : Int;
}

class Header
{
	public function new () {};
	public var versionNumber : VersionNumber;
	public var flags : HeaderFlags;
	public var tagSize : Int;
}

class Frame
{
	public function new () {};
	public var header : FrameHeader;
	function readText(encoding : TextEncoding, data : Bytes, pos : Int) : { text: String, bytesRead: Int }
	{
		if (pos >= data.length)
			return null;
			
		if (encoding == TextEncoding.ISO_8859_1 || encoding == TextEncoding.UTF_8)
		{
			var stringEnd = pos;
			while (stringEnd <= data.length)
			{
				if (stringEnd == data.length || data.get(stringEnd) == 0)
				{
					var string = data.getString(pos, stringEnd - pos);
					return { text: string, bytesRead: 1 + stringEnd - pos };
				}
				else
				{
					stringEnd++;
				}
			}
		}
		
		if (encoding == TextEncoding.UTF_16_WITH_BOM || encoding == TextEncoding.UTF_16_BE)
		{
			var unicodePoint : UInt;
			var bigEndian = true;
			var currentByteIndex = pos;
			var string : String = "";
			if (encoding == TextEncoding.UTF_16_WITH_BOM)
			{
				bigEndian = data.get(currentByteIndex) == 0xFE && data.get(currentByteIndex + 1) == 0xFF;
				currentByteIndex += 2;
			}
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
					return { text: string, bytesRead: currentByteIndex - pos };
				}
			}
		}
		
		return null;
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

class UnknownFrame extends Frame
{
	public function new(_data) {
		super();
		data = _data;
	}
	var data : Bytes;
}

typedef Footer = Header;

class ExtendedHeader
{
	public function new () {};
	public var size : Int;
	public var numberOfFlagBytes : Int;
	public var flags : ExtendedHeaderFlags;
	public var CRCValue : Int;
	public var tagRestrictions : TagRestrictions;
}

class ExtendedHeaderFlags
{
	public function new () {};
	public var isUpdate : Bool;
	public var crcDataPresent : Bool;
	public var tagRestrictions : Bool;
}

class FrameHeader
{
	public function new () { };
	public function countExtraBytes() : Int
	{
		var extraBytes = 0;
		if (this.flags.formatFlags.groupingIdentity)
			extraBytes++;
		if (this.flags.formatFlags.encryption)
			extraBytes++;
		if (this.flags.formatFlags.dataLengthIndicator)
			extraBytes += 4;
		return extraBytes;
	}
	public var ID : String;
	public var frameSize : Int;
	public var flags : FrameHeaderFlags;
	public var groupingIdentity : Int;
	public var encryptionMethod : Int;
	public var dataLength : Null<Int>;
}

class FrameHeaderFlags
{
	public function new () { };
	public var statusFlags : FrameStatusFlags;
	public var formatFlags : FrameFormatFlags;
	
}

class FrameStatusFlags
{
	public function new () { };
	public var preserveOnTagAlteration : Bool;
	public var preserveOnFileAlteration : Bool;
	public var readOnly : Bool;
}

class FrameFormatFlags
{
	public function new () { };
	public var groupingIdentity : Bool;
	public var compression : Bool;
	public var encryption : Bool;
	public var unsychronization : Bool;
	public var dataLengthIndicator : Bool;
}

class TagRestrictions
{
	public function new () { };
	public var tagSize: TagSizeRestrictions;
	public var textEncoding: TextEncodingRestrictions;
	public var textFieldsSize: TextFieldsSizeRestrictions;
	public var imageEncoding: ImageEncodingRestrictions;
	public var imageSize: ImageSizeRestrictions;
}

class TrackPosition
{
	public function new () { };
	public var trackNumber : Null<Int>;
	public var tracksInSet : Null<Int>;
}

enum TextEncoding
{
	ISO_8859_1;
	UTF_16_WITH_BOM;
	UTF_16_BE;
	UTF_8;
}

enum TagSizeRestrictions {
	MAX_128_FRAMES_1_MB;
	MAX_64_FRAMES_128_KB;
	MAX_32_FRAMES_40_KB;
	MAX_32_FRAMES_4_KB;
}

enum TextEncodingRestrictions {
	NO_RESTRICTIONS;
	ISO_8859_1_OR_UTF_8;
}

enum TextFieldsSizeRestrictions {
	NO_RESTRICTIONS;
	MAX_1024;
	MAX_128;
	MAX_30;
}

enum ImageEncodingRestrictions {
	NO_RESTRICTIONS;
	PNG_OR_JPEG;
}

enum ImageSizeRestrictions {
	NO_RESTRICTIONS;
	MAX_256_BY_256;
	MAX_64_BY_64;
	EXACTLY_64_BY_64;
}

enum ParseError 
{
	INVALID_HEADER_FILE_IDENTIFIER;
	INVALID_SYNCHSAFE_INTEGER;
	UNSYNCHRONIZATION_ERROR;
	UNSUPPORTED_VERSION;
	INVALID_EXTENDED_HEADER_SIZE;
	INVALID_EXTENDED_HEADER_NUMBER_OF_FLAG_BYTES;
	INVALID_EXTENDED_HEADER_IS_UPDATE_FLAG_SIZE;
	INVALID_EXTENDED_HEADER_IS_CRC_FLAG_SIZE;
	INVALID_EXTENDED_HEADER_TAG_RESTRICTIONS_FLAG_SIZE;
	INVALID_EXTENDED_HEADER_TAG_SIZE_RESTRICTIONS;
	INVALID_EXTENDED_HEADER_TEXT_FIELD_SIZE_RESTRICTIONS;
	INVALID_EXTENDED_HEADER_IMAGE_SIZE_RESTRICTIONS;
	MISSING_FRAME_DATA_LENGTH_INDICATOR;
	INVALID_FOOTER_FILE_IDENTIFIER;
	BAD_UTF16_ENCODING;
}

class HeaderFlags
{
	public function new () {};
	public var unsynchronization : Bool;
	public var extendedHeader : Bool;
	public var experimental : Bool;
	public var footer : Bool;
}