import Foundation

struct VMLocation {
	enum Status: String {
		case running
		case suspended
		case stopped
	}

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

	var agentURL: URL {
		rootURL.appendingPathComponent("agent.sock")
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

	var status: Status {
		get {
			if FileManager.default.fileExists(atPath: stateURL.path) {
				return .suspended
			} else {
				let fd = open(configURL.path, O_RDWR)

				if fd != -1 {

					defer {
						close(fd)
					}

					var result = flock(l_start: 0, l_len: 0, l_pid: 0, l_type: Int16(F_RDLCK), l_whence: Int16(SEEK_SET))

					if fcntl(fd, F_GETLK, &result) == 0 {
						if result.l_pid != 0 {
							return .running
						}
					}
				}

				return .stopped
			}
		}
	}

	func lock() -> Bool {
		let fd = open(configURL.path, O_RDWR) 

		if fd != -1 {
			close(fd)
		}

		return fd != -1
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