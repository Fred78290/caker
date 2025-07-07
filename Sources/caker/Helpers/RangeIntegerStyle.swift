//
//  RangeIntegerStyle.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/06/2025.
//

import Foundation

struct RangeIntegerStyle: ParseableFormatStyle {
	var parseStrategy: RangeIntegerStrategy
	let range: ClosedRange<Int>
	
	init(range: ClosedRange<Int>) {
		self.range = range
		self.parseStrategy = .init(range: range)
	}
	
	func format(_ value: Int) -> String {
		let constrainedValue = min(max(value, range.lowerBound), range.upperBound)
		
		return "\(constrainedValue)"
	}

	func inRange(_ value: Int) -> Bool {
		return range.contains(value)
	}

	func outside(_ value: Int) -> Bool {
		return range.contains(value) == false
	}

	static var hostPortRange = RangeIntegerStyle.ranged(((geteuid() == 0 ? 1 : 1024)...65535))
	static var guestPortRange = RangeIntegerStyle.ranged(1...65535)
}

struct OptionalRangeIntegerStyle: ParseableFormatStyle {
	var parseStrategy: OptionalRangeIntegerStrategy = .init()
	let range: ClosedRange<Int>

	func format(_ value: Int?) -> String {
		guard let value = value else {
			return ""
		}

		let constrainedValue = min(max(value, range.lowerBound), range.upperBound)

		return "\(constrainedValue)"
	}
}

struct RangeIntegerStrategy: ParseStrategy {
	let range: ClosedRange<Int>

	func parse(_ value: String) throws -> Int {
		return Int(value) ?? range.lowerBound
	}
}

struct OptionalRangeIntegerStrategy: ParseStrategy {
	func parse(_ value: String) throws -> Int? {
		return Int(value) ?? nil
	}
}

/// Allow writing `.ranged(0...5)` instead of `RangeIntegerStyle(range: 0...5)`.
extension FormatStyle where Self == RangeIntegerStyle {
	static func ranged(_ range: ClosedRange<Int>) -> RangeIntegerStyle {
		return RangeIntegerStyle(range: range)
	}
}

extension FormatStyle where Self == OptionalRangeIntegerStyle {
	static func optional(_ range: ClosedRange<Int>) -> OptionalRangeIntegerStyle {
		return OptionalRangeIntegerStyle(range: range)
	}
}
