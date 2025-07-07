//
//  VZMacAddressParseableFormatStyle.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/06/2025.
//

import Foundation
import Virtualization

struct VZMacAddressParseableFormatStyle : ParseableFormatStyle {
	struct VZMacAddressStrategy: ParseStrategy {
		func parse(_ input: String) throws -> VZMACAddress {
			guard let macAddr = VZMACAddress(string: input) else {
				throw NSError(domain: "VZMacAddressStrategy", code: 1, userInfo: nil)
			}
			
			return macAddr
		}
	}

	var parseStrategy = VZMacAddressStrategy()
	
	func format(_ value: VZMACAddress) -> String {
		return value.string.uppercased()
	}
}

struct OptionalVZMacAddressParseableFormatStyle : ParseableFormatStyle {
	struct OptionalVZMacAddressStrategy: ParseStrategy {
		func parse(_ input: String) throws -> VZMACAddress? {
			guard let macAddr = VZMACAddress(string: input) else {
				throw NSError(domain: "VZMacAddressStrategy", code: 1, userInfo: nil)
			}
			
			return macAddr
		}
	}

	var parseStrategy = OptionalVZMacAddressStrategy()
	
	func format(_ value: VZMACAddress?) -> String {
		guard let value = value else {
			return ""
		}

		return value.string.uppercased()
	}
}

struct OptionalMacAddressParseableFormatStyle : ParseableFormatStyle {
	struct OptionalMacAddressStrategy: ParseStrategy {
		func parse(_ input: String) throws -> String? {
			guard let macAddr = VZMACAddress(string: input) else {
				return nil
			}
			
			return macAddr.string.uppercased()
		}
	}

	var parseStrategy = OptionalMacAddressStrategy()
	
	func format(_ value: String?) -> String {
		guard let value = value else {
			return ""
		}

		guard let value = VZMACAddress(string: value) else {
			return ""
		}

		return value.string.uppercased()
	}
}

extension FormatStyle where Self == VZMacAddressParseableFormatStyle {
	static var macAddress: VZMacAddressParseableFormatStyle {
		VZMacAddressParseableFormatStyle()
	}
}

extension FormatStyle where Self == OptionalVZMacAddressParseableFormatStyle {
	static var optionalMacAddress: OptionalVZMacAddressParseableFormatStyle {
		OptionalVZMacAddressParseableFormatStyle()
	}
}
