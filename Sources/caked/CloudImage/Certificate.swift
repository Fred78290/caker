import Foundation
import Security
import Crypto
import SwiftASN1
import X509
import _CryptoExtras

struct CypherKeyGeneratorError: Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

public struct CypherKeyModel {
	var publicKey: SecKey
	var privateKey: SecKey

	init(publicKey: SecKey, privateKey: SecKey) {
		self.publicKey = publicKey
		self.privateKey = privateKey
	}

	public func save(privateURL: URL , publicURL: URL) throws {
		let privateKey = try self.privateKeyString()
		let publicKey = try self.publicKeyString()

		FileManager.default.createFile(atPath: privateURL.path, contents: privateKey.data(using: .ascii), attributes: [.posixPermissions : 0o600])
		FileManager.default.createFile(atPath: publicURL.path, contents: publicKey.data(using: .ascii), attributes: [.posixPermissions : 0o644])
	}

	public func publicKeyString() throws -> String {
		var error: Unmanaged<CFError>?

		guard let externalRepresentation = SecKeyCopyExternalRepresentation(self.publicKey, &error) else {
			throw error!.takeRetainedValue() as Error
		}

		let data = externalRepresentation as Data

		return "ssh-rsa " + data.base64EncodedString()
	}

	public func privateKeyString() throws -> String {
		var error: Unmanaged<CFError>?

		guard let externalRepresentation = SecKeyCopyExternalRepresentation(self.privateKey, &error) else {
			throw error!.takeRetainedValue() as Error
		}

		let data = externalRepresentation as Data

		return "-----BEGIN RSA PRIVATE KEY-----\n" + data.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters) + "\n-----END RSA PRIVATE KEY-----"
	}
}

public struct CypherKeyGenerator {
	private var publicKey: Data
	private var privateKey: Data
	private let identifier: String

	init(identifier: String) throws {
		let publicKeyId = identifier + ".public"
		let privateKeyId = identifier + ".private"

		guard let publicKeyIndentifierData = publicKeyId.data(using: String.Encoding.utf8),
			  let privateKeyIndentifierData = privateKeyId.data(using: String.Encoding.utf8)
		else {
			throw CypherKeyGeneratorError("Can't generate cypher key")
		}

		self.identifier = identifier
		self.publicKey = publicKeyIndentifierData
		self.privateKey = privateKeyIndentifierData
	}

	func generateKey() throws -> CypherKeyModel {
		var error: Unmanaged<CFError>?

		let publicKeyAttr: CFDictionary =
			[
				kSecAttrIsPermanent: true,
				kSecAttrLabel: identifier,
				kSecAttrApplicationLabel: identifier,
				kSecAttrApplicationTag: publicKey,
				kSecClass: kSecClassKey,
				kSecReturnData: kCFBooleanTrue ?? true,
			] as CFDictionary  // added this value

		let privateKeyAttr: CFDictionary =
			[
				kSecAttrIsPermanent: true,
				kSecAttrLabel: identifier,
				kSecAttrApplicationLabel: identifier,
				kSecAttrApplicationTag: privateKey,
				kSecClass: kSecClassKey,  // added this value
				kSecReturnData: kCFBooleanTrue ?? true,
			] as CFDictionary  // added this value

		let parameters: CFDictionary =
			[
				kSecAttrKeyType: kSecAttrKeyTypeRSA,
				kSecAttrApplicationLabel: identifier,
				kSecAttrKeySizeInBits: 1024,
				kSecPublicKeyAttrs: publicKeyAttr,
				kSecPrivateKeyAttrs: privateKeyAttr,
			] as CFDictionary

		guard let privateKey = SecKeyCreateRandomKey(parameters, &error) else {
			throw error!.takeRetainedValue() as Error
		}

		guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
			throw CypherKeyGeneratorError("Unable to get public key")
		}

