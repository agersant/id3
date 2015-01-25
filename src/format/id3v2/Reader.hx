package format.id3v2;
import format.id3v2.Data.ExtendedHeader;
import format.id3v2.Data.ExtendedHeaderFlags;
import format.id3v2.Data.Footer;
import format.id3v2.Data.Frame;
import format.id3v2.Data.FrameFormatFlags;
import format.id3v2.Data.FrameHeader;
import format.id3v2.Data.FrameHeaderFlags;
import format.id3v2.Data.FrameStatusFlags;
import format.id3v2.Data.ID3v2;
import format.id3v2.Data.Header;
import format.id3v2.Data.HeaderFlags;
import format.id3v2.Data.ImageEncodingRestrictions;
import format.id3v2.Data.ImageSizeRestrictions;
import format.id3v2.Data.ParseError;
import format.id3v2.Data.TagRestrictions;
import format.id3v2.Data.TagSizeRestrictions;
import format.id3v2.Data.TextEncodingRestrictions;
import format.id3v2.Data.TextFieldsSizeRestrictions;
import format.id3v2.Data.UnknownFrame;
import format.id3v2.Data.VersionNumber;
import format.tools.BitsInput;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.Input;

/**
 * ...
 * @author agersant
 */
class Reader
{

	var input : Input;
	var bits : BitsInput;
	var data : ID3v2;
	var bytesRead : Int;
	
	public function new (_input : Input) 
	{
		input = _input;
		bits = new BitsInput(input);
		input.bigEndian = true;
		bytesRead = 0;
		
		data = new ID3v2();
		data.header = parseHeader();
		data.extendedHeader = parseExtendedHeader();
		parseFrames();
		data.footer = parseFooter();
		
	}
	
	function parseHeader() : Header
	{
		var header = new Header();
		parseHeaderFileIdentifier();
		header.versionNumber = parseVersionNumber();
		header.flags = parseHeaderFlags();
		header.tagSize = readSynchsafeInteger(4);
		return header;
	}
	
	function parseFrames() : Void
	{
		data.frames = new List();
		while (true)
		{
			var frame = parseFrame();
			if (frame == null)
				return;
			data.frames.add(frame);
		}
	}
	
	function parseFooter() : Footer
	{
		if (!data.header.flags.footer)
			return null;
		var footer = new Footer();
		parseFooterFileIdentifier();
		footer.versionNumber = parseVersionNumber();
		footer.flags = parseHeaderFlags();
		footer.tagSize = readSynchsafeInteger(4);
		return footer;
	}
	
	function parseHeaderFileIdentifier() : Void
	{
		var fileIdentifier = input.readByte();
		if (fileIdentifier == 0x49)
		{
			fileIdentifier = input.readByte();
			if (fileIdentifier == 0x44)
			{
				fileIdentifier = input.readByte();
				if (fileIdentifier == 0x33)
				{
					return;
				}
			}
		}
		throw ParseError.INVALID_HEADER_FILE_IDENTIFIER;
	}
	
	function parseVersionNumber() : VersionNumber
	{
		var versionNumber = new VersionNumber();
		var majorVersion = input.readByte();
		if (majorVersion != 4)
			throw ParseError.UNSUPPORTED_VERSION;
		versionNumber.majorVersion = majorVersion;
		var revisionNumber = input.readByte();
		versionNumber.revisionNumber = revisionNumber;
		return versionNumber;
	}
	
	function parseHeaderFlags() : HeaderFlags
	{
		var flags = new HeaderFlags();
		bits.reset();
		flags.unsynchronization = bits.readBit();
		flags.extendedHeader = bits.readBit();
		flags.experimental = bits.readBit();
		flags.footer = bits.readBit();
		return flags;
	}
	
	function parseExtendedHeader() : ExtendedHeader
	{
		if (!data.header.flags.extendedHeader)
			return null;
		var extendedHeader = new ExtendedHeader();
		extendedHeader.size = readSynchsafeInteger(4);
		if (extendedHeader.size < 6)
			throw ParseError.INVALID_EXTENDED_HEADER_SIZE;
		extendedHeader.numberOfFlagBytes = input.readByte();
		if (extendedHeader.numberOfFlagBytes != 1)
			throw ParseError.INVALID_EXTENDED_HEADER_NUMBER_OF_FLAG_BYTES;
		extendedHeader.flags = parseExtendedHeaderFlags();
		if (extendedHeader.flags.isUpdate)
			parseExtendedHeaderFlagIsUpdate();
		if (extendedHeader.flags.crcDataPresent)
			extendedHeader.CRCValue = parseExtendedHeaderFlagCRCData();
		if (extendedHeader.flags.tagRestrictions)
			extendedHeader.tagRestrictions = parseExtendedHeaderTagRestrictions();
		bytesRead += extendedHeader.size;
		return extendedHeader;
	}
	
