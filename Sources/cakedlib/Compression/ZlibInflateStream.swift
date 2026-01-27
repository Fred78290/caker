import zlib

#if canImport(FoundationEssentials)
	import FoundationEssentials
#else
	import Foundation
#endif

final class ZlibInflateStream: ZlibStream {
	enum ZlibStreamError: Error {
		case decompressedDataOverflow
		case decompressedDataLengthMismatch
	}

	override func setupStream() throws {
		var version = ZLIB_VERSION
		let status = withUnsafeMutablePointer(to: &version) { versionPtr in
			return inflateInit_(streamPtr, versionPtr, .init(MemoryLayout<z_stream>.size))
		}

		guard ZlibError.isSuccess(status) else {
			throw Self.error(streamPtr: streamPtr, status: status)
		}
	}

	override func end() {
		try? self._inflateEnd()
	}

	/// All dynamically allocated data structures for this stream are freed.
	/// This function discards any unprocessed input and does not flush any pending output.
	/// inflateEnd returns Z_OK if success, or Z_STREAM_ERROR if the stream state was inconsistent.
	private func _inflateEnd() throws {
		let streamPtr = self.streamPtr

		let status = inflateEnd(streamPtr)

		guard ZlibError.isSuccess(status) else {
			throw Self.error(streamPtr: streamPtr, status: status)
		}
	}

	private func _inflate(flush: ZlibFlush) throws -> Bool {
		let streamPtr = self.streamPtr

		let flushValue = flush.rawValue

		let status = inflate(streamPtr, flushValue)

		if status == Z_STREAM_END {
			return true
		}

		guard ZlibError.isSuccess(status) else {
			throw Self.error(streamPtr: streamPtr, status: status)
		}

		return false
	}

	func decompressedData(compressedData: Data) throws -> Data {
		let flush = ZlibFlush.noFlush

		let compressedSize = compressedData.count
		var mutableCompressedData = compressedData

		var decompressedData = Data()

		// TODO: What's the "perfect" buffer size?
		let bufferSize: UInt = 1024 * 10 * 10
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: .init(bufferSize))

		defer {
			buffer.deallocate()
		}

		try mutableCompressedData.withUnsafeMutableBytes { compressedDataPtr in
			let compressedDataBytes = compressedDataPtr.baseAddress!.assumingMemoryBound(to: Bytef.self)

			self.totalOut = 0
			self.nextIn = compressedDataBytes
			self.availIn = .init(compressedSize)

			while true {
				if self.availIn <= 0 {
					break
				}

				var isDone = false

				self.nextOut = buffer
				self.availOut = .init(bufferSize)

				// Inflate another chunk.
				isDone = try self._inflate(flush: flush)

				if self.availOut >= 0 {
					let availOut: UInt = .init(self.availOut)
					let actualOut = bufferSize - availOut

					if actualOut > 0 {
						decompressedData.append(buffer, count: .init(actualOut))
					}
				}

				if isDone {
					break
				}
			}
		}

		return decompressedData
	}

	func decompressedData(compressedData: Data, uncompressedSize: UInt) throws -> Data {
		let flush = ZlibFlush.noFlush

		let compressedSize = compressedData.count
		var mutableCompressedData = compressedData

		var decompressedData = Data(count: .init(uncompressedSize))

		try mutableCompressedData.withUnsafeMutableBytes { compressedDataPtr in
			let compressedDataBytes = compressedDataPtr.baseAddress!.assumingMemoryBound(to: Bytef.self)

			self.totalOut = 0
			self.nextIn = compressedDataBytes
			self.availIn = .init(compressedSize)

			try decompressedData.withUnsafeMutableBytes { decompressedDataPtr in
				let decompressedDataBytes = decompressedDataPtr.baseAddress!.assumingMemoryBound(to: Bytef.self)

				while true {
					let doneBytes = self.totalOut
					let remainingBytes = uncompressedSize - doneBytes

					if doneBytes > uncompressedSize {
						throw ServiceError("zlib described a larger decompressed size (\(uncompressedSize)) than the actual data (\(doneBytes))")
					}

					self.nextOut = decompressedDataBytes.advanced(by: .init(doneBytes))
					self.availOut = .init(remainingBytes)

					if remainingBytes <= 0 {
						break
					}

					// Inflate another chunk.
					let isDone = try self._inflate(flush: flush)

					if isDone {
						break
					}
				}

				guard self.totalOut == uncompressedSize else {
					throw ServiceError("zlib did not decompress the expected number of bytes (\(uncompressedSize))")
				}
			}
		}

		return decompressedData
	}
}
