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
	override func setupStream() throws {
		var version = ZLIB_VERSION
		let status = withUnsafeMutablePointer(to: &version) { versionPtr in
			return zlib.deflateInit2_(streamPtr, ZlibCompressionLevel.defaultCompression.rawValue, Z_DEFLATED, MAX_WBITS, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, versionPtr, Int32(MemoryLayout<z_stream>.size))
		}

		guard status == Z_OK else {
			throw ZlibDeflateStream.error(streamPtr: streamPtr, status: status)
		}
	}

	override func end() {
		try? deflateEnd()
	}

	func deflateEnd() throws {
		let status = zlib.deflateEnd(streamPtr)

		guard status == Z_OK else {
			throw ZlibDeflateStream.error(streamPtr: streamPtr, status: status)
		}
	}

	func deflate(flush: ZlibFlush) throws -> Bool {
		let status = zlib.deflate(streamPtr, flush.rawValue)

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
		var flush = flush
		var mutableData = data
		let expectedCompressedSize: UInt = UInt(length + ((length + 99) / 100) + 12)
		var output = Data(count: .init(expectedCompressedSize))

		if offset + length > data.count {
			throw ZlibError.dataError(message: "Out of bounds")
		}

		let written = try mutableData.withUnsafeMutableBytes { inputPtr in
			let inputBytes = inputPtr.baseAddress!.assumingMemoryBound(to: Bytef.self).advanced(by: offset)

			return try output.withUnsafeMutableBytes { outPtr in
				let outBytes = outPtr.baseAddress!.assumingMemoryBound(to: Bytef.self)

				self.totalOut = 0
				self.totalIn = 0
				self.nextIn = inputBytes
				self.availIn = .init(length)
				self.availOut = 0
				self.dataType = Z_BINARY

				while true {
					let doneBytes = self.totalOut
					let remaining = expectedCompressedSize - doneBytes

					if doneBytes > expectedCompressedSize {
						throw ZlibError.streamError(message: "ZLib produced more compressed bytes (\(doneBytes)) than expected (\(expectedCompressedSize))")
					}

					self.nextOut = outBytes.advanced(by: .init(doneBytes))
					self.availOut = .init(remaining)

					if remaining == 0 {
						break
					}

					if try self.deflate(flush: flush) == false {
						if self.availIn == 0 {
							break
						}
						flush = .finish
					} else {
						break
					}
				}

				return self.totalOut
			}
		}

		// In compression, exact size match isn't guaranteed, so we trim to totalOut
		output.removeSubrange(Int(written)..<output.count)

		return output
	}
}
