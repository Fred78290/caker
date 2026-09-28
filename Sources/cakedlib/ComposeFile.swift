//
//  ComposeFile.swift
//  CakedLib
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import Foundation
import GRPCLib
import CakeAgentLib
import Yams

public class ComposeFileDatabase {
	public struct ServiceStatus: Codable {
		public var createdAt: Date
		public var instanceIdentifier: String
	}

	public struct ComposeFileStatus: Codable {
		public var composeFile: ComposeFile
		public var installed: [String: ServiceStatus]

		public init(composeFile: ComposeFile, installed: [String: ServiceStatus] = [:]) {
			self.composeFile = composeFile
			self.installed = installed
		}
	}

	// Snapshot loaded at init — use for read-only queries during a command.
	public private(set) var applications: [String: ComposeFileStatus] = [:]
	public let url: URL
	private let lock: FileLock

	public var names: [String] { Array(applications.keys) }

	init(_ url: URL) throws {
		self.url = url

		if try url.exists() == false {
			try ([String: ComposeFileStatus]()).write(to: url)
		}

		self.lock = try FileLock(lockURL: url)
		// Read once under lock to get a consistent snapshot, then release
		// immediately so long-running callers (e.g. compose up) don't block
		// other compose commands for the entire duration of the VM build.
		try self.lock.lock()
		self.applications = try Dictionary(contentsOf: url)
		try self.lock.unlock()
	}

	public func get(_ key: String) -> ComposeFileStatus? {
		guard key.isEmpty == false else { return nil }
		return applications[key]
	}

	@inlinable public func map<T>(_ transform: ((key: String, value: ComposeFileStatus)) throws -> T) throws -> [T] {
		return try applications.map(transform)
	}

	/// Atomically writes `value` for `key`.
	/// Re-reads disk state under the FileLock before writing so concurrent mutations
	/// to other keys (e.g. two simultaneous `compose up` for different projects) are
	/// preserved — the lock is held only for the duration of the read + write, never
	/// across long-running VM operations.
	public func upsert(_ key: String, _ value: ComposeFileStatus) throws {
		try lock.lock()
		defer { try? lock.unlock() }
		var onDisk: [String: ComposeFileStatus] = (try? Dictionary(contentsOf: url)) ?? [:]
		onDisk[key] = value
		try onDisk.write(to: url)
		self.applications = onDisk
	}

	/// Atomically removes `key` and writes the updated state back to disk.
	@discardableResult
	public func remove(_ key: String) throws -> Bool {
		try lock.lock()
		defer { try? lock.unlock() }
		var onDisk: [String: ComposeFileStatus] = (try? Dictionary(contentsOf: url)) ?? [:]
		let removed = onDisk.removeValue(forKey: key) != nil
		try onDisk.write(to: url)
		self.applications = onDisk
		return removed
	}
}

// MARK: - Polymorphic helpers

/// `depends_on` — either a plain list or a condition map.
public enum ComposeDepends: Codable {
	case list([String])
	case conditions([String: ComposeServiceCondition])

	public var serviceNames: [String] {
		switch self {
		case .list(let l): return l
		case .conditions(let m): return Array(m.keys).sorted()
		}
	}

	public init(from decoder: Decoder) throws {
		let c = try decoder.singleValueContainer()
		if let list = try? c.decode([String].self) { self = .list(list); return }
		if let map = try? c.decode([String: ComposeServiceCondition].self) { self = .conditions(map); return }
		self = .list([])
	}

	public func encode(to encoder: Encoder) throws {
		var c = encoder.singleValueContainer()
		switch self {
		case .list(let l): try c.encode(l)
		case .conditions(let m): try c.encode(m)
		}
	}
}

public struct ComposeServiceCondition: Codable {
	public var condition: String?
}

/// `environment` — list of "KEY=VALUE" strings or key/value map.
public enum ComposeEnvironment: Codable {
	case list([String])
	case map([String: String?])

	public var lines: [String] {
		switch self {
		case .list(let l): return l
		case .map(let m): return m.sorted(by: { $0.key < $1.key }).map { k, v in v.map { "\(k)=\($0)" } ?? "\(k)=" }
		}
	}

