import Containerization
import ContainerizationOCI
import Foundation
import GRPCLib

public let defaultRemotes: [String: String] = [
	"images": "https://images.linuxcontainers.org/",
	"ubuntu": "https://cloud-images.ubuntu.com/releases/",
		//	"canonical": "https://images.lxd.canonical.com/"
]

public class RemoteDatabase {
	// Snapshot loaded at init — use for read-only queries during a command.
	public private(set) var remote: [String: String] = defaultRemotes
	public let url: URL
	private let lock: FileLock

	public var keys: [String] { Array(remote.keys) }

	init(_ url: URL) throws {
		self.url = url

		if try url.exists() == false {
			try defaultRemotes.write(to: url)
		}

		self.lock = try FileLock(lockURL: url)
		// Read once under lock for a consistent snapshot, then release immediately.
		try self.lock.lock()
		self.remote = try Dictionary(contentsOf: url)
		try self.lock.unlock()
	}

	public func get(_ key: String) -> String? {
		if key == String.empty {
			return remote["images"]
		}
		return remote[key]
	}

	public func reverseLookup(_ value: String) -> String? {
		return remote.first { (_, val: String) in
			URL(string: val).map { $0.host() == value } ?? false
		}?.key
	}

	@inlinable public func map<T>(_ transform: ((key: String, value: String)) throws -> T) throws -> [T] {
		return try remote.map(transform)
	}

	/// Atomically writes `value` for `key`, re-reading disk state under lock first
	/// so concurrent mutations to other keys are preserved.
	public func upsert(_ key: String, _ value: String) throws {
		try lock.lock()
		defer { try? lock.unlock() }
		var onDisk: [String: String] = (try? Dictionary(contentsOf: url)) ?? defaultRemotes
		onDisk[key] = value
		try onDisk.write(to: url)
		self.remote = onDisk
	}

	/// Atomically removes `key` and writes the updated state back to disk.
	@discardableResult
	public func remove(_ key: String) throws -> Bool {
		try lock.lock()
		defer { try? lock.unlock() }
		var onDisk: [String: String] = (try? Dictionary(contentsOf: url)) ?? defaultRemotes
		let removed = onDisk.removeValue(forKey: key) != nil
		try onDisk.write(to: url)
		self.remote = onDisk
		return removed
	}
}

public struct Home {
	public static let cakedCommandName = "caked"
	public static let cakerCommandName = "Caker"

	public let cakeHomeDirectory: URL
	public let agentPID: URL
	public let networkDirectory: URL
	public let cacheDirectory: URL
	public let agentDirectory: URL
	public let temporaryDirectory: URL
	public let remoteDb: URL
	public let composeFileDb: URL
	public let sshPrivateKey: URL
	public let sshPublicKey: URL
	public let contentStoreURL: URL
	public let imageStoreURL: URL

	public let contentStore: LocalContentStore!
	public let imageStore: ImageStore!

	public init(_ cakeHomeDirectory: URL, runMode: Utils.RunMode, createItIfNotExists: Bool = true) throws {
		self.cakeHomeDirectory = cakeHomeDirectory
		self.networkDirectory = self.cakeHomeDirectory.appendingPathComponent("networks", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.cacheDirectory = self.cakeHomeDirectory.appendingPathComponent("cache", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.agentDirectory = self.cakeHomeDirectory.appendingPathComponent("agent", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.agentPID = self.agentDirectory.appendingPathComponent("agent.pid", isDirectory: false).absoluteURL.resolvingSymlinksInPath()
		self.temporaryDirectory = self.cakeHomeDirectory.appendingPathComponent("tmp", isDirectory: true).absoluteURL.resolvingSymlinksInPath()
		self.remoteDb = self.cakeHomeDirectory.appendingPathComponent("remote.json", isDirectory: false).absoluteURL.resolvingSymlinksInPath()
		self.composeFileDb = self.cakeHomeDirectory.appendingPathComponent("compose.json", isDirectory: false).absoluteURL.resolvingSymlinksInPath()
		self.contentStoreURL = self.cacheDirectory.appendingPathComponent("oci/storage")
		self.imageStoreURL = cacheDirectory.appendingPathComponent("oci")

		if try cakeHomeDirectory.exists() == false && createItIfNotExists {
			try FileManager.default.createDirectory(at: cakeHomeDirectory, withIntermediateDirectories: true)
		}

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

			if try self.composeFileDb.exists() == false {
				let defaultComposeFiles: [String: ComposeFileDatabase.ComposeFileStatus] = [:]
				try defaultComposeFiles.write(to: self.composeFileDb)
			}
		}

		if try self.agentDirectory.exists() == false && createItIfNotExists {
			try FileManager.default.createDirectory(at: self.agentDirectory, withIntermediateDirectories: true)
			_ = try CertificatesLocation.createAgentCertificats(runMode: runMode, force: true)
		}
	}

	public init(runMode: Utils.RunMode, createItIfNotExists: Bool = true) throws {
		try self.init(try Utils.getHome(runMode: runMode, createItIfNotExists: createItIfNotExists), runMode: runMode, createItIfNotExists: createItIfNotExists)
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

	public func composeFileDatabase() throws -> ComposeFileDatabase {
		return try ComposeFileDatabase(self.composeFileDb)
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
