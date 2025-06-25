//
//  OptionalStringFormatStyle.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/06/2025.
//

import Foundation

struct OptionalStringStrategy: ParseStrategy {
	func parse(_ input: String) throws -> String? {
		if input.isEmpty {
			return nil
		}

		return input
	}
}

struct OptionalStringFormatStyle: ParseableFormatStyle {
	var parseStrategy = OptionalStringStrategy()

	func format(_ value: String?) -> String {
		guard let value else {
			return ""
		}
		
		return value
	}
}

extension FormatStyle where Self == OptionalStringFormatStyle {
	static var optional: OptionalStringFormatStyle {
		OptionalStringFormatStyle()
	}
}