	function parseExtendedHeaderFlags() : ExtendedHeaderFlags
	{
		var flags = new ExtendedHeaderFlags();
		bits.reset();
		bits.readBit();
		flags.isUpdate = bits.readBit();
		flags.crcDataPresent = bits.readBit();
		flags.tagRestrictions = bits.readBit();
		return flags;
	}
	
	function parseExtendedHeaderFlagIsUpdate() : Void
	{
		var size = input.readByte();
		if (size != 0)
			throw ParseError.INVALID_EXTENDED_HEADER_IS_UPDATE_FLAG_SIZE;
	}
	
	function parseExtendedHeaderFlagCRCData() : Int
	{
		var size = input.readByte();
		if (size != 5)
			throw ParseError.INVALID_EXTENDED_HEADER_IS_CRC_FLAG_SIZE;
		return readSynchsafeInteger(5);
	}
	
	function parseExtendedHeaderTagRestrictions() : TagRestrictions
	{
		var tagRestrictions = new TagRestrictions();
		var size = input.readByte();
		if (size != 1)
			throw ParseError.INVALID_EXTENDED_HEADER_TAG_RESTRICTIONS_FLAG_SIZE;
		
		bits.reset();
		var tagSize = 2 * (bits.readBit() ? 1 : 0) + (bits.readBit() ? 1 : 0);
		switch (tagSize)
		{
			case 0x00:
				tagRestrictions.tagSize = TagSizeRestrictions.MAX_128_FRAMES_1_MB;
			case 0x01:
				tagRestrictions.tagSize = TagSizeRestrictions.MAX_64_FRAMES_128_KB;
			case 0x10:
				tagRestrictions.tagSize = TagSizeRestrictions.MAX_32_FRAMES_40_KB;
			case 0x11:
				tagRestrictions.tagSize = TagSizeRestrictions.MAX_32_FRAMES_4_KB;
			default:
				throw ParseError.INVALID_EXTENDED_HEADER_TAG_SIZE_RESTRICTIONS;
		}
		
		var textEncoding = bits.readBit();
		if (textEncoding)
			tagRestrictions.textEncoding = TextEncodingRestrictions.ISO_8859_1_OR_UTF_8;
		else
			tagRestrictions.textEncoding = TextEncodingRestrictions.NO_RESTRICTIONS;
		
		var textFieldsSize = 2 * (bits.readBit() ? 1 : 0) + (bits.readBit() ? 1 : 0);
		switch (textFieldsSize)
		{
			case 0x00:
				tagRestrictions.textFieldsSize = TextFieldsSizeRestrictions.NO_RESTRICTIONS;
			case 0x01:
				tagRestrictions.textFieldsSize = TextFieldsSizeRestrictions.MAX_1024;
			case 0x10:
				tagRestrictions.textFieldsSize = TextFieldsSizeRestrictions.MAX_128;
			case 0x11:
				tagRestrictions.textFieldsSize = TextFieldsSizeRestrictions.MAX_30;
			default:
				throw ParseError.INVALID_EXTENDED_HEADER_TEXT_FIELD_SIZE_RESTRICTIONS;
		}
		
		var imageEncoding = bits.readBit();
		if (imageEncoding)
			tagRestrictions.imageEncoding = ImageEncodingRestrictions.PNG_OR_JPEG;
		else
			tagRestrictions.imageEncoding = ImageEncodingRestrictions.NO_RESTRICTIONS;
		
		var imageSize = 2 * (bits.readBit() ? 1 : 0) + (bits.readBit() ? 1 : 0);
		switch (imageSize)
		{
			case 0x00:
				tagRestrictions.imageSize = ImageSizeRestrictions.NO_RESTRICTIONS;
			case 0x01:
				tagRestrictions.imageSize = ImageSizeRestrictions.MAX_256_BY_256;
			case 0x10:
				tagRestrictions.imageSize = ImageSizeRestrictions.MAX_64_BY_64;
			case 0x11:
				tagRestrictions.imageSize = ImageSizeRestrictions.EXACTLY_64_BY_64;
			default:
				throw ParseError.INVALID_EXTENDED_HEADER_IMAGE_SIZE_RESTRICTIONS;
		}	
		
		return tagRestrictions;
	}
	
	function parseFrame() : Frame
	{
		if (bytesRead >= data.header.tagSize)
			return null;
		var header = parseFrameHeader();
		if (header == null)
			return null;		
		var frameData = readFrameData(header);
		var frame : Frame;
		switch (header.ID)
		{
			default:
				frame = new UnknownFrame(frameData);
		}
		frame.header = header;
		return frame;
	}
	