	public init(from decoder: Decoder) throws {
		let c = try decoder.singleValueContainer()
		if let list = try? c.decode([String].self) { self = .list(list); return }
		if let map = try? c.decode([String: String?].self) { self = .map(map); return }
		self = .list([])
	}

	public func encode(to encoder: Encoder) throws {
		var c = encoder.singleValueContainer()
		switch self {
		case .list(let l): try c.encode(l)
		case .map(let m): try c.encode(m)
		}
	}
}

/// Port mapping — short string `"host:container[/proto]"` or long mapping form.
public enum ComposePort: Codable {
	case short(String)
	case long(ComposePortLong)

	public var portString: String? {
		switch self {
		case .short(let s): return s
		case .long(let l):
			guard let target = l.target else { return nil }
			if let published = l.published {
				let proto = l.protocol.map { "/\($0)" } ?? ""
				return "\(published):\(target)\(proto)"
			}
			return "\(target)"
		}
	}

	public init(from decoder: Decoder) throws {
		let c = try decoder.singleValueContainer()
		if let s = try? c.decode(String.self) { self = .short(s); return }
		if let n = try? c.decode(Int.self) { self = .short("\(n)"); return }
		if let l = try? c.decode(ComposePortLong.self) { self = .long(l); return }
		throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode port")
	}

	public func encode(to encoder: Encoder) throws {
		var c = encoder.singleValueContainer()
		switch self {
		case .short(let s): try c.encode(s)
		case .long(let l): try c.encode(l)
		}
	}
}

public struct ComposePortLong: Codable {
	public var target: Int?
	public var published: Int?
	public var `protocol`: String?
	public var mode: String?
}

/// Volume mount — short string `"host:container"` or long mapping form.
public enum ComposeVolume: Codable {
	case short(String)
	case long(ComposeVolumeLong)

	public var mountString: String? {
		switch self {
		case .short(let s): return s
		case .long(let l):
			guard let source = l.source, let target = l.target else { return nil }
			return "\(source):\(target)"
		}
	}

	public init(from decoder: Decoder) throws {
		let c = try decoder.singleValueContainer()
		if let s = try? c.decode(String.self) { self = .short(s); return }
		if let l = try? c.decode(ComposeVolumeLong.self) { self = .long(l); return }
		throw DecodingError.dataCorruptedError(in: c, debugDescription: "Cannot decode volume")
	}

	public func encode(to encoder: Encoder) throws {
		var c = encoder.singleValueContainer()
		switch self {
		case .short(let s): try c.encode(s)
		case .long(let l): try c.encode(l)
		}
	}
}

public struct ComposeVolumeLong: Codable {
	public var type: String?
	public var source: String?
	public var target: String?
	public var readonly: Bool?
}

// MARK: - Deploy / Resources

public struct ComposeDeploy: Codable {
	public var resources: ComposeResources?
	public var replicas: Int?
}

public struct ComposeResources: Codable {
	public var limits: ComposeResourceLimits?
	public var reservations: ComposeResourceLimits?
}

public struct ComposeResourceLimits: Codable {
	public var cpus: String?    // "2" or "2.0"
	public var memory: String?  // "2048M", "2G", "2048m", "2g"
}

// MARK: - Network config (top-level)

public struct ComposeNetwork: Codable {
	public enum SupportedDriver: String, Codable {
		case bridge // resolves to a real bridged/physical VM network attachment — see `bridgedAttachmentName(networkKey:)`
		case none
	}

	public var driver: SupportedDriver = .none
	public var external: Bool? = false // true: `name` (or the network's own key) already refers to an existing host interface
	public var name: String?

	public var driverOpts: [String: String]?

