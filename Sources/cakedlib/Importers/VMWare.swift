import Foundation

struct VMXMap: Sendable {
	var headline: String
	var keys: [String]
	var values: [String: String]

	/// Represents a network attachment in a VMX file.
	struct EthernetAttachment: Sendable {
		enum ConnectionType: String {
			case bridged = "bridged"
			case nat = "nat"
			case hostOnly = "hostonly"
			case custom = "custom"
		}

		var macAddress: String
		var connectionType: ConnectionType
		var virtualDev: String
		var unitNumber: Int
	}

	/// Represents a disk attachment in a VMX file.
	struct DiskAttachement: Sendable {
		var disk: String
		var controller: String
		var unitNumber: Int
		var deviceType: String?
	}

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
		try self.init(data: try Data(contentsOf: url))
	}

	var ethernetAttachements: [EthernetAttachment] {
		var attachments: [EthernetAttachment] = []

		for unitNumber in 0...3 {
			let baseKey = "ethernet\(unitNumber)"

			if if let present = values["\(baseKey).present"] as Bool?, present == true {
				attachments.append(EthernetAttachment(macAddress: macAddress, name: name, type: type, unitNumber: unitNumber))
			}
		}

		return attachments
	}

	var diskAttachments: [DiskAttachement] {
		var attachment
		let controllers = ["nvme", "scsi", "sata"]

		controllers.forEach { controller in
			for controllerNumber in 0...3 {
				for diskNumber in 0...9 {
					// Construct the key for each disk attachment
					// Example: "ide0:0.fileName", "scsi1:2.fileName", etc.
					// The controllerNumber and diskNumber are used to differentiate between multiple disks on the same controller
					let baseKey = "\(controller)\(controllerNumber):\(diskNumber)"

					if let present = values["\(baseKey).present"] as Bool?, present == true {
						if let fileName = values["\(baseKey):deviceType".lowercased()] {
							let deviceType = values["\(baseKey):deviceType".lowercased()]

							attachment.append(DiskAttachement(disk: fileName, controller: controller, unitNumber: unitNumber, deviceType: deviceType))
						}
					}
				}
			}
		}

		return attachments
	}
}

struct VMWareImporter: Importer {
	func importVM(location: VMLocation, source: String) throws {
		// Logic to import from a VMWare source
		if URL.binary("qemu-img") == nil {
			throw ServiceError("qemu-img binary not found. Please install qemu to import VMWare files.")
		}

		let vmxMap = try locateVM(source: source)

		// Placeholder for actual import logic
		throw ServiceError("Unimplemented import logic for VMWare files.")
	}

	func locateVM(source: String) throws -> VMXMap {
		var url = URL(fileURLWithPath: source)
		var isDirectory: Bool = false

		if FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory) {
			guard isDirectory else {
				guard url.pathExtension.lowercased() == "vmx" else {
					throw ServiceError("The provided path is not a directory or a .vmx file.")
				}

				return try VMXMap(fromURL: vmxFile)
			}

			return findVMX(fromURL: url)
		}

		url = URL(fileURLWithPath: "~/Virtual Machines.localized/\(source).vmwarevm".expandingTildeInPath, isDirectory: true)

		guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
			throw ServiceError("No Virtual Machines directory found at \(url.path).")
		}

		guard isDirectory else {
			throw ServiceError("The provided path is not a directory. Please provide a valid Virtual Machines directory.")
		}

		return findVMX(fromURL: url)
	}

	func findVMX(fromURL url: URL) throws -> VMXMap {
		guard let vmxFile = try FileManager.default.contentsOfDirectory(at: url.path, includingPropertiesForKeys: nil).first(where: { $0.pathExtension.lowercased() == "vmx" }) else {
			throw ServiceError("No VMX files found in the specified directory: \(url.path)")
		}

		return try VMXMap(fromURL: vmxFile)
	}

}
