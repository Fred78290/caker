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

	/// Default of `imdsEnabled`: IMDS is on until it is turned off.
	public static let defaultImdsEnabled = true
	/// Default of `primaryName`: the VM `sh`/`exec`/`run` use when none is named.
	public static let defaultPrimaryName = "primary"
	/// Default of `composeDnsDomain`: the domain the compose DNS resolver answers for.
	public static let defaultComposeDnsDomain = "compose.internal"

	case bridgedNetwork = "local.bridged-network"
	case driver = "local.driver"
	case imageMirror = "local.image.mirror"
	case passphrase = "local.passphrase"
	case privilegedMounts = "local.privileged-mounts"
	case primaryName = "client.primary-name"
	case imdsEnabled = "client.imds-enabled"
	case cakeHome = "local.cake-home"
	case composeDnsDomain = "local.compose-dns-domain"

	/// The value a key has while it was never set: the default its readers apply, and what
	/// `get` prints. `nil` when "unset" has its own meaning (`bridgedNetwork`: no default bridged
	/// interface, `passphrase`: none, `cakeHome`: the platform's default home) or when nothing
	/// reads the key yet. The switch is exhaustive so that a new key has to decide its default here.
	public var defaultValue: Any? {
		switch self {
		case .imdsEnabled:
			return Self.defaultImdsEnabled
		case .primaryName:
			return Self.defaultPrimaryName
		case .composeDnsDomain:
			return Self.defaultComposeDnsDomain
		case .bridgedNetwork, .driver, .imageMirror, .passphrase, .privilegedMounts, .cakeHome:
			return nil
		}
	}

	/// Whether the key holds a boolean. It is stored as a `Bool`, the type `@AppStorage` reads and writes.
	public var isBoolean: Bool {
		self.defaultValue is Bool
	}

	/// What `get` prints: the stored value, or the key's default while it is unset. Booleans print
	/// as `true`/`false` whether they were stored by `set` (formerly as a string) or by Caker.app.
	public var stringValue: String? {
		if self.isBoolean {
			return String(self.bool())
		}

		return self.string()
	}

	/// Parses the spellings `set` accepts for a boolean key, case-insensitively; `nil` for anything else.
	public static func parseBool(_ value: String) -> Bool? {
		switch value.trimmingCharacters(in: .whitespaces).lowercased() {
		case "true", "yes", "on", "1":
			return true
		case "false", "no", "off", "0":
			return false
		default:
			return nil
		}
	}

	/// Sets a configuration value for the given key. This shim delegates to Keychain storage.
	/// Replace this with the real API if available (e.g., CakedLib.Config or SettingsHandler).
	public func set<T>(_ value: T?) {
		UserDefaults.shared.set(value, forKey: self.rawValue)  // Store in UserDefaults for quick access
	}

	/// Gets the raw stored value for the given key, without falling back to the key's default.
	/// - Returns: The stored value, or nil if not set or not a `T`.
	public func get<T>() -> T? {
		return UserDefaults.shared.object(forKey: self.rawValue) as? T
	}

	public func removeObject() {
		return UserDefaults.shared.removeObject(forKey: self.rawValue)
	}

	// The typed accessors below return `defaultValue` when the key is unset, or the key's own
	// `defaultValue` when the caller passes none.

	public func string(_ defaultValue: String? = nil) -> String? {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? String)
		}

		return UserDefaults.shared.string(forKey: self.rawValue)
	}

	public func array(_ defaultValue: [Any]? = nil) -> [Any]? {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? [Any])
		}

		return UserDefaults.shared.array(forKey: self.rawValue)
	}

	public func dictionary(_ defaultValue: [String : Any]? = nil) -> [String : Any]? {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? [String : Any])
		}

		return UserDefaults.shared.dictionary(forKey: self.rawValue)
	}

	public func data(_ defaultValue: Data? = nil) -> Data? {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? Data)
		}

		return UserDefaults.shared.data(forKey: self.rawValue)
	}

	public func stringArray(_ defaultValue: [String]? = nil) -> [String]? {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? [String])
		}

		return UserDefaults.shared.stringArray(forKey: self.rawValue)
	}

	public func integer(_ defaultValue: Int? = nil) -> Int {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? Int) ?? 0
		}

		return UserDefaults.shared.integer(forKey: self.rawValue)
	}

	public func float(_ defaultValue: Float? = nil) -> Float {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? Float) ?? 0.0
		}

		return UserDefaults.shared.float(forKey: self.rawValue)
	}

	public func double(_ defaultValue: Double? = nil) -> Double {
		guard self.exists() else {
			return defaultValue ?? (self.defaultValue as? Double) ?? 0.0
		}

		return UserDefaults.shared.double(forKey: self.rawValue)
	}

	public func bool(_ defaultValue: Bool? = nil) -> Bool {
		let fallback = defaultValue ?? (self.defaultValue as? Bool) ?? false

		guard let stored = UserDefaults.shared.object(forKey: self.rawValue) else {
			return fallback
		}

		// `set` used to store every value as a string; parse it rather than relying on how
		// `UserDefaults.bool(forKey:)` converts strings. An unrecognized string means the default.
		if let value = stored as? String {
			return Self.parseBool(value) ?? fallback
		}

		return UserDefaults.shared.bool(forKey: self.rawValue)
	}

	/// Returns true if a value exists for this key in UserDefaults.shared
	public func exists() -> Bool {
		UserDefaults.shared.object(forKey: self.rawValue) != nil
	}
}
