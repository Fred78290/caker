import Foundation
import GRPCLib
import ContainerizationOCI
import Containerization

public let defaultRemotes: [String: String] = [
	"images": "https://images.linuxcontainers.org/",
	"ubuntu": "https://cloud-images.ubuntu.com/releases/",
		//	"canonical": "https://images.lxd.canonical.com/"
]

public class RemoteDatabase {
	public var remote: [String: String] = defaultRemotes
	public let url: URL
	public let lock: FileLock
	public var keys: [String] {
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

	public func add(_ key: String, _ value: String) {
		self.remote[key] = value
	}

	public func get(_ key: String) -> String? {
		if key == "" {
			return self.remote["images"]
		}

		return self.remote[key]
	}

	public func reverseLookup(_ value: String) -> String? {
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

	@discardableResult public func remove(_ key: String) -> Bool {
		return self.remote.removeValue(forKey: key) != nil
	}

	public func save() throws {
		try self.remote.write(to: self.url)
	}
}

public struct Home {
	public static let cakedCommandName = "caked"

	public let cakeHomeDirectory: URL
	public let agentPID: URL
	public let networkDirectory: URL
	public let cacheDirectory: URL
	public let agentDirectory: URL
	public let temporaryDirectory: URL
	public let remoteDb: URL
	public let sshPrivateKey: URL
	public let sshPublicKey: URL
	public let contentStoreURL: URL
	public let imageStoreURL: URL

	public let contentStore: LocalContentStore!
	public let imageStore: ImageStore!

	public init(runMode: Utils.RunMode, createItIfNotExists: Bool = true) throws {
		self.cakeHomeDirectory = try Utils.getHome(runMode: runMode, createItIfNotExists: createItIfNotExists)
		self.networkDirectory = self.cakeHomeDirectory.appendingPathComponent("networks", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.cacheDirectory = self.cakeHomeDirectory.appendingPathComponent("cache", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.agentDirectory = self.cakeHomeDirectory.appendingPathComponent("agent", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.agentPID = self.agentDirectory.appendingPathComponent("agent.pid", isDirectory: false).absoluteURL.resolvingSymlinksInPath()
		self.temporaryDirectory = self.cakeHomeDirectory.appendingPathComponent("tmp", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.remoteDb = self.cakeHomeDirectory.appendingPathComponent("remote.json", isDirectory: false).absoluteURL.resolvingSymlinksInPath()
		self.contentStoreURL = self.cacheDirectory.appendingPathComponent("oci/storage")
		self.imageStoreURL = cacheDirectory.appendingPathComponent("oci")

		if createItIfNotExists {
			self.contentStore = try LocalContentStore(path: self.contentStoreURL)
			self.imageStore = try ImageStore(path: self.imageStoreURL, contentStore: self.contentStore)
		} else {
			self.contentStore = nil
			self.imageStore = nil
		}

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

	public func sharedNetworks() throws -> VZVMNetConfig {
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

	public func setSharedNetworks(_ config: VZVMNetConfig) throws {
		try config.save(toURL: self.networkDirectory.appendingPathComponent("networks.json", isDirectory: false).absoluteURL)
	}

	public func remoteDatabase() throws -> RemoteDatabase {
		return try RemoteDatabase(self.remoteDb)
	}

	public func getSharedPublicKey() throws -> String {
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