	/// Resolves the `BridgeAttachement.network` name a `driver: bridge` compose network attaches
	/// to. This is Apple's Virtualization.framework sense of "bridged" (a real host network
	/// interface), not Docker's own "bridge" driver sense (a private, host-only virtual switch) —
	/// caker has no equivalent of the latter, so `driver: bridge` here always means "attach the VM
	/// directly to a physical/bridged interface, or a real physical interface named `networkKey`."
	/// `name` (an explicit override, e.g. for `external: true`) wins if present; otherwise the
	/// network's own YAML key is used directly as a physical interface identifier/display name —
	/// except for the reserved key `"default"` (Docker Compose's own implicit-network convention,
	/// also `ComposeHandler.builtinNetworks`' historical sentinel), which maps to caker's own
	/// configured default bridged interface (`CakedKeyConfig.bridgedNetwork`), since there's no way
	/// to infer which specific host NIC a bare "default" network should bridge to, and requiring
	/// every compose file to hardcode one would break portability across hosts.
	public func bridgedAttachmentName(networkKey: String) -> String {
		if let name, name.isEmpty == false {
			return name
		}

		return networkKey == "default" ? "bridged" : networkKey
	}
}

// MARK: - Service

public struct ComposeService: Codable {
	public var image: String?
	public var ports: [ComposePort]?
	public var sockets: [String]?
	public var volumes: [ComposeVolume]?
	public var environment: ComposeEnvironment?
	public var networks: [String]?
	public var dependsOn: ComposeDepends?
	public var deploy: ComposeDeploy?
	public var restart: String?
	public var hostname: String?

	// Caker VM extensions (not in standard Docker Compose spec)
	public var disk: UInt64?        // GiB
	public var user: String?
	public var password: String?
	public var nested: Bool?
	public var autostart: Bool?
	public var packages: [String]?  // apt/dnf/apk/zypper package names, installed via cloud-init at build

	enum CodingKeys: String, CodingKey {
		case image, ports, sockets, volumes, environment, networks, deploy, restart, hostname
		case dependsOn = "depends_on"
		case disk, user, password, nested, autostart, packages
	}

	public init() {}

	/// Convert to `BuildOptions`. Environment variables and `packages` are both injected via the same
	/// cloud-init user-data document (`opts.userData`), since a VM only gets one — see the two
	/// sections collected right before it's written.
	/// `composeNetworks` is the parent `ComposeFile`'s top-level `networks:` section — needed so a
	/// service's own `networks: [name, ...]` list can be resolved against each name's `driver`/`name`
	/// definition (see `ComposeNetwork.bridgedAttachmentName(networkKey:)`) rather than being handed
	/// straight to `BridgeAttachement` as a raw string, which previously left a `driver: bridge`
	/// network — including the reserved `"default"` name every new compose project starts with —
	/// unable to ever resolve to a real network device: nothing here ever created a caker network,
	/// a physical interface, or the default bridged interface under that literal name, so the VM
	/// silently came up with no network attachment for it at all (`CakeConfig.collectNetworks` just
	/// logs a warning and drops the device).
	public func toBuildOptions(name: String, composeNetworks: [String: ComposeNetwork?]?) throws -> (options: BuildOptions, cleanup: [URL]) {
		let memoryMB = parseMemoryMB(deploy?.resources?.limits?.memory ?? "") ?? 2048
		var filesToClean: [URL] = []
		var mounts: [DirectorySharingAttachment] = []
		var ethernets: [BridgeAttachement] = []
		var tunnels: [TunnelAttachement] = ports?.compactMap {
			$0.portString
		}.compactMap {
			TunnelAttachement(argument: $0)
		} ?? []

		if let sockets {
			tunnels += sockets.compactMap {
				parseUnixSocketTunnel($0)
			}
		}

		if let volumes {
			mounts = try volumes.compactMap {
				$0.mountString
			}.compactMap {
				try DirectorySharingAttachment(parseFrom: $0)
			}
		}

		if let networks {
			ethernets = try networks.compactMap { networkName -> BridgeAttachement in
				let resolvedName: String

				if let networkDef = composeNetworks?[networkName].flatMap({ $0 }), networkDef.driver == .bridge {
					resolvedName = networkDef.bridgedAttachmentName(networkKey: networkName)
				} else {
					resolvedName = networkName
				}

				return try BridgeAttachement(parseFrom: resolvedName)
			}
		}

		var opts = BuildOptions(
			name: name,
			// use Double literals to avoid type-inference/parsing ambiguity
			cpu: UInt16(max(1.0, Double(deploy?.resources?.limits?.cpus ?? "2") ?? 2.0)),
			memory: memoryMB,
			diskSize: disk ?? 10,
			diskFormat: SupportedDiskFormat.defaultSupportedFormat,
			autostart: autostart ?? false,
			nested: nested ?? false,
			image: image ?? defaultUbuntuImage,
			forwardedPorts: tunnels,
			mounts: mounts,
			networks: ethernets
		)

		try opts.validateImageSource(remote: false)

		// `environment` and `packages` both need to reach the guest via the same cloud-init
		// user-data document — `BuildOptions.userData` is a single file path, so both are collected
		// into one set of top-level cloud-init keys and written together rather than each claiming
		// the slot independently (which would silently drop whichever one ran second).
		var cloudInitSections: [String] = []

		if let env = environment {
			let envLines = env.lines
			if !envLines.isEmpty {
				let indented = envLines.map { "        \($0)" }.joined(separator: "\n")
				cloudInitSections.append(
					"""
					write_files:
					  - path: /etc/environment
					    append: true
					    content: |
					\(indented)
					""")
			}
		}

		if let packages, packages.isEmpty == false {
			let packageList = packages.map { "  - \($0)" }.joined(separator: "\n")
			cloudInitSections.append("packages:\n\(packageList)")
		}

		if cloudInitSections.isEmpty == false {
			let cloudInit = cloudInitSections.joined(separator: "\n")

			let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
				.appendingPathComponent("compose-cloud-init-\(UUID().uuidString).yaml")

			try cloudInit.write(to: tempFile, atomically: true, encoding: .utf8)

			opts.userData = tempFile.path(percentEncoded: false)
			filesToClean.append(tempFile)
		}

		return (opts, filesToClean)
	}

