//
//  Settings.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//
import Foundation

@propertyWrapper
struct Setting<T> {
	private(set) var keyName: String
	private var defaultValue: T
	
	var wrappedValue: T {
		get {
			let defaults = UserDefaults.standard
			guard let value = defaults.value(forKey: keyName) else {
				return defaultValue
			}
			return value as! T
		}
		
		set {
			let defaults = UserDefaults.standard
			defaults.set(newValue, forKey: keyName)
		}
	}
	
	init(wrappedValue: T, _ keyName: String) {
		self.defaultValue = wrappedValue
		self.keyName = keyName
	}
}
