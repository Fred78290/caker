//
//  WIMArchive.swift
//  Caker
//
//  Reads Windows Imaging (WIM) files and adds files to one of their images, without a tool like wimlib or DISM
//  (neither of which runs on macOS out of the box). That's all the Windows installer needs: list the editions of
//  install.wim, and put a shell script into WinPE's boot.wim.
//
//  A WIM is a header, then "resources" (file contents and each image's directory tree, called its metadata),
//  a lookup table mapping each file's SHA-1 to its resource, and an XML document describing the images. Editing
//  never rewrites what is already in the file: the changed directory, the new files and a new lookup table are
//  appended, and the header, written last, points at them. An interrupted edit therefore leaves the old WIM intact.
//
//  Written from Microsoft's "Windows Imaging File Format" specification.
//

import CryptoKit
import Foundation

enum WIMError: Error, LocalizedError {
	case notAWIM
	case unsupported(String)
	case corrupt(String)
	case notFound(String)

	var errorDescription: String? {
		switch self {
		case .notAWIM: return String(localized: "Not a Windows image (WIM) file")
		case .unsupported(let reason): return String(format: String(localized: "Unsupported Windows image: %@"), reason)
		case .corrupt(let reason): return String(format: String(localized: "Corrupt Windows image: %@"), reason)
		case .notFound(let what): return String(format: String(localized: "Not found in the Windows image: %@"), what)
		}
	}
}

final class WIMArchive {
	struct ResourceHeader {
		static let free: UInt8 = 0x01
		static let metadata: UInt8 = 0x02
		static let compressed: UInt8 = 0x04

		var size: UInt64
		var flags: UInt8
		var offset: UInt64
		var originalSize: UInt64

		init(size: UInt64, flags: UInt8, offset: UInt64, originalSize: UInt64) {
			self.size = size
			self.flags = flags
			self.offset = offset
			self.originalSize = originalSize
		}

		init(_ data: Data, at start: Int) {
			// 7 bytes of size and 1 of flags, then the offset and the uncompressed size
			let sizeAndFlags = data.uint64(at: start)

			self.size = sizeAndFlags & 0x00FF_FFFF_FFFF_FFFF
			self.flags = UInt8(sizeAndFlags >> 56)
			self.offset = data.uint64(at: start + 8)
			self.originalSize = data.uint64(at: start + 16)
		}

		var bytes: Data {
			var data = Data()

			data.append(uint64: size | UInt64(flags) << 56)
			data.append(uint64: offset)
			data.append(uint64: originalSize)

			return data
		}
	}

	struct LookupEntry {
		static let size = 50

		var partNumber: UInt16
		var resource: ResourceHeader
		var referenceCount: UInt32
		var hash: [UInt8]

		var bytes: Data {
			var data = Data()

			data.append(resource.bytes)
			data.append(uint16: partNumber)
			data.append(uint32: referenceCount)
			data.append(contentsOf: hash)

			return data
		}
	}

	struct ImageInfo {
		let index: Int
		let name: String
		/// The image's default language, e.g. `en-US` (empty if the image doesn't say).
		let language: String
	}

	/// A file or directory of an image, as `files(ofImage:)` lists it.
	struct Entry {
		let path: String
		let isDirectory: Bool
		let hash: [UInt8]
	}

	private static let headerSize = 208
	private static let magic = Data("MSWIM\0\0\0".utf8)
	private static let compressionFlag: UInt32 = 0x0000_0002
	private static let lzxFlag: UInt32 = 0x0004_0000
	private static let directoryAttribute: UInt32 = 0x10
	private static let archiveAttribute: UInt32 = 0x20

	let url: URL
	private(set) var imageCount = 0
	private(set) var bootIndex = 0
	private var flags: UInt32 = 0
	private var chunkSize = 0
	private var partNumber: UInt16 = 1
	private var header = Data()

	private var lookupTable = ResourceHeader(size: 0, flags: 0, offset: 0, originalSize: 0)
	private var xmlData = ResourceHeader(size: 0, flags: 0, offset: 0, originalSize: 0)
	private var bootMetadata = ResourceHeader(size: 0, flags: 0, offset: 0, originalSize: 0)

