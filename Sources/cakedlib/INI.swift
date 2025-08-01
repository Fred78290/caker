import Foundation

typealias INISectionConfig = [String: String]
typealias INIConfig = [String: INISectionConfig]

extension INIConfig {
	private static func trim(_ s: String) -> String {
		let whitespaces = CharacterSet(charactersIn: " \n\r\t")
		return s.trimmingCharacters(in: whitespaces)
	}

	private static func stripComment(_ line: String) -> String {
		let parts = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)

		if parts.count > 0 {
			return String(parts[0])
		}

		return ""
	}

	private static func parseSectionHeader(_ line: String) -> String {
		let from = line.index(after: line.startIndex)
		let to = line.index(before: line.endIndex)

		return String(line[from..<to])
	}

	private static func parseLine(_ line: String) -> (String, String)? {
		let parts = stripComment(line).split(separator: "=", maxSplits: 1)

		if parts.count == 2 {
			let k = trim(String(parts[0]))
			let v = trim(String(parts[1]))
			return (k, v)
		}

		return nil
	}

	private static func parseConfig(_ from: URL) throws -> INIConfig {
		let f = try String(contentsOf: from, encoding: .utf8)

		var currentSectionName = "main"
		var config: INIConfig = [:]

		for line in f.components(separatedBy: "\n") {
			let line = trim(line)

			if line.hasPrefix("[") && line.hasSuffix("]") {
				currentSectionName = parseSectionHeader(line)
			} else if let (k, v) = parseLine(line) {
				var section = config[currentSectionName] ?? [:]

				section[k] = v

				config[currentSectionName] = section
			}
		}

		return config
	}

	init(from url: URL) throws {
		self = try Self.parseConfig(url)
	}
}
