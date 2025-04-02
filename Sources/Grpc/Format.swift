import ArgumentParser
import Foundation
import TextTable

extension Data {
	func toString() -> String {
		return String(decoding: self, as: UTF8.self)
	}
}

public enum Format: String, ExpressibleByArgument, CaseIterable, Sendable {
	case text, json

	public private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}

	public func renderSingle<T>(style: TextTableStyle.Type = Style.plain, uppercased: Bool = false, _ data: T) -> String where T: Encodable {
		switch self {
		case .text:
			return renderList(style: style, uppercased: uppercased, [data])
		case .json:
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
			return try! encoder.encode(data).toString()
		}
	}

	public func renderList<T>(style: TextTableStyle.Type = Style.plain, uppercased: Bool = false, _ data: Array<T>) -> String where T: Encodable {
		switch self {
		case .text:
			if (data.count == 0) {
				return ""
			}
			let table = TextTable<T> { (item: T) in
				return Mirror(reflecting: item).children.enumerated()
					.map { (_, element) in
						let label = element.label ?? "<unknown>"
						return Column(title: uppercased ? label.uppercased() : label, value: element.value)
					}
			}

			return table.string(for: data, style: style)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		case .json:
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
			return try! encoder.encode(data).toString()
		}
	}
}
