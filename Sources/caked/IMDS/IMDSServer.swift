import CakedLib
import Foundation
import NIO
import Synchronization
import Vapor

// MARK: - IMDSv2 token store

private struct IMDSToken: Sendable {
	let value: String
	let expiresAt: Date

	var isValid: Bool { Date.now < expiresAt }
}

private final class TokenStore: Sendable {
	private let tokens: Mutex<[String: IMDSToken]> = Mutex([:])

	func create(ttlSeconds: Int) -> String {
		let clamped = max(1, min(ttlSeconds, 21600))
		let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
		let entry = IMDSToken(value: token, expiresAt: Date.now.addingTimeInterval(TimeInterval(clamped)))

		self.tokens.withLock { tokens in
			tokens[token] = entry
		}

		return token
	}

	func isValid(_ token: String) -> Bool {
		self.tokens.withLock { tokens in
			guard let entry = tokens[token] else { return false }

			if entry.isValid == false {
				tokens.removeValue(forKey: token)
				return false
			}

			return true
		}
	}
}

// MARK: - Metadata updated as the VM runs

public final class IMDSMetadata: Sendable {
	private let _localIPv4: Mutex<String> = Mutex("")

	/// The VM's MAC address on the shared IMDS host-only network (see `IMDSNetworkInterface`
	/// for the actual subnet). This is *not* a data-plane address — it's only used by
	/// `IMDSRegistry` to figure out, via the host's ARP cache, which currently-connected
	/// guest a given metadata request came from (all Linux VMs on a host share the same
	/// "imds" virtual switch and gateway).
	public let imdsMac: String

	public let instanceID: String
	public let hostname: String
	public let mac: String
	public let instanceType: String
	public let networks: [(mac: String, name: String)]

	public var localIPv4: String {
		get { self._localIPv4.withLock { $0 } }
		set { self._localIPv4.withLock { $0 = newValue } }
	}

	public init(config: CakeConfig, locationName: String, imdsMac: String) {
		self.imdsMac = imdsMac
		self.instanceID = config.instanceID
		self.hostname = locationName
		self.mac = config.macAddress ?? ""
		self.instanceType = "caker.\(config.cpuCount)xlarge"

		let qualified = config.qualifiedNetworks
		self.networks = qualified.compactMap { net in
			guard let mac = net.macAddress ?? config.macAddress else { return nil }
			return (mac: mac, name: net.network)
		}
	}
}

// MARK: - Registry of the VMs currently served by the shared IMDS server

/// Every Linux VM on the host shares a single host-only "imds" vmnet virtual switch (see
/// `IMDSNetworkInterface` in `NetworkAttachement.swift` for the actual subnet/gateway):
/// its `networkName` is the fixed literal `"imds"` for every VM, so the first VM to attach
/// spawns the vmnet host process and every other VM's attachment simply connects to that
/// same running process as a client. There is therefore exactly one IMDS network segment
/// per host, not one per VM, and binding one process-wide HTTP server to
/// `IMDSServer.bindAddress:bindPort` is correct and sufficient for any number of
/// concurrently-running Linux VMs — there's no per-VM isolated switch to disambiguate with
/// interface-scoped binding.
///
/// What *does* need disambiguating is which VM a given HTTP request came from, since they all
/// arrive on the same listener. We resolve that from the request's source IP by cross
/// referencing the host's ARP cache (`ARPResolver`) against each registered VM's IMDS-network
/// MAC address (`imdsMac`, persisted as `CakeConfig.imdsMacAddress`).
public final class IMDSRegistry: Sendable {
	private struct Entry: Sendable {
		let imdsMac: String
		let metadata: IMDSMetadata
	}

	private let entries: Mutex<[String: Entry]> = Mutex([:])

	public init() {}

	public var isEmpty: Bool {
		self.entries.withLock { $0.isEmpty }
	}

	public func register(name: String, metadata: IMDSMetadata) {
		self.entries.withLock { $0[name] = Entry(imdsMac: metadata.imdsMac, metadata: metadata) }
	}

	@discardableResult
	public func unregister(name: String) -> Bool {
		self.entries.withLock { $0.removeValue(forKey: name) != nil }
	}

	/// Looks up which registered VM currently owns `remoteIP` on the IMDS network, by
	/// resolving each candidate's `imdsMac` through the host's ARP cache.
	public func metadata(forRemoteIP remoteIP: String) -> IMDSMetadata? {
		let snapshot = self.entries.withLock { $0 }

		for entry in snapshot.values {
			if ARPResolver.ipAddress(forMACAddress: entry.imdsMac) == remoteIP {
				return entry.metadata
			}
		}

		return nil
	}
}

// MARK: - IMDSv2 token authorization

/// Applied only to the `latest/meta-data` route group — `PUT /latest/api/token`
/// (where a token is obtained) is registered outside this group and stays unguarded.
private struct IMDSAuthMiddleware: Middleware {
	let tokens: TokenStore

