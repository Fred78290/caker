//
//  CertificateRepresentation.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/05/2026.
//

public struct CertificateRepresentation: Codable {
	public var name: String
	public var type: String
	public var restricted: Bool
	public var projects: String
	public var certificate: String
	public var fingerprint: String
	
	public init(_ from: Caked_Certificate) {
		self.name = from.name
		self.type = from.type
		self.restricted = from.restricted
		self.projects = from.projects.joined(separator: ", ")
		self.certificate = from.certificate
		self.fingerprint = from.fingerprint
	}
}

public struct ShortCertificateRepresentation: Codable {
	public var name: String
	public var projects: String
	public var fingerprint: String
	
	public init(_ from: Caked_Certificate) {
		self.name = from.name
		self.projects = from.projects.joined(separator: ", ")
		self.fingerprint = from.fingerprint
	}
}
