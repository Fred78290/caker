import ArgumentParser
import Foundation
import GRPCLib
import CakeAgentLib

// /var/root/Library/Application Support/multipassd/qemu/multipassd-vm-instances.json
// /var/root/Library/Application Support/multipassd/qemu/vault/multipassd-instance-image-records.json

public struct ImportHandler {
	public enum ImportSource: String, ExpressibleByArgument, CaseIterable, Codable, Sendable {
		case multipass
		case vmdk

		public static let allValueStrings: [String] = Self.allCases.map { "\($0)" }

		public init?(argument: String) {
			switch argument {
			case "multipass":
				self = .multipass
			case "vmdk":
				self = .vmdk
			default:
				return nil
			}
		}

		public var importer: Importer {
			switch self {
			case .multipass:
				return MultipassImporter()
			case .vmdk:
				return VMWareImporter()
			}
		}
	}

	public static func importVM(importer: Importer, name: String, source: String, userName: String, password: String, sshPrivateKey: String?, passphrase: String?, uid: UInt32, gid: UInt32, runMode: Utils.RunMode) -> ImportedReply {
		let storageLocation = StorageLocation(runMode: runMode)

		if importer.needSudo && geteuid() != 0 {
			return ImportedReply(source: source, name: name, imported: false, reason: "Importing from \(importer.name) requires root privileges.")
		} else if storageLocation.exists(name) {
			return ImportedReply(source: source, name: name, imported: false, reason: "VM already exists")
		} else {
			var tempLocation: VMLocation! = nil

			do {
				tempLocation = try VMLocation.tempDirectory(runMode: runMode)

				try importer.importVM(location: tempLocation, source: source, userName: userName, password: password, sshPrivateKey: sshPrivateKey, passphrase: passphrase, runMode: runMode)
				try FileManager.default.setAttributesRecursively([.ownerAccountID: uid, .groupOwnerAccountID: gid], atPath: tempLocation.rootURL.path)
				try storageLocation.relocate(name, from: tempLocation)

				return ImportedReply(source: source, name: name, imported: true, reason: "VM imported successfully")
			} catch {
				try? tempLocation?.delete()

				return ImportedReply(source: source, name: name, imported: false, reason: "\(error)")
			}
		}
	}
}
