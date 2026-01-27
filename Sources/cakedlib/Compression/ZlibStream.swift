import ZLib

#if canImport(FoundationEssentials)
	import FoundationEssentials
#else
	import Foundation
#endif

enum ZlibError: Error {
	case unknown(status: Int32, message: String?)

	case streamEnd(message: String?)
	case needDict(message: String?)
	case errNo(message: String?)
	case bufferError(message: String?)
	case streamError(message: String?)
	case memoryError(message: String?)
	case dataError(message: String?)
	case versionError(message: String?)
}

enum ZlibFlush: Int32 {
	case noFlush = 0  // Z_NO_FLUSH
	case partialFlush = 1  // Z_PARTIAL_FLUSH
	case syncFlush = 2  // Z_SYNC_FLUSH
	case fullFlush = 3  // Z_FULL_FLUSH
	case finish = 4  // Z_FINISH
	case block = 5  // Z_BLOCK
	case trees = 6  // Z_TREES
}

internal class ZlibStream {
	var streamPtr: UnsafeMutablePointer<z_stream>

	internal init() throws {
		let streamPtr = UnsafeMutablePointer<z_stream>.allocate(capacity: 1)

		memset(streamPtr, 0, MemoryLayout<z_stream>.size)

		self.streamPtr = streamPtr

		try self.setupStream()
	}

	open func setupStream() throws {

	}

	open func end() {
		self.streamPtr.deallocate()
	}

	deinit {
		self.end()
		self.streamPtr.deallocate()
	}

	static func error(streamPtr: UnsafePointer<z_stream>, status: Int32) -> ZlibError {
		let errMsg = Self.errorMessage(streamPtr: streamPtr)
		let err = ZlibError.withStatus(status, errorMessage: errMsg)

		return err
	}

	static func errorMessage(streamPtr: UnsafePointer<z_stream>) -> String? {
		guard let msg = streamPtr.pointee.msg else {
			return nil
		}

		let errorMsg = String(cString: msg)

		return errorMsg
	}

	/// remaining free space at nextOut
	var availOut: UInt32 {
		get {
			streamPtr.pointee.avail_out
		}
		set {
			streamPtr.pointee.avail_out = newValue
		}
	}

	/// total number of bytes output so far
	var totalOut: UInt {
		get {
			.init(streamPtr.pointee.total_out)
		}
		set {
			streamPtr.pointee.total_out = .init(newValue)
		}
	}

	/// number of bytes available at nextIn
	var availIn: UInt32 {
		get {
			streamPtr.pointee.avail_in
		}
		set {
			streamPtr.pointee.avail_in = newValue
		}
	}

	/// total number of input bytes read so far
	var totalIn: UInt {
		get {
			.init(streamPtr.pointee.total_in)
		}
		set {
			streamPtr.pointee.total_in = .init(newValue)
		}
	}

	/// next input byte
	var nextIn: UnsafeMutablePointer<UInt8>? {
		get {
			streamPtr.pointee.next_in
		}
		set {
			streamPtr.pointee.next_in = newValue
		}
	}

	/// next output byte will go here
	var nextOut: UnsafeMutablePointer<UInt8>? {
		get {
			streamPtr.pointee.next_out
		}
		set {
			streamPtr.pointee.next_out = newValue
		}
	}

	/// best guess about the data type: binary or text for deflate, or the decoding state for inflate
	var dataType: Int32 {
		get {
			streamPtr.pointee.data_type
		}
		set {
			streamPtr.pointee.data_type = newValue
		}
	}

	/// last error message, nil if no error
	var errorMessage: String? {
		Self.errorMessage(streamPtr: streamPtr)
	}

	/// Adler-32 or CRC-32 value of the uncompressed data
	var adler: UInt {
		get {
			.init(streamPtr.pointee.adler)
		}
		set {
			streamPtr.pointee.adler = .init(newValue)
		}
	}
}

extension ZlibError {
	static func isSuccess(_ status: Int32) -> Bool {
		status == Z_OK
	}

	static func withStatus(_ status: Int32, errorMessage: String?) -> Self {
		switch status {
		case Z_STREAM_END:
			.streamEnd(message: errorMessage)
		case Z_NEED_DICT:
			.needDict(message: errorMessage)
		case Z_ERRNO:
			.errNo(message: errorMessage)
		case Z_STREAM_ERROR:
			.streamError(message: errorMessage)
		case Z_DATA_ERROR:
			.dataError(message: errorMessage)
		case Z_MEM_ERROR:
			.memoryError(message: errorMessage)
		case Z_BUF_ERROR:
			.bufferError(message: errorMessage)
		case Z_VERSION_ERROR:
			.versionError(message: errorMessage)
		default:
			.unknown(status: status, message: errorMessage)
		}
	}
}