	init(url: URL) throws {
		self.url = url

		let handle = try FileHandle(forReadingFrom: url)

		defer { try? handle.close() }

		header = try handle.read(upToCount: Self.headerSize) ?? Data()

		guard header.count == Self.headerSize, header.prefix(8) == Self.magic else {
			throw WIMError.notAWIM
		}

		flags = header.uint32(at: 16)
		chunkSize = Int(header.uint32(at: 20))
		partNumber = header.uint16(at: 40)
		imageCount = Int(header.uint32(at: 44))
		lookupTable = ResourceHeader(header, at: 48)
		xmlData = ResourceHeader(header, at: 72)
		bootMetadata = ResourceHeader(header, at: 96)
		bootIndex = Int(header.uint32(at: 120))

		guard header.uint16(at: 42) == 1 else {
			throw WIMError.unsupported("split WIM")
		}
	}

	// MARK: - Reading

	private var isCompressed: Bool {
		flags & Self.compressionFlag != 0
	}

	private func readLookupTable() throws -> [LookupEntry] {
		let data = try readResource(lookupTable, compressed: false)

		guard data.count % LookupEntry.size == 0 else {
			throw WIMError.corrupt("lookup table size")
		}

		return stride(from: 0, to: data.count, by: LookupEntry.size).map { start in
			LookupEntry(
				partNumber: data.uint16(at: start + 24),
				resource: ResourceHeader(data, at: start),
				referenceCount: data.uint32(at: start + 26),
				hash: Array(data[(start + 30)..<(start + 50)]))
		}
	}

	/// Returns a resource's uncompressed contents.
	private func readResource(_ resource: ResourceHeader, compressed: Bool? = nil) throws -> Data {
		let handle = try FileHandle(forReadingFrom: url)

		defer { try? handle.close() }

		try handle.seek(toOffset: resource.offset)

		guard let stored = try handle.read(upToCount: Int(resource.size)), stored.count == Int(resource.size) else {
			throw WIMError.corrupt("resource past the end of the file (offset \(resource.offset), size \(resource.size), flags \(resource.flags))")
		}

		guard compressed ?? (resource.flags & ResourceHeader.compressed != 0) else {
			return stored
		}

		guard flags & Self.lzxFlag != 0 else {
			throw WIMError.unsupported("compression other than LZX")
		}

		return try decompress(stored, originalSize: Int(resource.originalSize))
	}

	/// A compressed resource is a table of chunk offsets (the first chunk starts at 0, so it has no entry) followed by
	/// the chunks, each compressed on its own; a chunk that didn't shrink is stored as is.
	private func decompress(_ stored: Data, originalSize: Int) throws -> Data {
		guard originalSize > 0 else { return Data() }
		guard chunkSize > 0 else { throw WIMError.corrupt("chunk size") }

		let chunkCount = (originalSize + chunkSize - 1) / chunkSize
		let entrySize = originalSize > Int(UInt32.max) ? 8 : 4
		let tableSize = (chunkCount - 1) * entrySize

		guard stored.count >= tableSize else { throw WIMError.corrupt("chunk table") }

		func chunkOffset(_ index: Int) -> Int {
			if index == 0 { return 0 }
			return entrySize == 4 ? Int(stored.uint32(at: (index - 1) * 4)) : Int(stored.uint64(at: (index - 1) * 8))
		}

		let decompressor = LZXDecompressor()
		var result = Data()

		result.reserveCapacity(originalSize)

		for index in 0..<chunkCount {
			let start = tableSize + chunkOffset(index)
			let end = index == chunkCount - 1 ? stored.count : tableSize + chunkOffset(index + 1)
			let uncompressedSize = index == chunkCount - 1 ? originalSize - index * chunkSize : chunkSize

			guard start <= end, end <= stored.count else { throw WIMError.corrupt("chunk bounds") }

			let chunk = [UInt8](stored[(stored.startIndex + start)..<(stored.startIndex + end)])

			if chunk.count == uncompressedSize {
				result.append(contentsOf: chunk)
			} else {
				result.append(contentsOf: try decompressor.decompress(chunk, outputSize: uncompressedSize))
			}
		}

		return result
	}

