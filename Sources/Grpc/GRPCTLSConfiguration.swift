//
//  GRPCTLSConfiguration.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/01/2026.
//
import Foundation
import GRPC
import NIO
import NIOSSL

public class GrpcError: Error {
	public let code: Int
	public let reason: String

	public init(code: Int, reason: String) {
		self.code = code
		self.reason = reason
	}
}

extension Caked {
	public static let defaultServicePort = 5101

	public static func createClient(
		on: EventLoopGroup,
		listeningAddress: URL?,
		connectionTimeout: Int64 = 60,
		retries: ConnectionBackoff.Retries,
		caCert: String?,
		tlsCert: String?,
		tlsKey: String?,
		password: String? = nil,
		interceptors: Caked_ServiceClientInterceptorFactoryProtocol? = nil
	) throws -> CakedServiceClient {
		if let listeningAddress = listeningAddress {
			let target: ConnectionTarget
			let inet: Bool

			if listeningAddress.scheme == "unix" || listeningAddress.isFileURL {
				target = ConnectionTarget.unixDomainSocket(listeningAddress.path)
				inet = false
			} else if listeningAddress.scheme == "tcp" {
				target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? Caked.defaultServicePort)
				inet = true
			} else {
				throw GrpcError(
					code: -1,
					reason:
						"unsupported address scheme: \(String(describing: listeningAddress.scheme))")
			}

			var clientConfiguration = ClientConnection.Configuration.default(target: target, eventLoopGroup: on)

			if let tlsCert = tlsCert, let tlsKey = tlsKey {
				if inet == false || password == nil {
					clientConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeClientConfiguration(
						caCert: caCert,
						tlsKey: tlsKey,
						tlsCert: tlsCert)
				} else {
					clientConfiguration.tlsConfiguration = GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL(certificateVerification: .none)
				}
			}

			clientConfiguration.connectionBackoff = ConnectionBackoff(maximumBackoff: TimeInterval(connectionTimeout), minimumConnectionTimeout: TimeInterval(connectionTimeout), retries: retries)

			var client = CakedServiceClient(channel: ClientConnection(configuration: clientConfiguration), interceptors: interceptors)

			if let password = password, inet {
				client.interceptors = CakedPasswordAuthClientInterceptorFactory(password: password, client: client)
			}

			return client
		}

		throw GrpcError(code: -1, reason: String(localized: "connection address must be specified"))
	}
}

extension GRPCTLSConfiguration {
	static public func makeServerConfiguration(caCert: String?, tlsKey: String, tlsCert: String, certificateVerification: CertificateVerification = .none, requireALPN: Bool = false) throws -> GRPCTLSConfiguration {
		
		let tlsCert = try NIOSSLCertificate.fromPEMFile(tlsCert)
		let tlsKey = try NIOSSLPrivateKey(file: tlsKey, format: .pem)
		let trustRoots: NIOSSLTrustRoots
		
		if let caCert: String = caCert {
			trustRoots = .certificates(try NIOSSLCertificate.fromPEMFile(caCert))
		} else {
			trustRoots = NIOSSLTrustRoots.default
		}
		
		
		return GRPCTLSConfiguration.makeServerConfigurationBackedByNIOSSL(
			certificateChain: [.certificate(tlsCert.first!)],
			privateKey: .privateKey(tlsKey),
			trustRoots: trustRoots,
			certificateVerification: certificateVerification,
			requireALPN: requireALPN)
	}
	
	static public func makeClientConfiguration(caCert: String?, tlsKey: String, tlsCert: String, certificateVerification: CertificateVerification = .noHostnameVerification) throws -> GRPCTLSConfiguration {

		let tlsCert = try NIOSSLCertificate.fromPEMFile(tlsCert)
		let tlsKey = try NIOSSLPrivateKey(file: tlsKey, format: .pem)
		let trustRoots: NIOSSLTrustRoots

		if let caCert: String = caCert {
			trustRoots = .certificates(try NIOSSLCertificate.fromPEMFile(caCert))
		} else {
			trustRoots = NIOSSLTrustRoots.default
		}

		return GRPCTLSConfiguration.makeClientConfigurationBackedByNIOSSL(
			certificateChain: [.certificate(tlsCert.first!)],
			privateKey: .privateKey(tlsKey),
			trustRoots: trustRoots,
			certificateVerification: certificateVerification)
	}
}
