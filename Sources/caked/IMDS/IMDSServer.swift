import CakedLib
import Foundation
import NIO
import Vapor

// MARK: - IMDSv2 token store

private struct IMDSToken: Sendable {
	let value: String
	let expiresAt: Date

	var isValid: Bool { Date.now < expiresAt }
}

private final class TokenStore: @unchecked Sendable {
	private var tokens: [String: IMDSToken] = [:]
	private let lock = NSLock()

	func create(ttlSeconds: Int) -> String {
		let clamped = max(1, min(ttlSeconds, 21600))
		let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
		let entry = IMDSToken(value: token, expiresAt: Date.now.addingTimeInterval(TimeInterval(clamped)))

		lock.lock()
		defer { lock.unlock() }
		tokens = tokens.filter { $0.value.isValid }
		tokens[token] = entry

		return token
	}

	func isValid(_ token: String) -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return tokens[token]?.isValid ?? false
	}
}

// MARK: - Metadata updated as the VM runs

public final class IMDSMetadata: @unchecked Sendable {
	private let lock = NSLock()
	private var _localIPv4: String = ""

	public let instanceID: String
	public let hostname: String
	public let mac: String
	public let instanceType: String
	public let networks: [(mac: String, name: String)]

	public var localIPv4: String {
		get {
			lock.lock(); defer { lock.unlock() }
			return _localIPv4
		}
		set {
			lock.lock(); defer { lock.unlock() }
			_localIPv4 = newValue
		}
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

	public func shutdown() async {
		try? await app.asyncShutdown()
	}

	// MARK: - Route registration

	private static func registerRoutes(on app: Application, metadata: IMDSMetadata, tokens: TokenStore) {
		// IMDSv2: obtain a session token via PUT
		app.put("latest", "api", "token") { req -> Response in
			let ttl = Int(req.headers.first(name: "X-aws-ec2-metadata-token-ttl-seconds") ?? "21600") ?? 21600
			let token = tokens.create(ttlSeconds: ttl)
			return plainText(token, on: req)
		}

		func authorized(_ req: Request) -> Bool {
			guard let token = req.headers.first(name: "X-aws-ec2-metadata-token") else {
				return true  // IMDSv1: no token required
			}
			return tokens.isValid(token)
		}

		let meta = app.grouped("latest", "meta-data")

		meta.get { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
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
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText(metadata.instanceID, on: req)
		}

		meta.get("hostname") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("\(metadata.hostname).caker.local", on: req)
		}

		meta.get("local-hostname") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("\(metadata.hostname).caker.local", on: req)
		}

		meta.get("local-ipv4") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText(metadata.localIPv4, on: req)
		}

		meta.get("mac") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText(metadata.mac, on: req)
		}

		meta.get("ami-id") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			let suffix = String(metadata.instanceID.suffix(8)).lowercased()
			return plainText("ami-\(suffix)", on: req)
		}

		meta.get("ami-launch-index") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("0", on: req)
		}

		meta.get("instance-type") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText(metadata.instanceType, on: req)
		}

		// Placement
		meta.get("placement") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("availability-zone\nregion", on: req)
		}

		meta.get("placement", "availability-zone") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("caker-1a", on: req)
		}

		meta.get("placement", "region") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("caker-1", on: req)
		}

		// Network interfaces / MACs
		let macsBase = meta.grouped("network", "interfaces", "macs")

		macsBase.get { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			let list = metadata.networks.map { "\($0.mac)/" }.joined(separator: "\n")
			return plainText(list, on: req)
		}

		macsBase.get(":mac") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("local-ipv4s\nsubnet-ipv4-cidr-block\nvpc-id", on: req)
		}

		macsBase.get(":mac", "local-ipv4s") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText(metadata.localIPv4, on: req)
		}

		macsBase.get(":mac", "subnet-ipv4-cidr-block") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("169.254.169.0/24", on: req)
		}

		macsBase.get(":mac", "vpc-id") { req -> Response in
			guard authorized(req) else { return Response(status: .unauthorized) }
			return plainText("vpc-caker", on: req)
		}
	}

	private static func plainText(_ body: String, on req: Request) -> Response {
		let response = Response(status: .ok, body: .init(string: body))
		response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
		return response
	}
}
