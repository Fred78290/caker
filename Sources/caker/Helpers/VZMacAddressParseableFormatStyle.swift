//
//  VZMacAddressParseableFormatStyle.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/06/2025.
//

import Foundation
import Virtualization

struct VZMacAddressStrategy: ParseStrategy {
	func parse(_ input: String) throws -> VZMACAddress? {
		guard let macAddr = VZMACAddress(string: input) else {
			return nil
		}
		
		return macAddr
	}
}

struct VZMacAddressParseableFormatStyle : ParseableFormatStyle {
	var parseStrategy = VZMacAddressStrategy()
	
	func format(_ value: VZMACAddress?) -> String {
		guard let value = value else {
			return ""
		}
		
		return value.string
	}
}

struct OptionalVZMacAddressStrategy: ParseStrategy {
	func parse(_ input: String) throws -> String? {
		guard let macAddr = VZMACAddress(string: input) else {
			return nil
		}
		
		return macAddr.string
	}
}

struct OptionalVZMacAddressParseableFormatStyle : ParseableFormatStyle {
	var parseStrategy = OptionalVZMacAddressStrategy()
	
	func format(_ value: String?) -> String {
		guard let value = value else {
			return ""
		}
		
		guard let macAddr = VZMACAddress(string: value) else {
			return ""
		}

		return macAddr.string
	}
}

extension FormatStyle where Self == VZMacAddressParseableFormatStyle {
	static var macAddress: VZMacAddressParseableFormatStyle {
		VZMacAddressParseableFormatStyle()
	}
	
	static var optionalMacAddress: OptionalVZMacAddressParseableFormatStyle {
		OptionalVZMacAddressParseableFormatStyle()
	}
}
