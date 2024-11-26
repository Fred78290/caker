import Foundation

struct VMLocation {
	var rootURL: URL

	var configURL: URL {
		rootURL.appendingPathComponent("config.json")
	}

	var diskURL: URL {
		rootURL.appendingPathComponent("disk.img")
	}

	var nvramURL: URL {
		rootURL.appendingPathComponent("nvram.bin")
	}

	var stateURL: URL {
		rootURL.appendingPathComponent("state.vzvmsave")
	}

	var manifestURL: URL {
		rootURL.appendingPathComponent("manifest.json")
	}

	var name: String {
		rootURL.lastPathComponent
	}

	var url: URL {
		rootURL
	}

	var inited: Bool {
		FileManager.default.fileExists(atPath: configURL.path) &&
			FileManager.default.fileExists(atPath: diskURL.path) &&
			FileManager.default.fileExists(atPath: nvramURL.path)
	}

	static func tempDirectory() throws -> VMLocation {
		let tmpDir = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: false)

		return VMLocation(rootURL: tmpDir)
	}

	func validatate(userFriendlyName: String) throws {
		if !FileManager.default.fileExists(atPath: rootURL.path) {
			throw ServiceError("VM not found \(userFriendlyName)")
		}

		if !self.inited {
			throw ServiceError("VM is not correctly inited, missing files: (\(configURL.lastPathComponent), \(diskURL.lastPathComponent) or \(nvramURL.lastPathComponent))")
		}
	}

	func expandDiskTo(_ sizeGB: UInt16) throws {
		let wantedFileSize = UInt64(sizeGB) * 1000 * 1000 * 1000

		if !FileManager.default.fileExists(atPath: diskURL.path) {
			FileManager.default.createFile(atPath: diskURL.path, contents: nil, attributes: nil)
		}

		let diskFileHandle = try FileHandle.init(forWritingTo: diskURL)

		defer {
			do {
				try diskFileHandle.close()
			} catch {

			}
		}

		let curFileSize = try diskFileHandle.seekToEnd()

		if wantedFileSize < curFileSize {
			let curFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(curFileSize))
			let wantedFileSizeHuman = ByteCountFormatter().string(fromByteCount: Int64(wantedFileSize))
			throw ServiceError("the new file size \(wantedFileSizeHuman) is lesser than the current disk size of \(curFileSizeHuman)")
		} else if wantedFileSize > curFileSize {
			try diskFileHandle.truncate(atOffset: wantedFileSize)
		}
	}

}