	function parseFrameHeader() : FrameHeader
	{
		var ID = parseFrameID();
		if (ID == null)
			return null;
		var frameHeader = new FrameHeader();
		frameHeader.ID = ID;
		frameHeader.frameSize = readSynchsafeInteger(4); bytesRead += 4;
		frameHeader.flags = parseFrameHeaderFlags(); bytesRead += 2;
		if (frameHeader.flags.formatFlags.groupingIdentity)
		{
			frameHeader.groupingIdentity = input.readByte();
			bytesRead++;
		}
		if (frameHeader.flags.formatFlags.compression && frameHeader.flags.formatFlags.dataLengthIndicator)
			throw ParseError.MISSING_FRAME_DATA_LENGTH_INDICATOR;
		if (frameHeader.flags.formatFlags.encryption)
		{
			frameHeader.encryptionMethod = input.readByte();
			bytesRead++;
		}
		if (frameHeader.flags.formatFlags.dataLengthIndicator)
		{
			frameHeader.dataLength = readSynchsafeInteger(4);
			bytesRead++;
		}
		return frameHeader;
	}
	
	function parseFrameID() : String
	{
		var regex = new EReg("[A-Z0-9]", "");
		var id = "";
		for (i in 0...4)
		{
			var byte = input.readByte();
			bytesRead++; 
			if (i == 0 && byte == 0) // We hit the padding section of the tag
				return null;
			var char = String.fromCharCode(byte);
			if (!regex.match(char))
				throw ParseError.INVALID_FRAME_ID;
			id += char;
		}
		return id;
	}
	
	function parseFrameHeaderFlags() : FrameHeaderFlags
	{
		var flags = new FrameHeaderFlags();
		flags.statusFlags = parseFrameStatusFlags();
		flags.formatFlags = parseFrameFormatFlags();
		return flags;
	}
	
	function parseFrameStatusFlags() : FrameStatusFlags
	{
		var flags = new FrameStatusFlags();
		bits.reset();
		bits.readBit();
		flags.preserveOnTagAlteration = bits.readBit();
		flags.preserveOnFileAlteration = bits.readBit();
		flags.readOnly = bits.readBit();
		return flags;
	}
	
	function parseFrameFormatFlags() : FrameFormatFlags
	{
		var flags = new FrameFormatFlags();
		bits.reset();
		bits.readBit();
		flags.groupingIdentity = bits.readBit();
		bits.readBit();
		bits.readBit();
		flags.compression = bits.readBit();
		flags.encryption = bits.readBit();
		flags.unsychronization = bits.readBit();
		flags.dataLengthIndicator = bits.readBit();
		return flags;
	}
	
	function parseFooterFileIdentifier() : Void
	{
		var fileIdentifier = input.readByte();
		if (fileIdentifier == 0x33)
		{
			fileIdentifier = input.readByte();
			if (fileIdentifier == 0x44)
			{
				fileIdentifier = input.readByte();
				if (fileIdentifier == 0x49)
				{
					return;
				}
			}
		}
		throw ParseError.INVALID_FOOTER_FILE_IDENTIFIER;
	}
	
	function readFrameData(frameHeader : FrameHeader) : Bytes
	{
		var wipBytes : Bytes;
		if (frameHeader.flags.formatFlags.dataLengthIndicator)
			wipBytes = Bytes.alloc(frameHeader.dataLength);
		else
			wipBytes = Bytes.alloc(frameHeader.frameSize);
		
		var unsynchronize = data.header.flags.unsynchronization || frameHeader.flags.formatFlags.unsychronization;
		var dataLength = 0;
		var prevByte : Int = 0;
		for (i in 0...frameHeader.frameSize)
		{
			var byte = input.readByte();
			if (!unsynchronize || byte != 0 || prevByte != 0xFF)
			{
				wipBytes.set(dataLength, byte);
				dataLength++;
			}
			prevByte = byte;
			bytesRead++;
		}
		
		var outBytes : Bytes;
		if (frameHeader.flags.formatFlags.dataLengthIndicator)
			outBytes = wipBytes;
		else
		{
			outBytes = Bytes.alloc(dataLength);
			outBytes.blit(0, wipBytes, 0, dataLength);
		}
		return outBytes;
	}
	
	function readSynchsafeInteger(numBytes : Int) : Int
	{
		var result = 0;
		var i = numBytes - 1;
		while (i >= 0)
		{
			var byte = input.readByte();
			if ((byte & 0x80) != 0)
			{
				throw INVALID_SYNCHSAFE_INTEGER;
			}
			result += byte << (7 * i);
			i--;
		}
		return result;
	}
	
}