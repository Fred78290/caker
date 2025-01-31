import Foundation
import GRPCLib

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
		if key == "" {
			return self.remote["images"]
		}

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
	let agentDir: URL
	let temporaryDir: URL
	let remoteDb: URL
	let sshPrivateKey: URL
	let sshPublicKey: URL

	init(asSystem: Bool) throws {
		self.homeDir = try Utils.getHome(asSystem: asSystem)
		self.cacheDir = self.homeDir.appendingPathComponent("cache", isDirectory: true).absoluteURL
		self.agentDir = self.homeDir.appendingPathComponent("agent", isDirectory: true).absoluteURL
		self.temporaryDir = self.homeDir.appendingPathComponent("tmp", isDirectory: true).absoluteURL
		self.remoteDb = self.homeDir.appendingPathComponent("remote.json", isDirectory: false).absoluteURL

		self.sshPrivateKey = self.homeDir.appendingPathComponent("cake_rsa", isDirectory: false).absoluteURL
		self.sshPublicKey = self.homeDir.appendingPathComponent("cake_rsa.pub", isDirectory: false).absoluteURL

		try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: temporaryDir, withIntermediateDirectories: true)

		if try self.remoteDb.exists() == false {
			try defaultRemotes.write(to: self.remoteDb)
		}
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
