//
//  MemorySizeStyle.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/07/2025.
//

import Foundation

struct MemorySizeStyle: ParseableFormatStyle {
	var parseStrategy: MemorySizeStategy
	let units: MemorySizeStategy.Units

	init(units: MemorySizeStategy.Units) {
		self.units = units
		self.parseStrategy = .init(units: units)
	}

	func format(_ value: UInt64) -> String {
		return units.convert(value)
	}
}

struct OptionalMemorySizeStyle: ParseableFormatStyle {
	var parseStrategy: OptionalMemorySizeStategy
	let units: OptionalMemorySizeStategy.Units

	init(units: OptionalMemorySizeStategy.Units) {
		self.units = units
		self.parseStrategy = .init(units: units)
	}

	func format(_ value: UInt64?) -> String {
		return units.convert(value)
	}
}

struct MemorySizeStategy: ParseStrategy {
	let units: Units

	enum Units: UInt64, Codable {
		case useBytes
		case useKB
		case useMB
		case useGB
		
		func convert(_ value: UInt64) -> String {
			switch self {
			case .useBytes:
				return "\(value)"
			case .useKB:
				return "\(value * 1024)"
			case .useMB:
				return "\(value * (1024 * 1024))"
			case .useGB:
				return "\(value * (1024 * 1024 * 1024))"
			}
		}
		
		func convert(_ value: String) -> UInt64 {
			if let value = UInt64(value) {
				switch self {
				case .useBytes:
					return value
				case .useKB:
					return value / 1024
				case .useMB:
					return value / (1024 * 1024)
				case .useGB:
					return value / (1024 * 1024 * 1024)
				}
			}

			return 0
		}
	}

	init(units: Units) {
		self.units = units
	}

	func parse(_ value: String) throws -> UInt64 {
		return units.convert(value)
	}
}

struct OptionalMemorySizeStategy: ParseStrategy {
	let units: Units

	enum Units: UInt64, Codable {
		case useBytes
		case useKB
		case useMB
		case useGB
		
		func convert(_ value: UInt64?) -> String {
			guard let value = value else {
				return ""
			}
			
			switch self {
			case .useBytes:
				return "\(value)"
			case .useKB:
				return "\(value * 1024)"
			case .useMB:
				return "\(value * (1024 * 1024))"
			case .useGB:
				return "\(value * (1024 * 1024 * 1024))"
			}
		}
		
		func convert(_ value: String) -> UInt64? {
			if let value = UInt64(value) {
				switch self {
				case .useBytes:
					return value
				case .useKB:
					return value / 1024
				case .useMB:
					return value / (1024 * 1024)
				case .useGB:
					return value / (1024 * 1024 * 1024)
				}
			}

			return nil
		}
	}

	init(units: Units) {
		self.units = units
	}

	func parse(_ value: String) throws -> UInt64? {
		return units.convert(value)
	}
}

extension FormatStyle where Self == MemorySizeStyle {
	static func memory(_ units: MemorySizeStategy.Units = .useGB) -> MemorySizeStyle {
		return MemorySizeStyle(units: units)
	}
}

extension FormatStyle where Self == OptionalMemorySizeStyle {
	static func optionalMemory(_ units: OptionalMemorySizeStategy.Units = .useGB) -> OptionalMemorySizeStyle {
		return OptionalMemorySizeStyle(units: units)
	}
}
