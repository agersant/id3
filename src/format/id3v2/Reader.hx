package format.id3v2;
import format.id3v2.Data.ExtendedHeader;
import format.id3v2.Data.ExtendedHeaderFlags;
import format.id3v2.Data.Footer;
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
import format.id3v2.Data.VersionNumber;
import format.tools.BitsInput;
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
		if (data.header.flags.extendedHeader)
		{
			data.extendedHeader = parseExtendedHeader();
			bytesRead += data.extendedHeader.size;
		}
		parseFrames();
		parsePadding();
		if (data.header.flags.footer)
			data.footer = parseFooter();
		trace(data);
	}
	
	function parseHeader() : Header
	{
		var header = new Header();
		parseHeaderFileIdentifier();
		header.versionNumber = parseVersionNumber();
		header.flags = parseHeaderFlags();
		header.size = readSynchsafeInteger(4);
		return header;
	}
	
	function parseFrames() : Void
	{
		// TMP
		var size = data.header.size;
		if (data.header.flags.extendedHeader)
			size -= data.extendedHeader.size;
		input.read(size);
		bytesRead += size;
	}
	
	function parsePadding() : Void
	{
		var paddingBytes = data.header.size - bytesRead;
		if (paddingBytes > 0)
		{
			if (data.header.flags.footer)
				throw ParseError.UNEXPECTED_PADDING;
			for (i in 0...paddingBytes)
			{
				if (input.readByte() != 0)
					throw ParseError.INVALID_PADDING_BYTE;
				bytesRead++;
			}
		}
	}
	
	function parseFooter() : Footer
	{
		var footer = new Footer();
		parseFooterFileIdentifier();
		footer.versionNumber = parseVersionNumber();
		footer.flags = parseHeaderFlags();
		footer.size = readSynchsafeInteger(4);
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
	
	function readSynchsafeInteger(numBytes : Int) : Int
	{
		var result = 0;
		var i = numBytes;
		while (i >= 0)
		{
			result += input.readByte() << (7 * i);
			i--;
		}
		return result;
	}
	
}