	/// The images' names and default languages, from the XML description.
	func images() throws -> [ImageInfo] {
		let data = try readResource(xmlData, compressed: false)
		var bytes = data

		if bytes.prefix(2) == Data([0xFF, 0xFE]) {
			bytes = bytes.dropFirst(2)
		}

		guard let xml = String(data: bytes, encoding: .utf16LittleEndian), let document = try? XMLDocument(xmlString: xml, options: []) else {
			throw WIMError.corrupt("XML data")
		}

		return try document.nodes(forXPath: "/WIM/IMAGE").compactMap { node -> ImageInfo? in
			guard let element = node as? XMLElement, let index = Int(element.attribute(forName: "INDEX")?.stringValue ?? "") else {
				return nil
			}

			let name = try element.nodes(forXPath: "NAME").first?.stringValue ?? ""
			let language = try element.nodes(forXPath: "WINDOWS/LANGUAGES/DEFAULT").first?.stringValue ?? ""

			return ImageInfo(index: index, name: name, language: language)
		}
	}

	// MARK: - Directory entries

	/// What a directory entry holds. Offsets are into an image's (uncompressed) metadata resource.
	private struct DirectoryEntry {
		static let fixedSize = 102

		let offset: Int
		/// The entry, its names and its alternate data stream entries.
		let blockSize: Int
		let attributes: UInt32
		let subdirectoryOffset: Int
		let hash: [UInt8]
		let name: String

		var isDirectory: Bool { attributes & WIMArchive.directoryAttribute != 0 }
	}

	private func entry(in metadata: Data, at offset: Int) throws -> DirectoryEntry? {
		guard offset + 8 <= metadata.count else { throw WIMError.corrupt("directory entry offset") }

		let length = Int(metadata.uint64(at: offset))

		if length == 0 { return nil }

		guard length >= DirectoryEntry.fixedSize, offset + length <= metadata.count else { throw WIMError.corrupt("directory entry length") }

		let streams = Int(metadata.uint16(at: offset + 96))
		let nameBytes = Int(metadata.uint16(at: offset + 100))

		guard DirectoryEntry.fixedSize + nameBytes <= length else { throw WIMError.corrupt("directory entry name") }

		let nameStart = offset + DirectoryEntry.fixedSize
		let name = String(data: metadata[nameStart..<(nameStart + nameBytes)], encoding: .utf16LittleEndian) ?? ""
		var end = offset + length

		for _ in 0..<streams {
			guard end + 8 <= metadata.count else { throw WIMError.corrupt("stream entry") }

			let streamLength = Int(metadata.uint64(at: end))

			guard streamLength >= 38, end + streamLength <= metadata.count else { throw WIMError.corrupt("stream entry length") }

			end += streamLength
		}

		return DirectoryEntry(
			offset: offset,
			blockSize: end - offset,
			attributes: metadata.uint32(at: offset + 8),
			subdirectoryOffset: Int(metadata.uint64(at: offset + 16)),
			hash: Array(metadata[(offset + 64)..<(offset + 84)]),
			name: name)
	}

	private func children(of directory: DirectoryEntry, in metadata: Data) throws -> [DirectoryEntry] {
		guard directory.subdirectoryOffset != 0 else { return [] }

		var result = [DirectoryEntry]()
		var offset = directory.subdirectoryOffset

		while let child = try entry(in: metadata, at: offset) {
			result.append(child)
			offset += child.blockSize
		}

		return result
	}

	/// The image's metadata resource and its root directory entry. The metadata starts with the security
	/// descriptors, and the root entry follows them, 8-byte aligned.
	private func root(of metadata: Data) throws -> DirectoryEntry {
		guard metadata.count >= 8 else { throw WIMError.corrupt("metadata") }

		let securitySize = Int(metadata.uint32(at: 0))
		let rootOffset = (max(securitySize, 8) + 7) & ~7

		guard let root = try entry(in: metadata, at: rootOffset) else { throw WIMError.corrupt("root directory") }

		return root
	}

	private func metadataEntries(_ table: [LookupEntry]) -> [Int] {
		table.indices.filter { table[$0].resource.flags & ResourceHeader.metadata != 0 }
	}

