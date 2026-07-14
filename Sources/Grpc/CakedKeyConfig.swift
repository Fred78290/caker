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
	case imdsEnabled = "client.imds-enabled"
	
	/// Sets a configuration value for the given key. This shim delegates to Keychain storage.
	/// Replace this with the real API if available (e.g., CakedLib.Config or SettingsHandler).
	public func set<T>(_ value: T?) {
		UserDefaults.shared.set(value, forKey: self.rawValue)  // Store in UserDefaults for quick access
	}
	
	/// Gets a configuration value for the given key from the Keychain.
	/// - Parameter key: The configuration key to read.
	/// - Returns: The stored string value, or nil if not found.
	public func get<T>() -> T? {
		return UserDefaults.shared.object(forKey: self.rawValue) as? T
	}
	
	public func removeObject() {
		return UserDefaults.shared.removeObject(forKey: self.rawValue)
	}

	public func string() -> String? {
		return UserDefaults.shared.string(forKey: self.rawValue)
	}

	public func array() -> [Any]? {
		return UserDefaults.shared.array(forKey: self.rawValue)
	}
	
	public func dictionary() -> [String : Any]? {
		return UserDefaults.shared.dictionary(forKey: self.rawValue)
	}

	public func data() -> Data? {
		return UserDefaults.shared.data(forKey: self.rawValue)
	}
	
	public func stringArray() -> [String]? {
		return UserDefaults.shared.stringArray(forKey: self.rawValue)
	}

	public func integer() -> Int {
		return UserDefaults.shared.integer(forKey: self.rawValue)
	}
	
	public func float() -> Float {
		return UserDefaults.shared.float(forKey: self.rawValue)
	}
	
	public func double() -> Double {
		return UserDefaults.shared.double(forKey: self.rawValue)
	}
	
	public func bool() -> Bool {
		return UserDefaults.shared.bool(forKey: self.rawValue)
	}
}