	private func parseMemoryMB(_ s: String) -> UInt64? {
		let s = s.trimmingCharacters(in: .whitespaces).uppercased()
		if s.hasSuffix("GB") { return UInt64(s.dropLast(2)).map { $0 * 1024 } }
		if s.hasSuffix("G") { return UInt64(s.dropLast()).map { $0 * 1024 } }
		if s.hasSuffix("MB") { return UInt64(s.dropLast(2)) }
		if s.hasSuffix("M") { return UInt64(s.dropLast()) }
		if s.hasSuffix("KB") { return UInt64(s.dropLast(2)).map { $0 / 1024 } }
		if s.hasSuffix("K") { return UInt64(s.dropLast()).map { $0 / 1024 } }
		return UInt64(s)
	}
}

// MARK: - File

public struct ComposeFile: Codable {
	public static let filename = "compose.yml"
	public static let legacyFilenames = ["compose.yaml", "docker-compose.yml", "docker-compose.yaml"]

	public var name: String
	public var version: String?
	public var services: [String: ComposeService] = [:]
	public var networks: [String: ComposeNetwork?]?

	public init(name: String, services: [String: ComposeService] = [:]) {
		self.name = name
		self.services = services
	}

	// MARK: Load

	public static func load(from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> ComposeFile {
		let primary = directory.appendingPathComponent(filename)

		if FileManager.default.fileExists(atPath: primary.path(percentEncoded: false)) {
			return try load(fromFile: primary.path(percentEncoded: false))
		}

		for legacy in legacyFilenames {
			let url = directory.appendingPathComponent(legacy)
			if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
				return try load(fromFile: url.path(percentEncoded: false))
			}
		}

		throw ServiceError(String(format: String(localized: "No compose.yml found in %@"), directory.path(percentEncoded: false)))
	}

	public static func load(fromFile path: String) throws -> ComposeFile {
		let content = try String(contentsOfFile: path.expandingTildeInPath, encoding: .utf8)

		return try YAMLDecoder().decode(ComposeFile.self, from: content)
	}

	// MARK: Ordering

