//
//  LZXDecompressor.swift
//  Caker
//
//  Decompresses one chunk of a WIM resource compressed with LZX (the compression Microsoft's own installation
//  media use). A WIM compresses every 32 KiB chunk on its own, with the Huffman state starting over, so this only
//  deals with a single chunk of at most 32768 bytes.
//
//  The format is the one the CAB "LZX" and Microsoft's LZX DELTA share, as WIM uses it: no frame header, the
//  x86 "E8" call translation always on (with a fixed 12,000,000-byte file size), and 16-bit little-endian
//  words read most significant bit first.
//
//  Written from the format description in [MS-PATCH] and the WIM specification.
//

import Foundation

enum LZXError: Error {
	case corrupt(String)
}

struct LZXDecompressor {
	private static let numChars = 256
	private static let minMatch = 2
	private static let numSecondaryLengths = 249
	private static let preTreeSymbols = 20
	private static let alignedSymbols = 8
	private static let translationFileSize: Int32 = 12_000_000

	private enum BlockType: UInt32 {
		case verbatim = 1
		case aligned = 2
		case uncompressed = 3
	}

	/// Position slots for a 2^15-byte window: the window a 32 KiB chunk needs.
	private let positionSlots = 30
	private let extraBits: [Int]
	private let positionBase: [Int]

	init() {
		var extra = [Int]()
		var base = [Int]()

		for slot in 0..<30 {
			extra.append(slot < 4 ? 0 : (slot < 36 ? (slot - 2) / 2 : 17))
			base.append(slot == 0 ? 0 : base[slot - 1] + (1 << extra[slot - 1]))
		}

		self.extraBits = extra
		self.positionBase = base
	}

	/// Decompresses `input` into exactly `outputSize` bytes.
	func decompress(_ input: [UInt8], outputSize: Int) throws -> [UInt8] {
		var reader = BitReader(input)
		var output = [UInt8](repeating: 0, count: outputSize)
		var position = 0
		var recent = (1, 1, 1)

		var mainLengths = [UInt8](repeating: 0, count: Self.numChars + positionSlots * 8)
		var lengthLengths = [UInt8](repeating: 0, count: Self.numSecondaryLengths)

		while position < outputSize {
			guard let blockType = BlockType(rawValue: reader.read(3)) else {
				throw LZXError.corrupt("invalid block type")
			}

			var blockSize = reader.read(1) == 1 ? 32768 : Int(reader.read(16))

			if blockSize == 0 || blockSize > outputSize - position {
				blockSize = outputSize - position
			}

			let blockEnd = position + blockSize

			switch blockType {
			case .uncompressed:
				// 1-16 padding bits up to a 16-bit boundary, then the three repeat offsets and the raw bytes
				reader.alignToWord()

				guard let r0 = reader.readRawUInt32(), let r1 = reader.readRawUInt32(), let r2 = reader.readRawUInt32() else {
					throw LZXError.corrupt("truncated uncompressed block")
				}

				recent = (Int(r0), Int(r1), Int(r2))

				guard let raw = reader.readRawBytes(blockSize) else {
					throw LZXError.corrupt("truncated uncompressed block")
				}

				output.replaceSubrange(position..<blockEnd, with: raw)
				position = blockEnd

				if blockSize % 2 == 1 {
					reader.skipRawBytes(1)
				}

			case .verbatim, .aligned:
				var alignedTree: HuffmanTree?

				if blockType == .aligned {
					var lengths = [UInt8]()

					for _ in 0..<Self.alignedSymbols {
						lengths.append(UInt8(reader.read(3)))
					}

					alignedTree = try HuffmanTree(lengths)
				}

				try Self.readLengths(&mainLengths, from: 0, to: Self.numChars, reader: &reader)
				try Self.readLengths(&mainLengths, from: Self.numChars, to: mainLengths.count, reader: &reader)
				try Self.readLengths(&lengthLengths, from: 0, to: Self.numSecondaryLengths, reader: &reader)

				let mainTree = try HuffmanTree(mainLengths)
				let lengthTree = try HuffmanTree(lengthLengths)

				while position < blockEnd {
					let symbol = try mainTree.decode(&reader)

					if symbol < Self.numChars {
						output[position] = UInt8(symbol)
						position += 1
						continue
					}

					let header = symbol - Self.numChars
					let slot = header >> 3
					var matchLength = (header & 7) + Self.minMatch

					if (header & 7) == 7 {
						matchLength += try lengthTree.decode(&reader)
					}

					var offset: Int

					switch slot {
					case 0:
						offset = recent.0
					case 1:
						offset = recent.1
						recent.1 = recent.0
						recent.0 = offset
					case 2:
						offset = recent.2
						recent.2 = recent.0
						recent.0 = offset
					default:
						let extra = extraBits[slot]

						offset = positionBase[slot] - 2

						if let alignedTree, extra >= 3 {
							if extra > 3 {
								offset += Int(reader.read(extra - 3)) << 3
							}

							offset += try alignedTree.decode(&reader)
						} else if extra > 0 {
							offset += Int(reader.read(extra))
						}

						recent.2 = recent.1
						recent.1 = recent.0
						recent.0 = offset
					}

					guard offset > 0, offset <= position else {
						throw LZXError.corrupt("match offset out of range")
					}

					let count = min(matchLength, outputSize - position)

					// A match may overlap its own output, so copy byte by byte
					for index in 0..<count {
						output[position + index] = output[position + index - offset]
					}

					position += count
				}
			}
		}

		Self.undoCallTranslation(&output)

		return output
	}

