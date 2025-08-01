import Crypto
import Foundation
import GRPCLib
import Security
import SwiftASN1
import X509
import _CryptoExtras

struct CypherKeyGeneratorError: Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

extension Data {
	/// A partial PKCS8 DER prefix. This specifically is the version and private key algorithm identifier.
	private static let partialPKCS8Prefix = Data(
		[
			0x02, 0x01, 0x00,  // Version, INTEGER 0
			0x30, 0x0d,  // SEQUENCE, length 13
			0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01,  // rsaEncryption OID
			0x05, 0x00,  // NULL
		]
	)

	fileprivate var pkcs8RSAKeyBytes: Data? {
		// This is PKCS8. A bit awkward now. Rather than bring over the fully-fledged ASN.1 code from
		// the main module and all its dependencies, we have a little hand-rolled verifier. To be a proper
		// PKCS8 key, this should match:
		//
		// PrivateKeyInfo ::= SEQUENCE {
		//   version                   Version,
		//   privateKeyAlgorithm       PrivateKeyAlgorithmIdentifier,
		//   privateKey                PrivateKey,
		//   attributes           [0]  IMPLICIT Attributes OPTIONAL }
		//
		// Version ::= INTEGER
		//
		// PrivateKeyAlgorithmIdentifier ::= AlgorithmIdentifier
		//
		// PrivateKey ::= OCTET STRING
		//
		// Attributes ::= SET OF Attribute
		//
		// We know the version and algorithm identifier, so we can just strip the bytes we'd expect to see here. We do validate
		// them though.
		precondition(self.startIndex == 0)

		guard self.count >= 4 + Data.partialPKCS8Prefix.count + 4 else {
			return nil
		}

		// First byte will be the tag for sequence, 0x30.
		guard self[0] == 0x30 else {
			return nil
		}

		// The next few bytes will be a length. We'll expect it to be 3 bytes long, with the first byte telling us
		// that it's 3 bytes long.
		let lengthLength = Int(self[1])
		guard lengthLength == 0x82 else {
			return nil
		}

		let length = Int(self[2]) << 8 | Int(self[3])
		guard length == self.count - 4 else {
			return nil
		}

		// Now we can check the version through the algorithm identifier against the hardcoded values.
		guard self.dropFirst(4).prefix(Data.partialPKCS8Prefix.count) == Data.partialPKCS8Prefix else {
			return nil
		}

		// Ok, the last check are the next 4 bytes, which should now be the tag for OCTET STRING followed by another length.
		guard self[4 + Data.partialPKCS8Prefix.count] == 0x04,
			self[4 + Data.partialPKCS8Prefix.count + 1] == 0x82
		else {
			return nil
		}

		let octetStringLength = Int(self[4 + Data.partialPKCS8Prefix.count + 2]) << 8 | Int(self[4 + Data.partialPKCS8Prefix.count + 3])
		guard octetStringLength == self.count - 4 - Data.partialPKCS8Prefix.count - 4 else {
			return nil
		}

		return self.dropFirst(4 + Data.partialPKCS8Prefix.count + 4)
	}
}

public struct PrivateKeyModel {
	var publicKey: SecKey
	var privateKey: SecKey

	static func base64String(pemEncoded pemString: String) throws -> Data? {
		let lines = pemString.components(separatedBy: "\n").filter { line in
			return !line.hasPrefix("-----BEGIN") && !line.hasPrefix("-----END")
		}

		if lines.isEmpty {
			throw CypherKeyGeneratorError("Couldn't get data from PEM key: no data available after stripping headers")
		}

		return Data(base64Encoded: lines.joined(separator: ""))
	}

