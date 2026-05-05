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

/// Simple Basic-Auth middleware that validates only the password part against a single shared secret.
private struct PasswordAuthMiddleware: Middleware {
	let password: String

	func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
		guard let authHeader = request.headers.first(name: .authorization) else {
			return unauthorized(on: request, next: next)
		}

		// Expecting: "Bearer base64(pass-phrase)"
		let parts = authHeader.split(separator: " ")
		guard parts.count == 2, parts[0].lowercased() == "bearer" else {
			return unauthorized(on: request, next: next)
		}

		let token = String(parts[1]).base64DecodedString()

		guard token.isEmpty == false else {
			return unauthorized(on: request, next: next)
		}

		guard token == password else {
			return unauthorized(on: request, next: next)
		}

		return next.respond(to: request)
	}

	private func unauthorized(on request: Request, next: Responder) -> EventLoopFuture<Response> {
		if let peerCertificateChain = request.peerCertificateChain, peerCertificateChain.isEmpty == false {
			return next.respond(to: request)
		}

		let response = Response(status: .unauthorized)
		response.headers.replaceOrAdd(name: .wwwAuthenticate, value: "Basic realm=\"Caker\"")
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
		// Add Basic-Auth protection if a password is provided
		if let password = listen.password(percentEncoded: false), password.isEmpty == false {
			app.middleware.use(PasswordAuthMiddleware(password: password))
		}

		var serverConfiguration = app.http.server.configuration

		serverConfiguration.hostname = listen.host(percentEncoded: false)!
		serverConfiguration.port = listen.port!

		if let tlsCert = tlsCert, let tlsKey = tlsKey {
			// Require client certificates only when caCert is provided; otherwise, server-only TLS
			let tlsConfiguration = try TLSConfiguration.makeServerConfiguration(
				caCert: caCert,
				tlsKey: tlsKey,
				tlsCert: tlsCert,
				certificateVerification: .noHostnameVerification
			)

			serverConfiguration.tlsConfiguration = tlsConfiguration
			serverConfiguration.customCertificateVerifyCallbackWithMetadata = { peerCerts, promise in
				// Determine if mTLS is configured by inspecting trust roots
				// If trustRoots are `.certificates` (non-empty), we assume a CA was configured and client certs are required.
				let requiresClientCert: Bool
	
				if case .certificates(let caCerts) = tlsConfiguration.trustRoots {
					requiresClientCert = caCerts.isEmpty == false && tlsConfiguration.certificateVerification != .none
				} else {
					requiresClientCert = false
				}

				// Helper to allow/deny
				func allow() { promise.succeed(.certificateVerified(VerificationMetadata(ValidatedCertificateChain(peerCerts)))) }
				func deny() { promise.succeed(.failed) }

				// If no client certificate presented
				guard peerCerts.isEmpty == false else {
					if requiresClientCert {
						// mTLS required but no client certificate
						deny()
					} else {
						// Server-only TLS, allow
						allow()
					}
					return
				}

				// If we get here, a client certificate (or chain) was presented. If mTLS is not required, accept.
				guard requiresClientCert else {
					allow()
					return
				}

				// Basic validation using the configured certificate chain as acceptable anchors when explicitly provided.
				// Extract leaf of presented chain and compare with any pinned client certificate if the server is configured with explicit certificates in certificateChain.
				let presentedLeaf = peerCerts.first

				// Gather any explicit certificates configured on the server side (certificateChain).
				//let serverChainCerts: [NIOSSLCertificate] = tlsConfiguration.certificateChain.compactMap { entry in
				//	if case .certificate(let cert) = entry { return cert } else { return nil }
				//}
				if case .certificates(let caCerts) = tlsConfiguration.trustRoots, caCerts.isEmpty == false, let leaf = presentedLeaf {
					// If you intend to require a specific client cert, compare DER representations.
					// (This is optional; remove if you only want CA-based verification.)
					let presentedDER = (try? leaf.toDERBytes()) ?? []

					if caCerts.contains( where: {((try? $0.toDERBytes()) ?? []) == presentedDER }) {
						allow()
						return
					}

					// If it doesn't match any pinned cert, fall through to CA-based decision (deny below).
				}

				// Without an explicit client cert pin, require at least one cert presented and a configured CA.
				// Since we disabled hostname verification above, we keep the policy strict here: deny when we cannot assert trust.
				// Note: Full path validation is normally handled by NIOSSL when not using a custom callback. Here, we keep a conservative stance.
				deny()
			}
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

