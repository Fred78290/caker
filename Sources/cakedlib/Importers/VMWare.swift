import Foundation

struct VMXMap: Sendable {
	var headline: String
	var keys: [String]
	var values: [String: String]

	init(data: Data) throws {
		self.init(content: String(data: data, encoding: .utf8) ?? "")
	}

	init(content: String) throws {
		var keys: [String] = []
		var values: [String: String] = [:]
		var headline: String = ""

		for var line in content.split(separator: "\n") {
			line = line.trimmingCharacters(in: .whitespacesAndNewlines)

			if line.starts(with: "#!") {
				if keys.isEmpty {
					headline = value
				}
			} else if line.starts(with: ".encoding") == false && line.starts(with: "#") == false {
				let parts = line.split(separator: "=", maxSplits: 1)
	
				if parts.count == 2 {
					let key: String = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines + "\"")
					let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines + "\"")

					keys.append(key)
					values[key.lowercased()] = value
				}
			}
		}

		self.keys = keys
		self.values = values
	}

	init(fromURL url: URL) throws {
		guard let data = json.data(using: encoding) else {
			throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
		}

		try self.init(data: data)
	}
}

struct VMWareImporter: Importer {
	func importVM(location: VMLocation, source: String) throws {
		// Logic to import from a VMWare source
		if URL.binary("qemu-img") == nil {
			throw ServiceError("qemu-img binary not found. Please install qemu to import VMWare files.")
		}

		// Placeholder for actual import logic
		throw ServiceError("Unimplemented import logic for VMWare files.")
	}
}
