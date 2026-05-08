//
//  LXDRESTServer.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib
import NIO
import NIOSSL
import Security
import Vapor
import X509

extension TLSConfiguration {
	static public func makeServerConfiguration(caCert: String? = nil, tlsKey: String, tlsCert: String) throws -> TLSConfiguration {
		let tlsCerts = try NIOSSLCertificate.fromPEMFile(tlsCert)
		let tlsKey = try NIOSSLPrivateKey(file: tlsKey, format: .pem)
		var tlsConfiguration: TLSConfiguration

		if let caCert = caCert {
			// When a CA is provided, use it for trust and require full client cert verification (mTLS)
			tlsConfiguration = TLSConfiguration.makeServerConfiguration(
				certificateChain: [.certificate(tlsCerts.first!)],
				privateKey: .privateKey(tlsKey)
			)

			tlsConfiguration.certificateVerification = CertificateVerification.optionalVerification
			tlsConfiguration.trustRoots = .certificates(try NIOSSLCertificate.fromPEMFile(caCert))
		} else {
			// No CA provided: do not verify client certificates (server-only TLS)
			tlsConfiguration = TLSConfiguration.makeServerConfiguration(
				certificateChain: [.certificate(tlsCerts.first!)],
				privateKey: .privateKey(tlsKey)
			)
		}

		return tlsConfiguration
	}
}

extension Environment {
	static func current() throws -> Environment {
		var env: Environment

		#if DEBUG
			env = .development
		#else
			env = .production
		#endif

		env.commandInput = CommandInput(arguments: [ProcessInfo.processInfo.arguments.first!, "serve"])

		return env
	}
}

/// Middleware that requires a valid TLS client certificate when enabled.
/// If no client certificate is presented, the request is rejected with 401.
private struct CertificateAuthMiddleware: Middleware {
	let trustRoots: [NIOSSLCertificate]

	init(caCert: String) throws {
		self.trustRoots = try NIOSSLCertificate.fromPEMFile(caCert)
	}

	/// Returns true if every certificate in `chain` validates against at least one of the provided `trustRoots`
	/// using the system's X.509 basic evaluation policy.
	func peerChainIsTrusted(_ chain: X509.ValidatedCertificateChain) -> Bool {
		guard let chain = try? chain.compactMap( {
			try NIOSSLCertificate(bytes: $0.serializeAsPEM().derBytes, format: .der)
		}) else {
			return false
		}

		return Self.peerChainIsTrusted(chain, trustRoots: self.trustRoots)
	}

	func peerChainIsTrusted(_ chain: [NIOSSLCertificate]) -> Bool {
		return Self.peerChainIsTrusted(chain, trustRoots: self.trustRoots)
	}

	/// Returns true if every certificate in `chain` validates against at least one of the provided `trustRoots`
	/// using the system's X.509 basic evaluation policy.
	static func peerChainIsTrusted(_ chain: [NIOSSLCertificate], trustRoots: [NIOSSLCertificate]) -> Bool {
		let secChain: [SecCertificate] = chain.compactMap { cert in
			guard let der = try? cert.toDERBytes() else { return nil }
			return SecCertificateCreateWithData(nil, Data(der) as CFData)
		}
		let secRoots: [SecCertificate] = trustRoots.compactMap { cert in
			guard let der = try? cert.toDERBytes() else { return nil }
			return SecCertificateCreateWithData(nil, Data(der) as CFData)
		}

		guard !secChain.isEmpty, !secRoots.isEmpty else { return false }

		var trust: SecTrust?
		guard SecTrustCreateWithCertificates(secChain as CFArray, SecPolicyCreateBasicX509(), &trust) == errSecSuccess,
			let trust
		else { return false }

		SecTrustSetAnchorCertificates(trust, secRoots as CFArray)
		SecTrustSetAnchorCertificatesOnly(trust, true)

		return SecTrustEvaluateWithError(trust, nil)
	}

	func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		if let chain = request.peerCertificateChain, chain.isEmpty == false,
		   self.peerChainIsTrusted(chain)
		{
			return next.respond(to: request)
		}

		let response = Response(status: .unauthorized)
		response.headers.replaceOrAdd(name: .wwwAuthenticate, value: "TLS-Certificate realm=\"Caker\"")
		return request.eventLoop.makeSucceededFuture(response)
	}
}

/// Password middleware that validates a Bearer token or HTTP Basic credentials against a single shared secret.
/// The username in Basic auth is ignored — only the password is checked.
/// If the client presents a valid TLS client certificate, the password check is bypassed.
private struct PasswordAuthMiddleware: Middleware {
	let password: String

	func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		// Allow mTLS-authenticated clients to skip password check
		if let peerCertificateChain = request.peerCertificateChain, peerCertificateChain.isEmpty == false {
			return next.respond(to: request)
		}

		guard let authHeader = request.headers.first(name: .authorization) else {
			return unauthorized(on: request)
		}

		let parts = authHeader.split(separator: " ", maxSplits: 1)
		guard parts.count == 2 else {
			return unauthorized(on: request)
		}

		let scheme = parts[0].lowercased()
		let credentials = String(parts[1])

		switch scheme {
		case "bearer":
			// Expecting: "Bearer base64(pass-phrase)"
			let token = credentials.base64DecodedString()
			guard token.isEmpty == false, token == password else {
				return unauthorized(on: request)
			}
		case "basic":
			// Expecting: "Basic base64(username:password)"
			let decoded = credentials.base64DecodedString()
			// Username is ignored — only the password (after the first ':') is validated
			let colonIdx = decoded.firstIndex(of: ":") ?? decoded.endIndex
			let providedPassword = String(decoded[decoded.index(after: colonIdx)...])
			guard providedPassword.isEmpty == false, providedPassword == password else {
				return unauthorized(on: request)
			}
		default:
			return unauthorized(on: request)
		}

