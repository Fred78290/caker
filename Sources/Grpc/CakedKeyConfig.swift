//
//  CakedKeyConfig.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/04/2026.
//
import Foundation
import Security

// Temporary shim to resolve missing Config symbol
public enum CakedKeyConfig: String, CaseIterable {
	private static let service = "com.aldunelabs.caker.config"

	case bridgedNetwork = "local.bridged-network"
	case driver = "local.driver"
	case imageMirror = "local.image.mirror"
	case passphrase = "local.passphrase"
	case privilegedMounts = "local.privileged-mounts"
	case primaryName = "client.primary-name"

	/// Sets a configuration value for the given key. This shim delegates to Keychain storage.
	/// Replace this with the real API if available (e.g., CakedLib.Config or SettingsHandler).
	public func set(_ value: String?) throws {
		// Store values in the Keychain as generic passwords under a service name for this app.
		// Use the key as the account attribute. If value is nil or empty, delete the item.

		// Helper to build a base query
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Self.service as CFString,
			kSecAttrAccount as String: self.rawValue as CFString,
		]

		// If no value provided, delete from Keychain
		if let value = value, value.isEmpty == false {
			let valueData = value.data(using: .utf8)!

			// Try update first
			let attributesToUpdate: [String: Any] = [
				kSecValueData as String: valueData
			]

			var status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

			if status == errSecItemNotFound {
				// Add new item
				query[kSecValueData as String] = valueData
				status = SecItemAdd(query as CFDictionary, nil)
			}

			if status != errSecSuccess {
				let message = SecCopyErrorMessageString(status, nil) as String? ?? String(localized: "Unknown Keychain error")
				throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
			}
		} else {
			// Delete existing item
			let status = SecItemDelete(query as CFDictionary)

			if status != errSecSuccess && status != errSecItemNotFound {
				let message = SecCopyErrorMessageString(status, nil) as String? ?? String(localized: "Unknown Keychain error")
				throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
			}
		}
	}

	/// Gets a configuration value for the given key from the Keychain.
	/// - Parameter key: The configuration key to read.
	/// - Returns: The stored string value, or nil if not found.
	public func get() throws -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: Self.service,
			kSecAttrAccount as String: self.rawValue,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne,
		]

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)

		switch status {
		case errSecSuccess:
			if let data = item as? Data, let value = String(data: data, encoding: .utf8) {
				return value
			} else if let data = (item as AnyObject) as? Data, let value = String(data: data, encoding: .utf8) {  // defensive
				return value
			} else {
				return nil
			}
		case errSecItemNotFound:
			return nil
		default:
			let message = SecCopyErrorMessageString(status, nil) as String? ?? String(localized: "Unknown Keychain error")
			throw NSError(domain: "Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
		}
	}
}