		return CypherKeyModel.init(publicKey: publicKey, privateKey: privateKey)
	}

	static func generateClientServerCertificate(subject: String, numberOfYears: Int,
												caKeyURL: URL, caCertURL: URL,
												serverKeyURL: URL, serverCertURL:URL,
												clientKeyURL: URL, clientCertURL: URL) throws {
		let notValidBefore = Date()
		let notValidAfter = notValidBefore.addingTimeInterval(TimeInterval(60 * 60 * 24 * 365 * numberOfYears))
		let rootPrivateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)
		let rootCertKey: Certificate.PrivateKey = Certificate.PrivateKey(rootPrivateKey)
		let rootCertName = try! DistinguishedName {
			CommonName("Caked Root CA")
		}
		let rootCert = try! Certificate(
			version: .v3,
			serialNumber: .init(),
			publicKey: rootCertKey.publicKey,
			notValidBefore: notValidBefore,
			notValidAfter: notValidAfter,
			issuer: rootCertName,
			subject: rootCertName,
			signatureAlgorithm: .sha512WithRSAEncryption,
			extensions: try! Certificate.Extensions {
				Critical(
					BasicConstraints.isCertificateAuthority(maxPathLength: nil)
				)
			},
			issuerPrivateKey: rootCertKey
		)

		let subjectName = try DistinguishedName {
			CommonName(subject);
			OrganizationName("AlduneLabs");
		}

		let serverPrivateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)
		let serverCertKey = Certificate.PrivateKey(serverPrivateKey)
		let serverCertificate = try Certificate(
			version: .v3,
			serialNumber: Certificate.SerialNumber(),
			publicKey: serverCertKey.publicKey,
			notValidBefore: notValidBefore,
			notValidAfter: notValidAfter,
			issuer: rootCertName,
			subject: subjectName,
			signatureAlgorithm: .sha512WithRSAEncryption,
			extensions: try Certificate.Extensions {
				Critical(
					BasicConstraints.isCertificateAuthority(maxPathLength: nil)
				)
				Critical(
					KeyUsage(digitalSignature: true, keyEncipherment: true, dataEncipherment: true, keyCertSign: true)
				)
				Critical(
					try ExtendedKeyUsage([.serverAuth, .clientAuth])
				)
				SubjectAlternativeNames([
					.dnsName("localhost"),
					.dnsName("*")
				])
			},
			issuerPrivateKey: rootCertKey)

		let clientPrivateKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)
		let clientCertKey = Certificate.PrivateKey(clientPrivateKey)
		let clientCertificate = try Certificate(
			version: .v3,
			serialNumber: Certificate.SerialNumber(),
			publicKey: clientCertKey.publicKey,
			notValidBefore: notValidBefore,
			notValidAfter: notValidAfter,
			issuer: subjectName,
			subject: try DistinguishedName {
				CommonName("Caked client");
				OrganizationName("AlduneLabs");
			},
			signatureAlgorithm: .sha512WithRSAEncryption,
			extensions: try Certificate.Extensions {
				Critical(
					BasicConstraints.isCertificateAuthority(maxPathLength: nil)
				)
				Critical(
					KeyUsage(digitalSignature: true, keyEncipherment: true)
				)
				Critical(
					try ExtendedKeyUsage([.clientAuth])
				)
				SubjectAlternativeNames([
					.dnsName("localhost"),
					.dnsName("*"),
					.ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1]))
				])
			},
			issuerPrivateKey: serverCertKey)

		// Save CA key & cert
		FileManager.default.createFile(atPath: caKeyURL.absoluteURL.path(),
									   contents: try rootCertKey.serializeAsPEM().pemString.data(using: .ascii),
									   attributes: [.posixPermissions : 0o600])

		FileManager.default.createFile(atPath: caCertURL.absoluteURL.path(),
									   contents: try rootCert.serializeAsPEM().pemString.data(using: .ascii),
									   attributes: [.posixPermissions : 0o600])


		// Save server key & cert
		FileManager.default.createFile(atPath: serverKeyURL.absoluteURL.path(),
									   contents: try serverCertKey.serializeAsPEM().pemString.data(using: .ascii),
									   attributes: [.posixPermissions : 0o644])

		FileManager.default.createFile(atPath: serverCertURL.absoluteURL.path(),
									   contents: try serverCertificate.serializeAsPEM().pemString.data(using: .ascii),
									   attributes: [.posixPermissions : 0o644])



		// Save Client key & cert
		FileManager.default.createFile(atPath: clientKeyURL.absoluteURL.path(),
									   contents: try clientCertKey.serializeAsPEM().pemString.data(using: .ascii),
									   attributes: [.posixPermissions : 0o644])

		FileManager.default.createFile(atPath: clientCertURL.absoluteURL.path(),
									   contents: try clientCertificate.serializeAsPEM().pemString.data(using: .ascii),
									   attributes: [.posixPermissions : 0o644])
	}
}

struct CloudInitGenerateError : Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