		return next.respond(to: request)
	}

	private func unauthorized(on request: Request) -> EventLoopFuture<Response> {
		let response = Response(status: .unauthorized)
		response.headers.replaceOrAdd(name: .wwwAuthenticate, value: "Basic realm=\"Caker\"")
		response.headers.add(name: .wwwAuthenticate, value: "Bearer realm=\"Caker\"")
		return request.eventLoop.makeSucceededFuture(response)
	}
}

/// Extracts a `.zip` archive to a temporary directory and returns the extracted root path.
/// If `path` does not end in `.zip`, it is returned unchanged.
private func resolveWebUIDirectory(_ path: String) throws -> String {
	let path = path.expandingTildeInPath

	guard path.lowercased().hasSuffix(".zip") else { return path }

	let tmpDir = FileManager.default.temporaryDirectory
		.appendingPathComponent("caker-webui-\(UUID().uuidString)")
	try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

	let process = Process()
	process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
	process.arguments = ["-q", path, "-d", tmpDir.path]
	process.standardOutput = Pipe()
	let errPipe = Pipe()
	process.standardError = errPipe
	try process.run()
	process.waitUntilExit()

	guard process.terminationStatus == 0 else {
		let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		throw ServiceError("Failed to extract web UI zip: \(msg.trimmingCharacters(in: .whitespacesAndNewlines))")
	}

	// Descend into a single top-level directory if present (e.g. dist/)
	if let contents = try? FileManager.default.contentsOfDirectory(atPath: tmpDir.path),
	   contents.count == 1
	{
		let candidate = tmpDir.appendingPathComponent(contents[0]).path
		var isDir: ObjCBool = false
		if FileManager.default.fileExists(atPath: candidate, isDirectory: &isDir), isDir.boolValue {
			return candidate
		}
	}

	return tmpDir.path
}

/// Wraps a Vapor Application providing LXD-compatible REST server lifecycle.
final class LXDRESTServer: Sendable {
	private let app: Application

	/// Creates and configures the Vapor application but does not start it.
	init(group: MultiThreadedEventLoopGroup, listen: URL, caCert: String?, tlsCert: String?, tlsKey: String?, runMode: Utils.RunMode, webUIDirectory: String? = nil) async throws {
		let logger = Logger(label: "LXDRESTServer")
		let app = try await Application.make(Environment.current(), .shared(group), logger: logger)

		// Configure JSON encoder/decoder for LXD snake_case + ISO8601 dates
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .useDefaultKeys
		encoder.dateEncodingStrategy = .iso8601

		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .useDefaultKeys
		decoder.dateDecodingStrategy = .iso8601

		ContentConfiguration.global.use(encoder: encoder, for: .json)
		ContentConfiguration.global.use(decoder: decoder, for: .json)

		// Add Bearer/Basic password protection if a password is provided
		if let password = listen.password(percentEncoded: false), password.isEmpty == false {
			app.middleware.use(PasswordAuthMiddleware(password: password))
		}

		guard let hostname = listen.host(percentEncoded: false), let port = listen.port else {
			throw ServiceError("Invalid listen URL: host or port missing")
		}

		var serverConfiguration = app.http.server.configuration

		serverConfiguration.hostname = hostname
		serverConfiguration.port = port

		if let tlsCert = tlsCert, let tlsKey = tlsKey {
			serverConfiguration.tlsConfiguration = try TLSConfiguration.makeServerConfiguration(caCert: caCert, tlsKey: tlsKey, tlsCert: tlsCert)

			if let caCert = caCert {
				let authMiddleware = try CertificateAuthMiddleware(caCert: caCert)

				app.middleware.use(authMiddleware)

				serverConfiguration.customCertificateVerifyCallbackWithMetadata = { peerCerts, successPromise in
					successPromise.succeed(.certificateVerified(VerificationMetadata(ValidatedCertificateChain(peerCerts))))
				}
			}
		}

		app.http.server.configuration = serverConfiguration

		// Disable default Vapor console logging to avoid noise (use caked's logger)
		app.logger.logLevel = CakeAgentLib.Logger.LoggingLevel()

		// Restore persisted state for all LXD stores
		try await LXDAuthGroupStore.shared.configure(runMode: runMode)
		try await LXDIdentityStore.shared.configure(runMode: runMode)
		try await LXDCertificateStore.shared.configure(runMode: runMode)
		try await LXDOperationStore.shared.configure(runMode: runMode)

		// Register LXD routes
		try registerLXDRoutes(app, runMode: runMode)

		// Serve web UI static files under /ui if a directory (or zip archive) was provided
		if let rawWebUIDir = webUIDirectory {
			let webUIDir = try resolveWebUIDirectory(rawWebUIDir)
			app.get { req -> Response in
				return req.redirect(to: "/ui", redirectType: .permanent)
			}
			app.get("ui") { req async throws -> Response in
				return try await req.fileio.asyncStreamFile(at: webUIDir + "/index.html")
			}
			app.get("ui", "**") { req async throws -> Response in
				let components = req.parameters.getCatchall()
				let relativePath = components.joined(separator: "/")
				let filePath = webUIDir + "/" + relativePath
				var isDir: ObjCBool = false
				if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue {
					return try await req.fileio.asyncStreamFile(at: filePath)
				}
				return try await req.fileio.asyncStreamFile(at: webUIDir + "/index.html")
			}
		}

		self.app = app
	}

	/// Starts the HTTP server (non-blocking).
	func start() throws {
		try app.start()
	}

	/// Shuts down the HTTP server and releases resources.
	func shutdown() async {
		try? await app.asyncShutdown()
	}
}
