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

		guard let leafCert = tlsCerts.first else {
			throw NIOSSLError.failedToLoadCertificate
		}

		var tlsConfiguration: TLSConfiguration

		if let caCert = caCert {
			// When a CA is provided, use it for trust and require full client cert verification (mTLS)
			tlsConfiguration = TLSConfiguration.makeServerConfiguration(
				certificateChain: [.certificate(leafCert)],
				privateKey: .privateKey(tlsKey)
			)

			tlsConfiguration.certificateVerification = CertificateVerification.optionalVerification
			tlsConfiguration.trustRoots = .certificates(try NIOSSLCertificate.fromPEMFile(caCert))
		} else {
			// No CA provided: do not verify client certificates (server-only TLS)
			tlsConfiguration = TLSConfiguration.makeServerConfiguration(
				certificateChain: [.certificate(leafCert)],
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

/// Set by PasswordAuthMiddleware on the request after successful credential validation.
/// CertificateAuthMiddleware reads this to skip its own challenge for already-authenticated requests.
private enum PasswordAuthenticatedKey: StorageKey {
	typealias Value = Bool
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
	func peerChainIsTrusted(_ chain: X509.ValidatedCertificateChain) async -> Bool {
		guard await LXDCertificateStore.shared.peerChainIsTrusted(chain) == false else {
			return true
		}

		guard let chain = try? chain.compactMap( {
			try NIOSSLCertificate(bytes: $0.serializeAsPEM().derBytes, format: .der)
		}) else {
			return false
		}

		return Self.peerChainIsTrusted(chain, trustRoots: self.trustRoots)
	}

	private func peerChainIsTrusted(_ chain: [NIOSSLCertificate]) -> Bool {
		return Self.peerChainIsTrusted(chain, trustRoots: self.trustRoots)
	}

	/// Returns true if every certificate in `chain` validates against at least one of the provided `trustRoots`
	/// using the system's X.509 basic evaluation policy.
	private static func peerChainIsTrusted(_ chain: [NIOSSLCertificate], trustRoots: [NIOSSLCertificate]) -> Bool {
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
		// Web UI static assets do not require a client certificate.
		let path = request.url.path
		if path == "/" || path.hasPrefix("/ui") {
			return next.respond(to: request)
		}

		// Password auth already granted access — no need to also require a client certificate.
		if request.storage[PasswordAuthenticatedKey.self] == true {
			return next.respond(to: request)
		}

		// Operation WebSocket upgrades use their own one-time secret token (see PasswordAuthMiddleware).
		if path.hasPrefix("/1.0/operations/"), path.hasSuffix("/websocket") {
			return next.respond(to: request)
		}

		if let chain = request.peerCertificateChain, chain.isEmpty == false {
			// Bridge to async for actor-isolated trust check, then hop back to the event loop
			let promise = request.eventLoop.makePromise(of: Response.self)

			Task {
				let trusted = await self.peerChainIsTrusted(chain)

				if trusted {
					let response = try await next.respond(to: request).get()
					promise.succeed(response)
				} else {
					let response = Response(status: .unauthorized)
					response.headers.replaceOrAdd(name: .wwwAuthenticate, value: "TLS-Certificate realm=\"Caker\"")
					promise.succeed(response)
				}
			}

			return promise.futureResult
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
	/// True when CertificateAuthMiddleware is also active — only then may a verified
	/// TLS client certificate substitute for the password.  Without a CA cert the
	/// server cannot verify the peer chain, so any self-signed cert would bypass auth.
	let hasCertificateAuth: Bool

	func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		// Web UI static assets are public — the React app handles authentication itself.
		let path = request.url.path
		if path == "/" || path.hasPrefix("/ui") {
			return next.respond(to: request)
		}

		// Operation WebSocket upgrades (terminal/VGA console, exec) carry their own
		// one-time `secret` query token, generated only after the originating
		// exec/console request was itself password-authenticated, and validated by
		// LXDOperationsController.websocketForOperation. Browsers cannot attach an
		// `Authorization` header to a WebSocket handshake, so challenging here would
		// only fail the upgrade and pop the browser's native credential dialog.
		if path.hasPrefix("/1.0/operations/"), path.hasSuffix("/websocket") {
			return next.respond(to: request)
		}

		// Allow mTLS-authenticated clients to skip password check — only when
		// CertificateAuthMiddleware is also active and has already validated the chain.
		if hasCertificateAuth, let peerCertificateChain = request.peerCertificateChain, peerCertificateChain.isEmpty == false {
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
			// Accept a raw bearer token and keep compatibility with legacy base64-encoded bearer values.
			let bearerToken = credentials
			let decodedToken = credentials.base64DecodedString()
			guard bearerToken.isEmpty == false else {
				return unauthorized(on: request)
			}

			if bearerToken == password || decodedToken == password {
				request.storage[PasswordAuthenticatedKey.self] = true
				return next.respond(to: request)
			}

			return request.eventLoop.makeFutureWithTask {
				let identity = await LXDIdentityStore.shared.get(nameOrID: bearerToken)
				let response: Response

				if let identity {
					request.storage[PasswordAuthenticatedKey.self] = true
					request.parameters.set("token", to: "\(identity.authenticationMethod)/\(identity.id)")
					response = try await next.respond(to: request).get()
				} else {
					response = Response(status: .unauthorized)

					response.headers.replaceOrAdd(name: .wwwAuthenticate, value: challenge("Basic", for: request))
					response.headers.add(name: .wwwAuthenticate, value: challenge("Bearer", for: request))
				}

				return response
			}
		case "basic":
			// Expecting: "Basic base64(username:password)"
			let decoded = credentials.base64DecodedString()
			// Username is ignored — only the password (after the first ':') is validated
			guard let colonIdx = decoded.firstIndex(of: ":") else {
				return unauthorized(on: request)
			}
			let providedPassword = String(decoded[decoded.index(after: colonIdx)...])
			guard providedPassword.isEmpty == false, providedPassword == password else {
				return unauthorized(on: request)
			}
		default:
			return unauthorized(on: request)
		}

		request.storage[PasswordAuthenticatedKey.self] = true
		return next.respond(to: request)
	}

	private func unauthorized(on request: Request) -> EventLoopFuture<Response> {
		let response = Response(status: .unauthorized)
		response.headers.replaceOrAdd(name: .wwwAuthenticate, value: challenge("Basic", for: request))
		response.headers.add(name: .wwwAuthenticate, value: challenge("Bearer", for: request))
		return request.eventLoop.makeSucceededFuture(response)
	}

	/// Builds a `WWW-Authenticate` challenge for `scheme`.
	///
	/// Browsers show their own built-in credential prompt whenever they recognize the
	/// challenge scheme (`Basic`, `Digest`, `NTLM`, `Negotiate`) in a 401 response — even for
	/// XHR/fetch requests. The web UI authenticates through its own login page, so for requests
	/// it makes (flagged with `X-Requested-With: XMLHttpRequest`) the scheme is prefixed with a
	/// token browsers don't recognize. `AuthContext` matches schemes by substring, so it still
	/// detects `x-Basic`/`x-Bearer` correctly while the native dialog is suppressed. Other
	/// clients (e.g. `cakectl`) keep receiving the standard, RFC-compliant scheme name.
	private func challenge(_ scheme: String, for request: Request) -> String {
		let isWebUIRequest = request.headers.first(name: "X-Requested-With")?.caseInsensitiveCompare("XMLHttpRequest") == .orderedSame
		let token = isWebUIRequest ? "x-\(scheme)" : scheme
		return "\(token) realm=\"Caker\""
	}
}

/// Extracts a `.zip` archive to a temporary directory and returns the extracted root path.
/// If `path` does not end in `.zip`, it is returned unchanged.
private func resolveWebUIDirectory(_ path: String) throws -> String {
	let path = path.expandingTildeInPath

	guard path.lowercased().hasSuffix(".zip") else { return path }

	let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("caker-webui")

	try? FileManager.default.removeItem(at: tmpDir)
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

	static var runMode: Utils.RunMode = .user

	/// Creates and configures the Vapor application but does not start it.
	init(group: EventLoopGroup, listen: URL, caCert: String?, tlsCert: String?, tlsKey: String?, runMode: Utils.RunMode, webUIDirectory: String? = nil, restLogLevel: CakeAgentLib.Logger.LogLevel = .warning) async throws {
		let app = try await Application.make(Environment.current(), .shared(group), logger: Logger(label: "LXDRESTServer"))

		Self.runMode = runMode

		// Configure JSON encoder/decoder for LXD snake_case + ISO8601 dates
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .useDefaultKeys
		encoder.dateEncodingStrategy = .iso8601

		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .useDefaultKeys
		decoder.dateDecodingStrategy = .iso8601

		ContentConfiguration.global.use(encoder: encoder, for: .json)
		ContentConfiguration.global.use(decoder: decoder, for: .json)

		// Add Bearer/Basic password protection if a password is provided.
		// hasCertificateAuth is resolved below once we know whether a CA cert is present.
		let listenPassword = listen.password(percentEncoded: false).flatMap { $0.isEmpty ? nil : $0 }
		let hasCertificateAuth = caCert != nil

		guard let hostname = listen.host(percentEncoded: false), let port = listen.port else {
			throw ServiceError("Invalid listen URL: host or port missing")
		}

		var serverConfiguration = app.http.server.configuration

		serverConfiguration.hostname = hostname
		serverConfiguration.port = port

		if let password = listenPassword {
			app.middleware.use(PasswordAuthMiddleware(password: password, hasCertificateAuth: hasCertificateAuth))
		}

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
		app.logger.logLevel = restLogLevel.level

		// Restore persisted state for all LXD stores
		try await LXDAuthGroupStore.shared.configure(runMode: runMode)
		try await LXDIdentityStore.shared.configure(runMode: runMode)
		try await LXDCertificateStore.shared.configure(runMode: runMode)

		// Register LXD routes
		try registerLXDRoutes(app, group: group, runMode: runMode)

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
		try? await LXDOperationStore.shared.shutdown()
		try? await app.asyncShutdown()
	}
}