	/// Reads the code lengths of `lengths[from..<to]` as differences from the previous block's, through a small
	/// Huffman tree of their own (the "pretree").
	private static func readLengths(_ lengths: inout [UInt8], from: Int, to: Int, reader: inout BitReader) throws {
		var preLengths = [UInt8]()

		for _ in 0..<preTreeSymbols {
			preLengths.append(UInt8(reader.read(4)))
		}

		let preTree = try HuffmanTree(preLengths)
		var index = from

		while index < to {
			let symbol = try preTree.decode(&reader)

			switch symbol {
			case 0...16:
				lengths[index] = UInt8((Int(lengths[index]) - symbol + 17) % 17)
				index += 1
			case 17, 18:
				let count = symbol == 17 ? Int(reader.read(4)) + 4 : Int(reader.read(5)) + 20

				guard index + count <= to else { throw LZXError.corrupt("run of zeros past the tree") }

				for _ in 0..<count {
					lengths[index] = 0
					index += 1
				}
			default:
				let count = Int(reader.read(1)) + 4
				let next = try preTree.decode(&reader)

				guard index + count <= to else { throw LZXError.corrupt("run past the tree") }

				let value = UInt8((Int(lengths[index]) - next + 17) % 17)

				for _ in 0..<count {
					lengths[index] = value
					index += 1
				}
			}
		}
	}

	/// The compressor turns the relative target of every x86 CALL (opcode E8) into an absolute address, which
	/// compresses better. This puts them back.
	private static func undoCallTranslation(_ data: inout [UInt8]) {
		guard data.count > 10 else { return }

		let end = data.count - 10
		var index = 0

		while index < end {
			if data[index] != 0xE8 {
				index += 1
				continue
			}

			let absolute = Int32(bitPattern: UInt32(data[index + 1]) | UInt32(data[index + 2]) << 8 | UInt32(data[index + 3]) << 16 | UInt32(data[index + 4]) << 24)

			if absolute >= -Int32(index) && absolute < translationFileSize {
				let relative = absolute >= 0 ? absolute - Int32(index) : absolute + translationFileSize
				let bits = UInt32(bitPattern: relative)

				data[index + 1] = UInt8(truncatingIfNeeded: bits)
				data[index + 2] = UInt8(truncatingIfNeeded: bits >> 8)
				data[index + 3] = UInt8(truncatingIfNeeded: bits >> 16)
				data[index + 4] = UInt8(truncatingIfNeeded: bits >> 24)
			}

			index += 5
		}
	}
}

// MARK: - Bits

/// Reads bits from 16-bit little-endian words, the first bit of a word being its most significant.
private struct BitReader {
	private let input: [UInt8]
	private var next = 0
	private var buffer: UInt64 = 0
	private var count = 0

	init(_ input: [UInt8]) {
		self.input = input
	}

	private mutating func fill(_ bits: Int) {
		while count < bits {
			let low = next < input.count ? UInt64(input[next]) : 0
			let high = next + 1 < input.count ? UInt64(input[next + 1]) : 0

			buffer = (buffer << 16) | (high << 8) | low
			count += 16
			next += 2
		}
	}

	mutating func read(_ bits: Int) -> UInt32 {
		guard bits > 0 else { return 0 }

		fill(bits)
		count -= bits

		return UInt32((buffer >> UInt64(count)) & ((1 << UInt64(bits)) - 1))
	}

	/// Drops the rest of the current word, or a whole one if none of it is left (LZX pads with 1 to 16 bits).
	mutating func alignToWord() {
		if count == 0 {
			fill(16)
		}

		count = 0
		buffer = 0
	}

	mutating func readRawBytes(_ length: Int) -> [UInt8]? {
		guard next + length <= input.count else { return nil }

		defer { next += length }

		return Array(input[next..<(next + length)])
	}

	mutating func readRawUInt32() -> UInt32? {
		guard let bytes = readRawBytes(4) else { return nil }

		return UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
	}

	mutating func skipRawBytes(_ length: Int) {
		next += length
	}
}

/// A canonical Huffman code, decoded one bit at a time (the metadata this reads is small).
private struct HuffmanTree {
	private var counts = [Int](repeating: 0, count: 17)
	private var symbols: [Int]

	init(_ lengths: [UInt8]) throws {
		for length in lengths {
			guard length <= 16 else { throw LZXError.corrupt("code length over 16") }

			counts[Int(length)] += 1
		}

		counts[0] = 0

		var offsets = [Int](repeating: 0, count: 18)

		for length in 1...16 {
			offsets[length + 1] = offsets[length] + counts[length]
		}

		symbols = [Int](repeating: 0, count: lengths.count)

		for (symbol, length) in lengths.enumerated() where length != 0 {
			symbols[offsets[Int(length)]] = symbol
			offsets[Int(length)] += 1
		}
	}

	func decode(_ reader: inout BitReader) throws -> Int {
		var code = 0
		var first = 0
		var index = 0

		for length in 1...16 {
			code |= Int(reader.read(1))

			let count = counts[length]

			if code - first < count {
				return symbols[index + (code - first)]
			}

			index += count
			first = (first + count) << 1
			code <<= 1
		}

		throw LZXError.corrupt("invalid Huffman code")
	}
}