	/// Every file and directory of image `index` (1-based), with `\`-separated paths relative to the root.
	func files(ofImage index: Int) throws -> [Entry] {
		let table = try readLookupTable()
		let metadataIndexes = metadataEntries(table)

		guard index >= 1, index <= metadataIndexes.count else { throw WIMError.notFound("image \(index)") }

		let metadata = try readResource(table[metadataIndexes[index - 1]].resource)
		var result = [Entry]()

		func walk(_ directory: DirectoryEntry, path: String) throws {
			for child in try children(of: directory, in: metadata) {
				let childPath = path.isEmpty ? child.name : path + "\\" + child.name

				result.append(Entry(path: childPath, isDirectory: child.isDirectory, hash: child.hash))

				if child.isDirectory {
					try walk(child, path: childPath)
				}
			}
		}

		try walk(try root(of: metadata), path: "")

		return result
	}

	/// The contents of a file of image `index`, or `nil` if there is no such file.
	func contents(ofImage index: Int, path: String) throws -> Data? {
		guard let entry = try files(ofImage: index).first(where: { $0.path.caseInsensitiveCompare(path) == .orderedSame && $0.isDirectory == false }) else {
			return nil
		}

		let table = try readLookupTable()

		guard let resource = table.first(where: { $0.hash == entry.hash }) else {
			return entry.hash.allSatisfy { $0 == 0 } ? Data() : nil
		}

		return try readResource(resource.resource)
	}

	// MARK: - Adding files

	/// Adds `files` to the directory `directory` (e.g. `["Windows", "System32"]`) of image `index`, replacing files
	/// of the same name. Only appends to the WIM file.
	func addFiles(_ files: [(name: String, data: Data)], toDirectory directory: [String], ofImage index: Int) throws {
		var table = try readLookupTable()
		let metadataIndexes = metadataEntries(table)

		guard index >= 1, index <= metadataIndexes.count else { throw WIMError.notFound("image \(index)") }

		let metadataSlot = metadataIndexes[index - 1]
		var metadata = try readResource(table[metadataSlot].resource)

		// Find the directory
		var current = try root(of: metadata)

		for component in directory {
			guard let next = try children(of: current, in: metadata).first(where: { $0.name.caseInsensitiveCompare(component) == .orderedSame && $0.isDirectory }) else {
				throw WIMError.notFound(directory.joined(separator: "\\"))
			}

			current = next
		}

		// Its children, minus the files being replaced, plus the new ones, in name order
		let existing = try children(of: current, in: metadata)
		let replaced = existing.filter { entry in files.contains { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame } }
		var blocks = [(name: String, bytes: Data)]()

		for child in existing where replaced.contains(where: { $0.offset == child.offset }) == false {
			blocks.append((child.name, metadata.subdata(in: child.offset..<(child.offset + child.blockSize))))
		}

		for entry in replaced {
			release(hash: entry.hash, in: &table)
		}

		var newResources = [(hash: [UInt8], data: Data)]()
		let now = Self.fileTime(Date())

		for file in files {
			let hash = Array(Insecure.SHA1.hash(data: file.data))

			blocks.append((file.name, Self.makeFileEntry(name: file.name, hash: file.data.isEmpty ? [UInt8](repeating: 0, count: 20) : hash, size: file.data.count, time: now)))

			if file.data.isEmpty == false {
				newResources.append((hash, file.data))
			}
		}

		blocks.sort { Self.sortKey($0.name).lexicographicallyPrecedes(Self.sortKey($1.name)) }

		// The new child list goes at the end of the metadata, and the directory points at it
		while metadata.count % 8 != 0 {
			metadata.append(0)
		}

		let listOffset = metadata.count

		for block in blocks {
			metadata.append(block.bytes)
		}

		metadata.append(uint64: 0)
		metadata.replaceSubrange((current.offset + 16)..<(current.offset + 24), with: Data(uint64: UInt64(listOffset)))

		// Append the new resources, then the lookup table, then the header
		let handle = try FileHandle(forUpdating: url)

		defer { try? handle.close() }

		var end = try handle.seekToEnd()

		func append(_ data: Data, flags: UInt8) throws -> ResourceHeader {
			try handle.seek(toOffset: end)
			try handle.write(contentsOf: data)

			defer { end += UInt64(data.count) }

			return ResourceHeader(size: UInt64(data.count), flags: flags, offset: end, originalSize: UInt64(data.count))
		}

		let newMetadata = try append(metadata, flags: ResourceHeader.metadata)

		table[metadataSlot].resource = newMetadata
		table[metadataSlot].hash = Array(Insecure.SHA1.hash(data: metadata))

		for resource in newResources {
			if let slot = table.firstIndex(where: { $0.hash == resource.hash && $0.resource.flags & ResourceHeader.metadata == 0 }) {
				table[slot].referenceCount += 1
			} else {
				table.append(LookupEntry(partNumber: partNumber, resource: try append(resource.data, flags: 0), referenceCount: 1, hash: resource.hash))
			}
		}

		var tableData = Data()

		for entry in table {
			tableData.append(entry.bytes)
		}

		let newLookupTable = try append(tableData, flags: lookupTable.flags)

		var newHeader = header

		newHeader.replaceSubrange(48..<72, with: newLookupTable.bytes)

		if index == bootIndex {
			newHeader.replaceSubrange(96..<120, with: newMetadata.bytes)
		}

		// The integrity table (a checksum of the whole file) no longer matches; it's optional
		newHeader.replaceSubrange(124..<148, with: Data(count: 24))

		try handle.seek(toOffset: 0)
		try handle.write(contentsOf: newHeader)
		try handle.synchronize()

		header = newHeader
		lookupTable = newLookupTable

		if index == bootIndex {
			bootMetadata = newMetadata
		}
	}

