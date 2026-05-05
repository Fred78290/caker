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
import Vapor

extension TLSConfiguration {
	static public func makeServerConfiguration(caCert: String?, tlsKey: String, tlsCert: String, certificateVerification: CertificateVerification = .none, requireALPN: Bool = false) throws -> TLSConfiguration {
		let tlsCerts = try NIOSSLCertificate.fromPEMFile(tlsCert)
		let tlsKey = try NIOSSLPrivateKey(file: tlsKey, format: .pem)
		let trustRoots: NIOSSLTrustRoots

		if let caCert: String = caCert {
			// When a CA is provided, use it for trust and require full client cert verification (mTLS)
			trustRoots = .certificates(try NIOSSLCertificate.fromPEMFile(caCert))
		} else {
			// No CA provided: do not verify client certificates (server-only TLS)
			trustRoots = NIOSSLTrustRoots.default
		}

		var tlsConfiguration = TLSConfiguration.makeServerConfigurationWithMTLS(
			certificateChain: [.certificate(tlsCerts.first!)],
			privateKey: .privateKey(tlsKey),
			trustRoots: trustRoots
		)

		tlsConfiguration.certificateVerification = certificateVerification

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

/// Password middleware that validates the Bearer token against a single shared secret.
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

		// Expecting: "Bearer base64(pass-phrase)"
		let parts = authHeader.split(separator: " ")
		guard parts.count == 2, parts[0].lowercased() == "bearer" else {
			return unauthorized(on: request)
		}

		let token = String(parts[1]).base64DecodedString()

		guard token.isEmpty == false, token == password else {
			return unauthorized(on: request)
		}

		return next.respond(to: request)
	}

	private func unauthorized(on request: Request) -> EventLoopFuture<Response> {
		let response = Response(status: .unauthorized)
		response.headers.replaceOrAdd(name: .wwwAuthenticate, value: "Bearer realm=\"Caker\"")
		return request.eventLoop.makeSucceededFuture(response)
	}
}

/// Wraps a Vapor Application providing LXD-compatible REST server lifecycle.
final class LXDRESTServer: Sendable {
	private let app: Application

	/// Creates and configures the Vapor application but does not start it.
	init(group: MultiThreadedEventLoopGroup, listen: URL, caCert: String?, tlsCert: String?, tlsKey: String?, runMode: Utils.RunMode) async throws {
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

		// HTTP server configuration
		// Add Bearer-token protection if a password is provided
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
			// When a CA cert is provided, enable mTLS (client certificate required).
			// NIOSSL handles chain verification internally using the configured trust roots.
			// When no CA cert is provided, server-only TLS is used (no client cert required).
			let tlsConfiguration = try TLSConfiguration.makeServerConfiguration(
				caCert: caCert,
				tlsKey: tlsKey,
				tlsCert: tlsCert,
				certificateVerification: caCert != nil ? .noHostnameVerification : .none
			)

			serverConfiguration.tlsConfiguration = tlsConfiguration
		}

		app.http.server.configuration = serverConfiguration

		// Disable default Vapor console logging to avoid noise (use caked's logger)
		app.logger.logLevel = CakeAgentLib.Logger.LoggingLevel()

		// Register LXD routes
		try registerLXDRoutes(app, runMode: runMode)

		self.app = app
	}

	/// Starts the HTTP server (non-blocking).
	func start() throws {
		try app.start()
	}

	/// Shuts down the HTTP server and releases resources.
	func shutdown() {
		app.shutdown()
	}
}