	func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		guard let token = request.headers.first(name: "X-aws-ec2-metadata-token") else {
			// IMDSv1: no token required
			return next.respond(to: request)
		}

		guard tokens.isValid(token) else {
			return request.eventLoop.makeSucceededFuture(Response(status: .unauthorized))
		}

		return next.respond(to: request)
	}
}

// MARK: - Per-request VM resolution

private struct IMDSMetadataKey: StorageKey {
	typealias Value = IMDSMetadata
}

extension Request {
	/// Set by `IMDSResolverMiddleware` before any `latest/meta-data` handler runs; every
	/// handler downstream of that middleware can assume this is present.
	fileprivate var imdsMetadata: IMDSMetadata? {
		self.storage[IMDSMetadataKey.self]
	}
}

/// Resolves which VM a request came from exactly once per request (instead of once per
/// handler), and off the NIO event loop: `IMDSRegistry.metadata(forRemoteIP:)` does an ARP
/// cache lookup that can shell out to `/usr/sbin/arp` on a cache miss, which would otherwise
/// block the event loop thread handling this (and every other multiplexed) connection.
/// Runs after `IMDSAuthMiddleware` so an invalid token still gets 401 rather than 404.
private struct IMDSResolverMiddleware: AsyncMiddleware {
	let registry: IMDSRegistry

	/// A guest's ARP entry may not have populated on the host yet right after boot (it's
	/// only learned once the guest sends a packet), which would otherwise show up as an
	/// immediate 404 indistinguishable from "IMDS isn't running" — and cloud-init only
	/// retries IMDS for a short, bounded window. A few short retries here (entirely via
	/// suspension, not blocking anything) closes most of that race without needing a
	/// different VM-identification mechanism.
	static let maxAttempts = 3
	static let retryDelayNanoseconds: UInt64 = 300_000_000

	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		guard let remoteIP = request.remoteAddress?.ipAddress else {
			return Response(status: .notFound)
		}

		var metadata: IMDSMetadata?

		for attempt in 1...Self.maxAttempts {
			metadata = try? await request.application.threadPool.runIfActive {
				registry.metadata(forRemoteIP: remoteIP)
			}

			if metadata != nil || attempt == Self.maxAttempts {
				break
			}

			try? await Task.sleep(nanoseconds: Self.retryDelayNanoseconds)
		}

		guard let metadata else {
			return Response(status: .notFound)
		}

		request.storage[IMDSMetadataKey.self] = metadata

		return try await next.respond(to: request)
	}
}

// MARK: - Vapor IMDS server

/// HTTP server that implements IMDSv1 and IMDSv2 for the IMDS host network (see
/// `IMDSNetworkInterface` for the subnet/gateway).
///
/// Always binds on the gateway address — guests can always reach it there, with no
/// privilege or `pf` redirect required, since binding an unprivileged port is always
/// possible. Whether the *port* is 80 (the AWS-style, guest-documented default) depends on
/// privilege:
/// - Running as root (`caked service listen --system`), it binds `bindAddress:bindPort`
///   (port 80) directly — nothing else needed.
/// - Running unprivileged (the common case, including sandboxed builds), it can't `bind()`
///   port 80, so it binds `bindAddress:internalPort` instead — still directly reachable
///   from the guest, just on a non-standard port. `needsPFRedirect` tells the caller
///   (`IMDSCoordinator`) that *additionally* exposing the standard `bindAddress:bindPort`
///   would need a `pf` redirect (`PFRedirect`, via a short-lived root helper) — an optional
///   convenience for guest tooling that hardcodes port 80, not a requirement for guests to
///   reach IMDS at all.
public final class IMDSServer: Sendable {
	private let app: Application

	public static let bindAddress = IMDSNetworkInterface.imdsGateway
	public static let bindPort = 80

	public static let internalBindPort = 28080

	/// True when this bound on `internalPort` rather than `bindPort` (80) directly, meaning
	/// a `pf` redirect is needed for the guest to additionally reach it on the standard
	/// port 80 — IMDS is already reachable at `bindAddress:internalPort` either way.
	public let needsPFRedirect: Bool

	/// The port actually used when running unprivileged (matches `internalBindPort` unless
	/// the caller overrode it, e.g. via `caked service listen --imds-port`). Always
	/// `bindPort` (80) when running as root.
	public let internalPort: Int

	/// One server serves every currently-running Linux VM: they all share the same IMDS
	/// virtual network (see `IMDSRegistry` doc comment), so `registry` is consulted per
	/// request to figure out which VM's metadata to answer with. `internalPort` is only
	/// used when running unprivileged (see the type doc comment) — ignored when root.
	public init(group: EventLoopGroup, registry: IMDSRegistry, internalPort: Int = IMDSServer.internalBindPort) async throws {
		let env = try Environment.current()
		let app = try await Application.make(env, .shared(group))
		let runningAsRoot = geteuid() == 0

		app.http.server.configuration.hostname = Self.bindAddress

		if runningAsRoot {
			app.http.server.configuration.port = Self.bindPort
			self.internalPort = Self.bindPort
		} else {
			app.http.server.configuration.port = internalPort
			self.internalPort = internalPort
		}

		app.logger.logLevel = .warning

		self.needsPFRedirect = runningAsRoot == false

		let tokens = TokenStore()
		Self.registerRoutes(on: app, registry: registry, tokens: tokens)

		self.app = app
	}