	public init(from fromPrivateKey: URL) throws {
		guard let privateKeyPEM = try String(data: Data(contentsOf: fromPrivateKey), encoding: .ascii) else {
			throw CypherKeyGeneratorError("Unable to read private key from file")
		}

		guard var privateKeyData = try Self.base64String(pemEncoded: privateKeyPEM) else {
			throw ServiceError("Unable to convert PEM to data")
		}

		if let pkcs8Data = privateKeyData.pkcs8RSAKeyBytes {
			privateKeyData = pkcs8Data
		}

		guard
			let privateKey = SecKeyCreateWithData(
				privateKeyData as CFData,
				[
					kSecAttrKeyType: kSecAttrKeyTypeRSA,
					kSecAttrKeyClass: kSecAttrKeyClassPrivate,
				] as CFDictionary, nil)
		else {
			throw CypherKeyGeneratorError("Unable to create private key from data")
		}

		guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
			throw CypherKeyGeneratorError("Unable to get public key")
		}

		self.publicKey = publicKey
		self.privateKey = privateKey
	}

	public init(publicKey: SecKey, privateKey: SecKey) {
		self.publicKey = publicKey
		self.privateKey = privateKey
	}

	public func save(privateURL: URL, publicURL: URL) throws {
		let privateKey = try self.privateKeyString()
		let publicKey = try self.publicKeyString()

		FileManager.default.createFile(atPath: privateURL.path, contents: privateKey.data(using: .ascii), attributes: [.posixPermissions: 0o600])
		FileManager.default.createFile(atPath: publicURL.path, contents: publicKey.data(using: .ascii), attributes: [.posixPermissions: 0o644])
	}

	public func publicKeyString() throws -> String {
		var error: Unmanaged<CFError>?

		guard let externalRepresentation = SecKeyCopyExternalRepresentation(self.publicKey, &error) else {
			throw error!.takeRetainedValue() as Error
		}

		let data = [UInt8](externalRepresentation as Data)

		var sshRsa: [UInt8] = [
			0x00, 0x00, 0x00, 0x07,
			0x73, 0x73, 0x68, 0x2d, 0x72, 0x73, 0x61,
			0x00, 0x00, 0x00, 0x03,
			0x01, 0x00, 0x01,
			0x00, 0x00,
		]

		let pubKey = [UInt8](data[6...data.count - 6])

		sshRsa.append(contentsOf: pubKey)

		return "ssh-rsa " + Data(sshRsa).base64EncodedString()
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

public struct RSAKeyGenerator {
	private var privateKey: PrivateKeyModel

	var publicKeyString: String {
		return try! self.privateKey.publicKeyString()
	}

	init() throws {
		self.privateKey = try Self.generateKey()
	}

	public func save(privateURL: URL, publicURL: URL) throws {
		try privateKey.save(privateURL: privateURL, publicURL: publicURL)
	}

	static func generateKey() throws -> PrivateKeyModel {

		var error: Unmanaged<CFError>?

		let publicKeyAttr: CFDictionary =
			[
				kSecAttrIsPermanent: false,
				kSecAttrLabel: Utils.cakerSignature,
				kSecAttrApplicationLabel: Utils.cakerSignature,
				kSecClass: kSecClassKey,
				kSecReturnData: kCFBooleanTrue ?? true,
				kSecAttrIsExtractable: kCFBooleanTrue ?? true,
				kSecAttrProtocol: kSecAttrProtocolSSH,
			] as CFDictionary  // added this value

		let privateKeyAttr: CFDictionary =
			[
				kSecAttrIsPermanent: false,
				kSecAttrLabel: Utils.cakerSignature,
				kSecAttrApplicationLabel: Utils.cakerSignature,
				kSecClass: kSecClassKey,  // added this value
				kSecReturnData: kCFBooleanTrue ?? true,
				kSecAttrIsExtractable: kCFBooleanTrue ?? true,
				kSecAttrProtocol: kSecAttrProtocolSSH,
			] as CFDictionary  // added this value

		let parameters: CFDictionary =
			[
				kSecAttrKeyType: kSecAttrKeyTypeRSA,
				kSecAttrApplicationLabel: Utils.cakerSignature,
				kSecAttrKeySizeInBits: 4096,
				kSecPublicKeyAttrs: publicKeyAttr,
				kSecPrivateKeyAttrs: privateKeyAttr,
				kSecAttrProtocol: kSecAttrProtocolSSH,
			] as CFDictionary

		guard let privateKey = SecKeyCreateRandomKey(parameters, &error) else {
			throw error!.takeRetainedValue() as Error
		}

		guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
			throw CypherKeyGeneratorError("Unable to get public key")
		}

		return PrivateKeyModel(publicKey: publicKey, privateKey: privateKey)
	}

	static func generateClientServerCertificate(
		subject: String, numberOfYears: Int,
		caKeyURL: URL, caCertURL: URL,
		serverKeyURL: URL, serverCertURL: URL,
		clientKeyURL: URL, clientCertURL: URL
	) throws {
		let notValidBefore = Date()
		let notValidAfter = notValidBefore.addingTimeInterval(TimeInterval(60 * 60 * 24 * 365 * numberOfYears))
		let rootPrivateKey = try _RSA.Signing.PrivateKey(keySize: .bits4096)
		let rootCertKey: Certificate.PrivateKey = Certificate.PrivateKey(rootPrivateKey)
		let rootCertName = try! DistinguishedName {
			CountryName("FR")
			OrganizationName("AlduneLabs")
			CommonName("\(subject) Root CA")
		}
		let rootCert = try! Certificate(
			version: .v3,
			serialNumber: Certificate.SerialNumber(),
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
			CommonName("\(subject) server")
			OrganizationName("AlduneLabs")
		}

		let serverPrivateKey = try _RSA.Signing.PrivateKey(keySize: .bits4096)
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
					try ExtendedKeyUsage([.serverAuth])
				)
				SubjectAlternativeNames([
					.ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1])),
					.dnsName("localhost"),
					.dnsName("*"),
				])
			},
			issuerPrivateKey: rootCertKey)

		let clientPrivateKey = try _RSA.Signing.PrivateKey(keySize: .bits4096)
		let clientCertKey = Certificate.PrivateKey(clientPrivateKey)
		let clientCertificate = try Certificate(
			version: .v3,
			serialNumber: Certificate.SerialNumber(),
			publicKey: clientCertKey.publicKey,
			notValidBefore: notValidBefore,
			notValidAfter: notValidAfter,
			issuer: rootCertName,
			subject: try DistinguishedName {
				CommonName("\(subject) client")
				OrganizationName("AlduneLabs")
			},
			signatureAlgorithm: .sha512WithRSAEncryption,
			extensions: try Certificate.Extensions {
				Critical(
					KeyUsage(digitalSignature: true, keyEncipherment: true)
				)
				Critical(
					try ExtendedKeyUsage([.clientAuth])
				)
				SubjectAlternativeNames([
					.dnsName("localhost"),
					.ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1])),
				])
			},
			issuerPrivateKey: rootCertKey)

		// Save CA key & cert
		FileManager.default.createFile(
			atPath: caKeyURL.absoluteURL.path,
			contents: try rootCertKey.serializeAsPEM().pemString.data(using: .ascii),
			attributes: [.posixPermissions: 0o600])

		FileManager.default.createFile(
			atPath: caCertURL.absoluteURL.path,
			contents: try rootCert.serializeAsPEM().pemString.data(using: .ascii),
			attributes: [.posixPermissions: 0o600])

		// Save server key & cert
		FileManager.default.createFile(
			atPath: serverKeyURL.absoluteURL.path,
			contents: try serverCertKey.serializeAsPEM().pemString.data(using: .ascii),
			attributes: [.posixPermissions: 0o644])

		FileManager.default.createFile(
			atPath: serverCertURL.absoluteURL.path,
			contents: try serverCertificate.serializeAsPEM().pemString.data(using: .ascii),
			attributes: [.posixPermissions: 0o644])

		// Save Client key & cert
		FileManager.default.createFile(
			atPath: clientKeyURL.absoluteURL.path,
			contents: try clientCertKey.serializeAsPEM().pemString.data(using: .ascii),
			attributes: [.posixPermissions: 0o644])

		FileManager.default.createFile(
			atPath: clientCertURL.absoluteURL.path,
			contents: try clientCertificate.serializeAsPEM().pemString.data(using: .ascii),
			attributes: [.posixPermissions: 0o644])
	}
}

struct CloudInitGenerateError: Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}