	public func resolvedServices(filter: [String] = []) throws -> [(name: String, service: ComposeService)] {
		if filter.isEmpty == false {
			let unknown = filter.filter { services[$0] == nil }

			if unknown.isEmpty == false {
				let errorMessage = unknown.count == 1 ? String(localized: "Unknown service") :	String(localized: "Unknown services")

				throw ServiceError("\(errorMessage): \(unknown.joined(separator: ", "))")
			}
		}

		let keys: [String] = filter.isEmpty ? services.keys.sorted() : filter

		return keys.compactMap {k in
			services[k].map {
				(k, $0)
			}
		}
	}

	/// Services sorted by `depends_on` (topological order). Throws on cycles or missing deps.
	public func startOrder(filter: [String] = []) throws -> [(name: String, service: ComposeService)] {
		let entries = try resolvedServices(filter: filter)

		guard entries.isEmpty == false else {
			return []
		}

		let entrySet = Set(entries.map { $0.name })
		var result: [(name: String, service: ComposeService)] = []
		var visited = Set<String>()
		var visiting = Set<String>()

		func visit(_ n: String, _ svc: ComposeService) throws {
			if visited.contains(n) {
				return
			}

			guard visiting.contains(n) == false else {
				throw ServiceError(String(format: String(localized: "Circular dependency involving '%@'"), n))
			}

			visiting.insert(n)

			for dep in svc.dependsOn?.serviceNames ?? [] {
				guard let depSvc = services[dep] else {
					throw ServiceError(String(format: String(localized: "'%@' depends_on '%@' which is not defined"), n, dep))
				}

				// Only follow transitive deps that are in the requested set to avoid
				// stopping/starting services the caller did not ask for.
				if entrySet.contains(dep) {
					try visit(dep, depSvc)
				}
			}

			visiting.remove(n)
			visited.insert(n)

			result.append((n, svc))
		}

		for (n, svc) in entries {
			try visit(n, svc)
		}

		return result
	}

	/// Reverse of `startOrder` — use for graceful shutdown.
	public func downOrder(filter: [String] = []) throws -> [(name: String, service: ComposeService)] {
		return Array(try startOrder(filter: filter).reversed())
	}

	// MARK: Template

	public static var template: String {
"""
# compose.yml — Caker multi-VM environment (docker compose compatible)
# Run `cakectl compose up` to start all services in depends_on order.
# Run `cakectl compose down` to stop them in reverse order.
# Run `cakectl compose ps` to show their status.
# Run `cakectl compose init` to regenerate this file.
name: template
services:
  app:
    image: ubuntu:24.04
    ports:
      - "3000:3000"
    # sockets:
    #   - "/tmp/docker.sock:/var/run/docker.sock"
    #   - "/tmp/host.sock:/tmp/guest.sock/udp"
    volumes:
      - ".:/workspace"
    environment:
      - NODE_ENV=production
    networks:
      - default
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2048M
    # Caker VM extensions:
    disk: 20          # GiB
    user: ubuntu
    password: ubuntu
    # packages:       # installed via cloud-init on first boot
    #   - git
    #   - curl

  database:
    image: ubuntu:24.04
    environment:
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: myapp
    networks:
      - default
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 4096M
    disk: 40
    user: ubuntu
    password: ubuntu
    depends_on:
      - app

networks:
  default:
    driver: bridge
"""
	}
}

extension ComposeReplyList.ComposeInfo {
	/// Best-effort reconstruction of a startable `ComposeFile` from what the registry still knows
	/// about this project (name + each service's image). None of the `ls`/`ps` RPCs return the
	/// original raw compose definition (ports/volumes/environment/networks/`depends_on`) back to the
	/// client once a project is registered, so this is the closest the `caker` GUI (sidebar "start"
	/// action, menu-bar quick actions, the Compose Editor's "edit" seed) can get to it without a
	/// dedicated new RPC — enough to re-run `compose up` and (re)start already-installed services.
	public func reconstructedComposeFile() -> ComposeFile {
		var compose = ComposeFile(name: self.name)

		for service in self.services.sorted(by: { $0.name < $1.name }) {
			var svc = ComposeService()

			svc.image = (service.image.isEmpty || service.image == "-") ? nil : service.image
			compose.services[service.name] = svc
		}

		return compose
	}
}
