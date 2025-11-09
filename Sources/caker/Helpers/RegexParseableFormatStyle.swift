//
//  RegexParseableFormatStyle.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/06/2025.
//

import Foundation

struct RegexParseableFormatStyle: ParseableFormatStyle {
	struct RegexStategy: ParseStrategy {
		let regex: String

		init(regex: String) {
			self.regex = regex
		}

		func parse(_ value: String) throws -> String {
			
			guard value.range(of: self.regex, options: .regularExpression) != nil else {
				return ""
			}

			return value
		}
	}

	var parseStrategy: RegexStategy

	init(regex: String) {
		self.parseStrategy = .init(regex: regex)
	}

	func format(_ value: String) -> String {
		return value
	}
}

extension FormatStyle where Self == RegexParseableFormatStyle {
	static func regex(_ pattern: String) -> RegexParseableFormatStyle {
		.init(regex: pattern)
	}
}
