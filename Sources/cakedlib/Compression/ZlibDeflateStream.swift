import zlib

#if canImport(Darwin)
	import Darwin
#elseif canImport(Glibc)
	import Glibc
#endif

#if canImport(Foundation)
	import Foundation
#endif

enum ZlibCompressionLevel: Int32 {
	case noCompression = 0
	case bestSpeed = 1
	case bestCompression = 9
	case defaultCompression = -1
}

final class ZlibDeflateStream: ZlibStream {
	var encodedBuffer: UnsafeMutableBufferPointer<UInt8>! = nil
	var currentCapacity: Int = 0

	deinit {
		if let buffer = encodedBuffer {
			buffer.deallocate()
			encodedBuffer = nil
		}
	}

	override func setupStream() throws {
		var version = ZLIB_VERSION
		let status = withUnsafeMutablePointer(to: &version) { versionPtr in
			return deflateInit2_(streamPtr, ZlibCompressionLevel.defaultCompression.rawValue, Z_DEFLATED, MAX_WBITS, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, versionPtr, Int32(MemoryLayout<z_stream>.size))
		}

		guard status == Z_OK else {
			throw ZlibDeflateStream.error(streamPtr: streamPtr, status: status)
		}
	}

	override func end() {
		try? _deflateEnd()
	}

	private func _deflateEnd() throws {
		let status = deflateEnd(streamPtr)

		guard status == Z_OK else {
			throw ZlibDeflateStream.error(streamPtr: streamPtr, status: status)
		}
	}

	private func _deflate(flush: ZlibFlush) throws -> Bool {
		let status = deflate(streamPtr, flush.rawValue)

		if status == Z_BUF_ERROR {
			if flush == .syncFlush || flush == .fullFlush {
				return true
			} else {
				return false
			}
		}

		if status == Z_STREAM_END {
			return true
		}

		guard status == Z_OK else {
			throw ZlibDeflateStream.error(streamPtr: streamPtr, status: status)
		}

		return false
	}

	func compressedData(data: Data, offset: Int, length: Int, flush: ZlibFlush = .finish) throws -> Data {
		var data = data
		let expectedCompressedSize: UInt = UInt(length + ((length + 99) / 100) + 12)
		let neededCapacity = Int(expectedCompressedSize)

		if offset + length > data.count {
			throw ZlibError.dataError(message: "Out of bounds")
		}

		if self.encodedBuffer == nil {
			self.encodedBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: neededCapacity)
			self.currentCapacity = neededCapacity
		} else if self.currentCapacity < neededCapacity {
			// Grow the buffer to the needed capacity
			let oldBuffer = self.encodedBuffer
			let newBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: neededCapacity)
			
			self.currentCapacity = neededCapacity
			self.encodedBuffer = newBuffer
			_ = newBuffer.initialize(from: oldBuffer!)
			oldBuffer!.deallocate()
		}

		return try data.withUnsafeMutableBytes { inputPtr in
			guard let outBase = self.encodedBuffer.baseAddress else {
				throw ZlibError.dataError(message: "Failed to access output buffer")
			}

			let previousOut = self.totalOut

			self.nextIn =  inputPtr.baseAddress!.assumingMemoryBound(to: UInt8.self).advanced(by: offset)
			self.availIn = .init(length)
			self.nextOut = outBase
			self.availOut = .init(self.currentCapacity)
			self.dataType = Z_BINARY

			let status = deflate(streamPtr, flush.rawValue)

			guard status == Z_OK || status == Z_STREAM_END else {
				throw ZlibDeflateStream.error(streamPtr: streamPtr, status: status)
			}

			return Data(bytes: outBase, count: Int(self.totalOut - previousOut))
		}
	}
}

