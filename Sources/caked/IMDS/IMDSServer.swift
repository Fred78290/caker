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

	public let instanceID: String
	public let hostname: String
	public let mac: String
	public let instanceType: String
	public let networks: [(mac: String, name: String)]

	public var localIPv4: String {
		get { self._localIPv4.withLock { $0 } }
		set { self._localIPv4.withLock { $0 = newValue } }
	}

	public init(config: CakeConfig, locationName: String) {
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

// MARK: - Vapor IMDS server

/// HTTP server that implements IMDSv1 and IMDSv2 on the IMDS host network (169.254.169.0/24).
/// Binds exclusively to 169.254.169.1:80 so only guests on that network can reach it.
public final class IMDSServer: Sendable {
	private let app: Application

	public static let bindAddress = "169.254.169.1"
	public static let bindPort = 80

	public init(group: EventLoopGroup, metadata: IMDSMetadata) async throws {
		let env = try Environment.current()
		let app = try await Application.make(env, .shared(group))

		app.http.server.configuration.hostname = Self.bindAddress
		app.http.server.configuration.port = Self.bindPort
		app.logger.logLevel = .warning

		let tokens = TokenStore()
		Self.registerRoutes(on: app, metadata: metadata, tokens: tokens)

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

	private static func registerRoutes(on app: Application, metadata: IMDSMetadata, tokens: TokenStore) {
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

		let meta = app.grouped("latest", "meta-data").grouped(IMDSAuthMiddleware(tokens: tokens))

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
			plainText(metadata.instanceID, on: req)
		}

		meta.get("hostname") { req -> Response in
			plainText("\(metadata.hostname).caker.local", on: req)
		}

		meta.get("local-hostname") { req -> Response in
			plainText("\(metadata.hostname).caker.local", on: req)
		}

		meta.get("local-ipv4") { req -> Response in
			plainText(metadata.localIPv4, on: req)
		}

		meta.get("mac") { req -> Response in
			plainText(metadata.mac, on: req)
		}

		meta.get("ami-id") { req -> Response in
			let suffix = String(metadata.instanceID.suffix(8)).lowercased()
			return plainText("ami-\(suffix)", on: req)
		}

		meta.get("ami-launch-index") { req -> Response in
			plainText("0", on: req)
		}

		meta.get("instance-type") { req -> Response in
			plainText(metadata.instanceType, on: req)
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
			let list = metadata.networks.map { "\($0.mac)/" }.joined(separator: "\n")
			return plainText(list, on: req)
		}

		macsBase.get(":mac") { req -> Response in
			plainText("local-ipv4s\nsubnet-ipv4-cidr-block\nvpc-id", on: req)
		}

		macsBase.get(":mac", "local-ipv4s") { req -> Response in
			plainText(metadata.localIPv4, on: req)
		}

		macsBase.get(":mac", "subnet-ipv4-cidr-block") { req -> Response in
			plainText("169.254.169.0/24", on: req)
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