	/// One reference to `hash` goes away; the resource is dropped from the table with its last reference. (Its
	/// bytes stay in the file as unreferenced data.)
	private func release(hash: [UInt8], in table: inout [LookupEntry]) {
		guard let slot = table.firstIndex(where: { $0.hash == hash && $0.resource.flags & ResourceHeader.metadata == 0 }) else { return }

		if table[slot].referenceCount > 1 {
			table[slot].referenceCount -= 1
		} else {
			table.remove(at: slot)
		}
	}

	/// Directory entries are ordered by name, compared case-insensitively.
	private static func sortKey(_ name: String) -> [UInt16] {
		Array(name.uppercased().utf16)
	}

	private static func fileTime(_ date: Date) -> UInt64 {
		UInt64((date.timeIntervalSince1970 + 11_644_473_600) * 10_000_000)
	}

	/// A directory entry for a plain file with no security descriptor, hard links or alternate streams.
	private static func makeFileEntry(name: String, hash: [UInt8], size: Int, time: UInt64) -> Data {
		let nameBytes = Data(name.utf16.flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] })
		let length = (DirectoryEntry.fixedSize + nameBytes.count + 2 + 7) & ~7
		var entry = Data()

		entry.append(uint64: UInt64(length))
		entry.append(uint32: archiveAttribute)
		entry.append(uint32: 0xFFFF_FFFF)
		entry.append(uint64: 0)
		entry.append(uint64: 0)
		entry.append(uint64: 0)
		entry.append(uint64: time)
		entry.append(uint64: time)
		entry.append(uint64: time)
		entry.append(contentsOf: hash)
		entry.append(uint32: 0)
		entry.append(uint64: 0)
		entry.append(uint16: 0)
		entry.append(uint16: 0)
		entry.append(uint16: UInt16(nameBytes.count))
		entry.append(nameBytes)
		entry.append(Data(count: length - entry.count))

		return entry
	}
}

// MARK: - Little-endian helpers

extension Data {
	func uint16(at offset: Int) -> UInt16 {
		let start = startIndex + offset

		return UInt16(self[start]) | UInt16(self[start + 1]) << 8
	}

	func uint32(at offset: Int) -> UInt32 {
		UInt32(uint16(at: offset)) | UInt32(uint16(at: offset + 2)) << 16
	}

	func uint64(at offset: Int) -> UInt64 {
		UInt64(uint32(at: offset)) | UInt64(uint32(at: offset + 4)) << 32
	}

	init(uint64 value: UInt64) {
		self.init()
		append(uint64: value)
	}

	mutating func append(uint16 value: UInt16) {
		append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8)])
	}

	mutating func append(uint32 value: UInt32) {
		append(uint16: UInt16(value & 0xFFFF))
		append(uint16: UInt16(value >> 16))
	}

	mutating func append(uint64 value: UInt64) {
		append(uint32: UInt32(value & 0xFFFF_FFFF))
		append(uint32: UInt32(value >> 32))
	}
}
