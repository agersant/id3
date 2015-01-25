package format.id3v2;
import haxe.io.Bytes;

/**
 * @author agersant
 */

class ID3v2
{
	public function new () {};
	public var header : Header;
	public var extendedHeader : ExtendedHeader;
	public var footer : Footer;
	public var frames : List<Frame>;
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

enum TextEncoding
{
	ISO_8859_1;
	UTF_16_WITH_BOM;
	UTF_16_WITHOUT_BOM;
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
	INVALID_FRAME_ID;
	MISSING_FRAME_DATA_LENGTH_INDICATOR;
	INVALID_FOOTER_FILE_IDENTIFIER;
	
	INVALID_FRAME_DATA_TRCK;
}

class HeaderFlags
{
	public function new () {};
	public var unsynchronization : Bool;
	public var extendedHeader : Bool;
	public var experimental : Bool;
	public var footer : Bool;
}