import Foundation
import Security

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
    FileManager.default.createFile(atPath: privateURL.path, contents: publicKey.data(using: .ascii), attributes: [.posixPermissions : 0o644])
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
}

struct CloudInitGenerateError : Error {
  let description: String

  init(_ what: String) {
    self.description = what
  }
}

