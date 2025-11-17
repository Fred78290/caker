//
//  RawDisk.swift
//  Caker
//
//  Created by Frederic BOLTZ on 16/11/2025.
//

import Foundation
import ContainerizationArchive
import ContainerizationExtras
import SystemPackage
import Compression

struct RawDisk: FileSystemProtocol {
	static let bufferSizeBytes = 4 * 1024 * 1024
	static let layerLimitBytes = 500 * 1000 * 1000

	private var handle: FileHandle

	init(_ devicePath: FilePath) throws {
		if !FileManager.default.fileExists(atPath: devicePath.description) {
			FileManager.default.createFile(atPath: devicePath.description, contents: nil)
		}

		guard let fileHandle = FileHandle(forWritingTo: devicePath) else {
			throw ServiceError("File not found")
		}

		self.handle = fileHandle
	}

	func close() throws {
		self.handle.closeFile()
	}
	
	func unpack(source: URL, compression: ContainerizationArchive.Filter) throws {
		// Decompress the layers onto the disk in a single stream
		let filter = try OutputFilter(.decompress, using: .lz4, bufferCapacity: Self.bufferSizeBytes) { data in
			if let data = data {
				try self.handle.write(contentsOf: data)
			}
		}
		
		let content = try Data(contentsOf: source, options: [.alwaysMapped])
		try filter.write(content)
		try filter.finalize()
	}
}