	public func start() throws {
		try app.start()
	}

	/// Retries `start()` with a fixed delay until it succeeds or `maxAttempts` is reached.
	/// Cooperatively cancellable — callers should cancel the enclosing `Task` (rather than
	/// letting it run unmanaged) before tearing the server down with `shutdown()`.
	public func startWithRetry(maxAttempts: Int = 20, retryDelayNanoseconds: UInt64 = 500_000_000) async throws {
		var attempts = 0

		while true {
			try Task.checkCancellation()

			do {
				try start()
				return
			} catch {
				attempts += 1

				if attempts >= maxAttempts {
					throw error
				}

				try await Task.sleep(nanoseconds: retryDelayNanoseconds)
			}
		}
	}

	public func shutdown() async {
		try? await app.asyncShutdown()
	}

	// MARK: - Route registration

	private static func registerRoutes(on app: Application, registry: IMDSRegistry, tokens: TokenStore) {
		// IMDSv2: obtain a session token via PUT. Not gated by IMDSAuthMiddleware — this is
		// the endpoint used to obtain a token in the first place.
		app.put("latest", "api", "token") { req -> Response in
			guard let ttlHeader = req.headers.first(name: "X-aws-ec2-metadata-token-ttl-seconds") else {
				let token = tokens.create(ttlSeconds: 21600)
				return plainText(token, on: req)
			}

			guard let ttl = Int(ttlHeader), ttl > 0 else {
				return Response(status: .badRequest)
			}

			let token = tokens.create(ttlSeconds: ttl)
			return plainText(token, on: req)
		}

		// Auth first (401 for an invalid/missing v2 token), then resolve which VM the
		// request is from (404 if unresolvable) — every handler below can assume
		// `req.imdsMetadata` is present.
		let meta = app.grouped("latest", "meta-data")
			.grouped(IMDSAuthMiddleware(tokens: tokens))
			.grouped(IMDSResolverMiddleware(registry: registry))

		meta.get { req -> Response in
			let keys = """
				ami-id
				ami-launch-index
				hostname
				instance-id
				instance-type
				local-hostname
				local-ipv4
				mac
				network/
				placement/
				"""
			return plainText(keys, on: req)
		}

		meta.get("instance-id") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			return plainText(metadata.instanceID, on: req)
		}

		meta.get("hostname") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			return plainText("\(metadata.hostname).caker.local", on: req)
		}

		meta.get("local-hostname") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			return plainText("\(metadata.hostname).caker.local", on: req)
		}

		meta.get("local-ipv4") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			return plainText(metadata.localIPv4, on: req)
		}

		meta.get("mac") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			return plainText(metadata.mac, on: req)
		}

		meta.get("ami-id") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			let suffix = String(metadata.instanceID.suffix(8)).lowercased()
			return plainText("ami-\(suffix)", on: req)
		}

		meta.get("ami-launch-index") { req -> Response in
			plainText("0", on: req)
		}

		meta.get("instance-type") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			return plainText(metadata.instanceType, on: req)
		}

		// Placement
		meta.get("placement") { req -> Response in
			plainText("availability-zone\nregion", on: req)
		}

		meta.get("placement", "availability-zone") { req -> Response in
			plainText("caker-1a", on: req)
		}

		meta.get("placement", "region") { req -> Response in
			plainText("caker-1", on: req)
		}

		// Network interfaces / MACs
		let macsBase = meta.grouped("network", "interfaces", "macs")

		macsBase.get { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			let list = metadata.networks.map { "\($0.mac)/" }.joined(separator: "\n")
			return plainText(list, on: req)
		}

		macsBase.get(":mac") { req -> Response in
			plainText("local-ipv4s\nsubnet-ipv4-cidr-block\nvpc-id", on: req)
		}

		macsBase.get(":mac", "local-ipv4s") { req -> Response in
			guard let metadata = req.imdsMetadata else { return Response(status: .notFound) }
			return plainText(metadata.localIPv4, on: req)
		}

		macsBase.get(":mac", "subnet-ipv4-cidr-block") { req -> Response in
			plainText(IMDSNetworkInterface.imdsSubnetCIDR, on: req)
		}

		macsBase.get(":mac", "vpc-id") { req -> Response in
			plainText("vpc-caker", on: req)
		}
	}

	private static func plainText(_ body: String, on req: Request) -> Response {
		let response = Response(status: .ok, body: .init(string: body))
		response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
		return response
	}
}
