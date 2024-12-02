import Foundation

let defaultRemotes: [String:String] = [
	"images": "https://images.linuxcontainers.org/",
	"ubuntu": "https://cloud-images.ubuntu.com/releases/",
	"canonical": "https://images.lxd.canonical.com/"
]

class RemoteDatabase {
	var remote: Dictionary<String,String> = defaultRemotes
	let url: URL
	let lock: FileLock
	var keys: Dictionary<String, String>.Keys {
		return self.remote.keys
	}

	init(_ url: URL) throws {
		self.url = url

		if try self.url.exists() == false {
			try remote.write(to: self.url)
		} else {
			self.remote = try Dictionary(contentsOf: url)
		}

		self.lock = try FileLock(lockURL: url)
		try self.lock.lock()
	}

	deinit {
		try? self.lock.unlock()
	}

	func add(_ key: String, _ value: String) {
		self.remote[key] = value
	}

	func get(_ key: String) -> String? {
		return self.remote[key]
	}

    @inlinable public func map<T>(_ transform: ((key: String, value: String)) throws -> T) throws -> [T] {
		return try self.remote.map(transform)
	}

	@discardableResult func remove(_ key: String) -> Bool {
		return self.remote.removeValue(forKey: key) != nil
	}

	func save() throws {
		try self.remote.write(to: self.url)
	}
}

struct Home {
	let homeDir: URL
	let cacheDir: URL
	let temporaryDir: URL
	let remoteDb: URL

	init(asSystem: Bool) throws {
		var baseDir: URL

		if asSystem {
			let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
			var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)

			applicationSupportDirectory = URL(fileURLWithPath: cakedSignature,
			                                  isDirectory: true,
			                                  relativeTo: applicationSupportDirectory)
			try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

			baseDir = applicationSupportDirectory
		} else if let customHome = ProcessInfo.processInfo.environment["CAKE_HOME"] {
			baseDir = URL(fileURLWithPath: customHome)
		} else {
			baseDir = FileManager.default
				.homeDirectoryForCurrentUser
				.appendingPathComponent(".cake", isDirectory: true)
		}

		self.homeDir = baseDir
		self.cacheDir = baseDir.appendingPathComponent("cache", isDirectory: true).absoluteURL
		self.temporaryDir = baseDir.appendingPathComponent("tmp", isDirectory: true).absoluteURL
		self.remoteDb = baseDir.appendingPathComponent("remote.json", isDirectory: false).absoluteURL

		try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: temporaryDir, withIntermediateDirectories: true)

		if try self.remoteDb.exists() == false {
			try defaultRemotes.write(to: self.remoteDb)
		}
	}

	func remoteDatabase() throws -> RemoteDatabase {
		return try RemoteDatabase(self.remoteDb)
	}
}
