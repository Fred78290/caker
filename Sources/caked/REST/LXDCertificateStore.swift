//
//  LXDCertificateStore.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/05/2026.
//

import Foundation
import GRPCLib

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
}
