//
//  GRPCTLSConfiguration.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/01/2026.
//
import GRPC
import NIO
import NIOSSL

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
