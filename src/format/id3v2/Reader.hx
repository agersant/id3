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
import format.id3v2.Frames.FrameTALB;
import format.id3v2.Frames.FrameTCON;
import format.id3v2.Frames.FrameTDRC;
import format.id3v2.Frames.FrameTIT2;
import format.id3v2.Frames.FrameTPE1;
import format.id3v2.Frames.FrameTRCK;
import format.id3v2.Frames.FrameTXXX;
import format.id3v2.Frames.FrameTYER;
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
		if (data.header.versionNumber.majorVersion > 3)
			data.footer = parseFooter();
	}
	
	
	
	// Data extraction
	
	public function getTrackTitle() : String
	{
		if (data.frameTIT2 != null)
			return data.frameTIT2.getTrackTitle();
		return null;
	}
	
	public function getTrackNumber() : Null<Int>
	{
		if (data.frameTRCK != null)
			return data.frameTRCK.getTrackNumber();
		return null;
	}
	
	public function getAlbumName() : String
	{
		if (data.frameTALB != null)
			return data.frameTALB.getAlbumName();
		return null;
	}
	
	public function getYear() : Null<Int>
	{
		var year : Null<Int> = null;
		if (data.frameTYER != null)
			year = data.frameTYER.getYear();
		if (year == null)
			if (data.frameTDRC != null)
				year = data.frameTDRC.getYear();
		return year;
	}
	
	public function getGenres() : Array<String>
	{
		if (data.frameTCON != null)
			return data.frameTCON.getGenres();
		return new Array();
	}
	
	public function getCustomTextInformation(description : String) : String
	{
		for (frame in data.framesTXXX)
		{
			if (frame.getDescription().toLowerCase() != description.toLowerCase())
				continue;
			return frame.getValue();
		}
		return null;
	}
	
	
	
	// Parse all
	
	function parseHeader() : Header
	{
		var header = new Header();
		parseHeaderFileIdentifier();
		header.versionNumber = parseVersionNumber();
		header.flags = parseHeaderFlags(header.versionNumber);
		header.tagSize = readSynchsafeInteger(4);
		return header;
	}
	
	function parseFrames() : Void
	{
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
		footer.flags = parseHeaderFlags(footer.versionNumber);
		footer.tagSize = readSynchsafeInteger(4);
		return footer;
	}
	
	
	
	// Parse header
	
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
		if (majorVersion < 3 || majorVersion > 4)
			throw ParseError.UNSUPPORTED_VERSION;
		versionNumber.majorVersion = majorVersion;
		var revisionNumber = input.readByte();
		versionNumber.revisionNumber = revisionNumber;
		return versionNumber;
	}
	
	function parseHeaderFlags(versionNumber : VersionNumber) : HeaderFlags
	{
		var flags = new HeaderFlags();
		bits.reset();
		flags.unsynchronization = bits.readBit();
		flags.extendedHeader = bits.readBit();
		flags.experimental = bits.readBit();
		if (versionNumber.majorVersion > 3)
			flags.footer = bits.readBit();
		else
			flags.footer = false;
		return flags;
	}
	
	
	
	
	// Parse extended header
	
	function parseExtendedHeader() : ExtendedHeader
	{
		if (!data.header.flags.extendedHeader)
			return null;
			
		var extendedHeader = new ExtendedHeader();
		if (data.header.versionNumber.majorVersion == 3)
		{
			extendedHeader.size = 4 + input.readInt32();
			if (extendedHeader.size != 10 && extendedHeader.size != 14)
				throw ParseError.INVALID_EXTENDED_HEADER_SIZE;
		}
		else
		{
			extendedHeader.size = readSynchsafeInteger(4);
			if (extendedHeader.size < 6)
				throw ParseError.INVALID_EXTENDED_HEADER_SIZE;
		}
		
		if (data.header.versionNumber.majorVersion > 3)
		{
			extendedHeader.numberOfFlagBytes = input.readByte();
			if (extendedHeader.numberOfFlagBytes != 1)
				throw ParseError.INVALID_EXTENDED_HEADER_NUMBER_OF_FLAG_BYTES;
		}
		
		extendedHeader.flags = parseExtendedHeaderFlags();
		
		if (data.header.versionNumber.majorVersion == 3)
		{
			var padding = readUnsynchronizedData(4);
		}
		
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
		if (data.header.versionNumber.majorVersion == 3)
		{
			flags.isUpdate = false;
			flags.tagRestrictions = false;
			bits.reset();
			flags.crcDataPresent = bits.readBit();
			input.readByte();
		}
		else
		{
			bits.reset();
			bits.readBit();
			flags.isUpdate = bits.readBit();
			flags.crcDataPresent = bits.readBit();
			flags.tagRestrictions = bits.readBit();
		}
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
	
	
	
	// Parse frame
	
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
			case "TALB":
				var frameTALB = new FrameTALB(frameData);
				if (data.frameTALB == null)
					data.frameTALB = frameTALB;
				frame = frameTALB;
			case "TCON":
				var frameTCON = new FrameTCON(frameData);
				if (data.frameTCON == null)
					data.frameTCON = frameTCON;
				frame = frameTCON;
			case "TDRC":
				var frameTDRC = new FrameTDRC(frameData);
				if (data.frameTDRC == null)
					data.frameTDRC = frameTDRC;
				frame = frameTDRC;
			case "TIT2":
				var frameTIT2 = new FrameTIT2(frameData);
				if (data.frameTIT2 == null)
					data.frameTIT2 = frameTIT2;
				frame = frameTIT2;
			case "TPE1":
				var frameTPE1 = new FrameTPE1(frameData);
				frame = frameTPE1;
			case "TRCK":
				var frameTRCK = new FrameTRCK(frameData);
				if (data.frameTRCK == null)
					data.frameTRCK = frameTRCK;
				frame = frameTRCK;
			case "TXXX":
				var frameTXXX = new FrameTXXX(frameData);
				data.framesTXXX.push( frameTXXX );
				frame = frameTXXX;
			case "TYER":
				var frameTYER = new FrameTYER(frameData);
				if (data.frameTYER == null)
					data.frameTYER = frameTYER;
				frame = frameTYER;
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
		if (data.header.versionNumber.majorVersion == 3)
		{
			frameHeader.frameSize = input.readInt32();
			bytesRead += 4;
		}
		else
		{
			frameHeader.frameSize = readSynchsafeInteger(4);
			bytesRead += 4;
		}		
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
		else
		{
			frameHeader.dataLength = null;
		}
		return frameHeader;
	}
	
	function parseFrameID() : String
	{
		var id = "";
		for (i in 0...4)
		{
			var byte = input.readByte();
			bytesRead++; 
			if (i == 0 && byte == 0) // We hit the padding section of the tag
				return null;
			var char = String.fromCharCode(byte);
			id += char;
		}
		var regex = ~/^[A-Z0-9]{4}$/;
		if (!regex.match(id))
			Sys.println('Invalid frame ID: $id');
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
		if (data.header.versionNumber.majorVersion > 3)
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
		if (data.header.versionNumber.majorVersion == 3)
		{
			flags.compression = bits.readBit();
			flags.encryption = bits.readBit();
			flags.groupingIdentity = bits.readBit();
		}
		else
		{
			bits.readBit();
			flags.groupingIdentity = bits.readBit();
			bits.readBit();
			bits.readBit();
			flags.compression = bits.readBit();
			flags.encryption = bits.readBit();
			flags.unsychronization = bits.readBit();
			flags.dataLengthIndicator = bits.readBit();
		}
		return flags;
	}
	
	
	
	// Parse footer
	
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
	
	
	
	// Parse utils
	
	function readFrameData(frameHeader : FrameHeader) : Bytes
	{
		var realFrameSize = frameHeader.frameSize - frameHeader.countExtraBytes();
		var unsynchronization = data.header.flags.unsynchronization;
		if (data.header.versionNumber.majorVersion > 3)
			unsynchronization = unsynchronization || frameHeader.flags.formatFlags.unsychronization;
		if (unsynchronization)
			return readUnsynchronizedData(realFrameSize);
		else
		{
			var bytes = Bytes.alloc(realFrameSize);
			input.readBytes(bytes, 0, realFrameSize);
			bytesRead += realFrameSize;
			return bytes;
		}
	}
	
	function readSynchsafeInteger(numBytes : Int) : Int
	{
		var badEncoding = false;
		var bytes : Array<Int> = new Array();
		for (i in 0...numBytes)
		{
			bytes.unshift(input.readByte());
			if ((bytes[i] & 0x80) != 0)
			{
				badEncoding = true;
				break;
			}
		}
		
		var result = 0;
		for (i in 0...numBytes)
		{
			var byte = bytes[i];
			if (badEncoding)
			{
				// For crappy software that doesn't respect the standard
				result += byte << (8 * i);
			}
			else {
				result += byte << (7 * i);
			}
		}
		return result;
	}
	
	function readUnsynchronizedData(inputLength : Int) : Bytes
	{
		var wipBytes : Bytes;
		wipBytes = Bytes.alloc(inputLength);
		
		var measuredDataLength = 0;
		var prevByte : Int = 0;
		var pendingZero = false;
		for (i in 0...inputLength)
		{
			var byte = input.readByte();
			if (pendingZero)
			{
				if ((byte & 0xE0) != 0xE0)
				{
					wipBytes.set(measuredDataLength, 0);
					measuredDataLength++;
				}
				pendingZero = false;
			}
			if (byte != 0 || prevByte != 0xFF || i == (inputLength - 1))
			{
				wipBytes.set(measuredDataLength, byte);
				measuredDataLength++;
			}
			else
			{
				pendingZero = true;
			}
			prevByte = byte;
			bytesRead++;
		}
		
		var outBytes : Bytes;
		outBytes = Bytes.alloc(measuredDataLength);
		outBytes.blit(0, wipBytes, 0, measuredDataLength);
		return outBytes;
	}
	
}