//
//  LXDCertificateStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import GRPCLib
import CryptoKit
import Security
import X509

// MARK: - LXD Certificate Store

/// Thread-safe in-memory store for LXD certificates, keyed by fingerprint.
actor LXDCertificateStore {
	static let shared = LXDCertificateStore()
	
	private var certificates: [String: LXDCertificate] = [:]
	private var storeURL: URL?
	
	// MARK: - Persistence
	
	/// Loads existing state from disk and stores the persistence URL for future saves.
	func configure(runMode: Utils.RunMode) throws {
		let url = try LXDStorePersistence.storeURL(name: "lxd-certificates", runMode: runMode)
		if let data = try? Data(contentsOf: url),
		   let loaded = try? JSONDecoder().decode([String: LXDCertificate].self, from: data) {
			self.certificates = loaded
		}
		self.storeURL = url
	}
	
	private func save() {
		guard let url = storeURL,
			  let data = try? JSONEncoder().encode(certificates) else { return }
		try? data.write(to: url, options: .atomic)
	}
	
	func create(name: String, type: String, restricted: Bool, projects: [String], certificate: String, fingerprint: String) -> LXDCertificate? {
		guard certificates[fingerprint] == nil else { return nil }
		
		let cert = LXDCertificate(
			name: name,
			type: type,
			restricted: restricted,
			projects: projects,
			certificate: certificate,
			fingerprint: fingerprint
		)
		
		certificates[fingerprint] = cert
		save()
		return cert
	}
	
	func get(fingerprint: String) -> LXDCertificate? {
		if let found = certificates[fingerprint] { return found }
		// fall back to name search
		return certificates.values.first { $0.name == fingerprint }
	}
	
	func get(name: String) -> LXDCertificate? {
		if let found = certificates.values.first(where: { $0.name == name }) { return found }
		
		// fall back to fingerprint search
		return certificates[name]
	}
	
	
	func list() -> [LXDCertificate] {
		Array(certificates.values).sorted { $0.fingerprint < $1.fingerprint }
	}
	
	func listURLs() -> [String] {
		certificates.values
			.sorted { $0.fingerprint < $1.fingerprint }
			.map { "/1.0/certificates/\($0.fingerprint)" }
	}
	
	/// Full replace (PUT).
	func put(fingerprint: String, name: String, type: String, restricted: Bool, projects: [String], certificate: String) -> LXDCertificate? {
		guard var cert = get(fingerprint: fingerprint) else { return nil }
		
		cert.name = name
		cert.type = type
		cert.restricted = restricted
		cert.projects = projects
		cert.certificate = certificate
		certificates[cert.fingerprint] = cert
		save()
		return cert
	}
	
	/// Partial update (PATCH).
	func patch(fingerprint: String, name: String?, type: String?, restricted: Bool?, projects: [String]?, certificate: String?) -> LXDCertificate? {
		guard var cert = get(fingerprint: fingerprint) else { return nil }
		
		if let name { cert.name = name }
		if let type { cert.type = type }
		if let restricted { cert.restricted = restricted }
		if let projects { cert.projects = projects }
		if let certificate { cert.certificate = certificate }
		certificates[cert.fingerprint] = cert
		save()
		return cert
	}
	
	func delete(fingerprint: String) -> Bool {
		guard let cert = get(fingerprint: fingerprint) else { return false }
		certificates.removeValue(forKey: cert.fingerprint)
		save()
		return true
	}
	
	func delete(name: String) -> Bool {
		guard let cert = get(name: name) else { return false }
		certificates.removeValue(forKey: cert.fingerprint)
		save()
		return true
	}
	
	// MARK: - PEM conversion helpers
	
	/// Convert the first PEM certificate block to DER data.
	static func pemToDer(_ pem: String) -> Data? {
		let lines = pem.components(separatedBy: "\n")
			.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
			.filter { !$0.hasPrefix("-----BEGIN") && !$0.hasPrefix("-----END") }
		let base64 = lines.joined()
		
		return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
	}
	
	/// Build an LXDCertificate from a PEM-encoded public certificate without persisting it.
	/// Computes a SHA-256 hex fingerprint of the DER bytes.
	static func lxdCertificate(fromPem pem: String, name: String, type: String = "client", restricted: Bool = false, projects: [String] = []) -> LXDCertificate? {
		guard let der = pemToDer(pem) else { return nil }
		
		let hash = SHA256.hash(data: der)
		let fingerprint = hash.map { String(format: "%02x", $0) }.joined()
		let normalizedPem = pem.trimmingCharacters(in: .whitespacesAndNewlines)
		
		return LXDCertificate(name: name, type: type, restricted: restricted, projects: projects, certificate: normalizedPem, fingerprint: fingerprint)
	}
	
	/// Convenience: compute fingerprint from PEM and create & persist the LXDCertificate in the store.
	func createFromPem(name: String, type: String = "client", restricted: Bool = false, projects: [String] = [], pem: String) -> LXDCertificate? {
		guard let cert = Self.lxdCertificate(fromPem: pem, name: name, type: type, restricted: restricted, projects: projects) else { return nil }
		// Ensure uniqueness and persist via existing create(fingerprint:)
		return create(name: cert.name, type: cert.type, restricted: cert.restricted, projects: cert.projects, certificate: cert.certificate, fingerprint: cert.fingerprint)
	}
	
	func peerChainIsTrusted(_ chain: X509.ValidatedCertificateChain) -> Bool {
        // Consider the peer trusted if any certificate in the validated chain matches a stored fingerprint.
        // We compute SHA-256 over the DER of each certificate in the chain and compare to keys in `certificates`.
		let result = chain.first {
			guard let hash = try? SHA256.hash(data: Data($0.serializeAsPEM().derBytes)) else {
				return false
			}

			let fingerprint = hash.map { String(format: "%02x", $0) }.joined()

			return certificates[fingerprint] != nil
		}

		return result != nil
	}
}
