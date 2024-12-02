import Foundation

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
			try "{}".write(to: self.remoteDb, atomically: true, encoding: .utf8)
		}
	}

	func remoteDatabase() throws -> Dictionary<String, String> {
		return try Dictionary<String, String>(contentsOf: self.remoteDb)
	}
}
