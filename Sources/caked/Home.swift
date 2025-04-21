import Foundation
import GRPCLib

let defaultRemotes: [String:String] = [
	"images": "https://images.linuxcontainers.org/",
	"ubuntu": "https://cloud-images.ubuntu.com/releases/",
//	"canonical": "https://images.lxd.canonical.com/"
]

class RemoteDatabase {
	var remote: Dictionary<String,String> = defaultRemotes
	let url: URL
	let lock: FileLock
	var keys: [String] {
		return self.remote.keys.compactMap { $0 }
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
		if key == "" {
			return self.remote["images"]
		}

		return self.remote[key]
	}

	func reverseLookup(_ value: String) -> String? {
		return self.remote.first { (key: String, val: String) in
			if let u = URL(string: val) {
				return u.host() == value
			}
			return false
		}?.key
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
	let cakeHomeDirectory: URL
	let networkDirectory: URL
	let cacheDirectory: URL
	let agentDirectory: URL
	let temporaryDirectory: URL
	let remoteDb: URL
	let sshPrivateKey: URL
	let sshPublicKey: URL

	init(asSystem: Bool, createItIfNotExists: Bool = true) throws {
		self.cakeHomeDirectory = try Utils.getHome(asSystem: asSystem, createItIfNotExists: createItIfNotExists)
		self.networkDirectory = self.cakeHomeDirectory.appendingPathComponent("networks", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.cacheDirectory = self.cakeHomeDirectory.appendingPathComponent("cache", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.agentDirectory = self.cakeHomeDirectory.appendingPathComponent("agent", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.temporaryDirectory = self.cakeHomeDirectory.appendingPathComponent("tmp", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.remoteDb = self.cakeHomeDirectory.appendingPathComponent("remote.json", isDirectory: false).absoluteURL.resolvingSymlinksInPath()

		self.sshPrivateKey = self.cakeHomeDirectory.appendingPathComponent("cake_rsa", isDirectory: false).absoluteURL.resolvingSymlinksInPath()
		self.sshPublicKey = self.cakeHomeDirectory.appendingPathComponent("cake_rsa.pub", isDirectory: false).absoluteURL.resolvingSymlinksInPath()

		if try self.cakeHomeDirectory.exists() && createItIfNotExists {
			try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
			try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

			if try self.remoteDb.exists() == false {
				try defaultRemotes.write(to: self.remoteDb)
			}
		}
	}

	func sharedNetworks() throws -> VZVMNetConfig {
		let location = self.networkDirectory.appendingPathComponent("networks.json", isDirectory: false).absoluteURL
		let config: VZVMNetConfig

		if try self.networkDirectory.exists() == false {
			try FileManager.default.createDirectory(at: self.networkDirectory, withIntermediateDirectories: true)
		}

		if try location.exists() == false {
			config = try VZVMNetConfig()

			try config.save(toURL: location)
		} else {
			config = try VZVMNetConfig(fromURL: location)
		}

		return config
	}

	func setSharedNetworks(_ config: VZVMNetConfig) throws {
		try config.save(toURL: self.networkDirectory.appendingPathComponent("networks.json", isDirectory: false).absoluteURL)
	}

	func remoteDatabase() throws -> RemoteDatabase {
		return try RemoteDatabase(self.remoteDb)
	}

	func getSharedPublicKey() throws -> String {
		if try self.sshPublicKey.exists() {
			let content = try Data(contentsOf: self.sshPublicKey)

			return String(data: content, encoding: .ascii)!
		} else {
			#if false
				let cypher = try CypherKeyGenerator(identifier: "com.aldunelabs.caker.ssh")
				let key = try cypher.generateKey()

				try key.save(privateURL: self.sshPrivateKey, publicURL: self.sshPublicKey)

				return try key.publicKeyString()
			#else
				let cypher = try RSAKeyGenerator()

				try cypher.save(privateURL: self.sshPrivateKey, publicURL: self.sshPublicKey)
				return cypher.publicKeyString
			#endif
		}
	}
}
