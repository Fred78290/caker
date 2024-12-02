import ArgumentParser
import Foundation
import TextTable

extension Data {
	func toString() -> String {
		return String(decoding: self, as: UTF8.self)
	}
}

public enum Format: String, ExpressibleByArgument, CaseIterable {
	case text, json

	public private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}

	public func renderSingle<T>(_ data: T) -> String where T: Encodable {
		switch self {
		case .text:
			return renderList([data])
		case .json:
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			return try! encoder.encode(data).toString()
		}
	}

	public func renderList<T>(_ data: Array<T>) -> String where T: Encodable {
		switch self {
		case .text:
			if (data.count == 0) {
				return ""
			}
			let table = TextTable<T> { (item: T) in
				return Mirror(reflecting: item).children.enumerated()
					.map { (_, element) in
						let label = element.label ?? "<unknown>"
						return Column(title: label, value: element.value)
					}
			}

			return table.string(for: data, style: Style.plain)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		case .json:
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			return try! encoder.encode(data).toString()
		}
	}
}
