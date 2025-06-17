import ArgumentParser
import Foundation
import GRPCLib

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

		var importer: Importer {
			switch self {
			case .multipass:
				return MultipassImporter()
			case .vmdk:
				return VMWareImporter()
			}
		}
	}

	public static func importVM(from: ImportSource, name: String, source: String, runMode: Utils.RunMode) throws -> Caked_Reply {
		let storageLocation = StorageLocation(runMode: runMode)

		if storageLocation.exists(name) {
			return Caked_Reply.with { reply in
				reply.error = Caked_Error.with {
					$0.code = 1
					$0.reason = "VM with name \(name) already exists."
				}
			}
		}

		let tempLocation = try VMLocation.tempDirectory(runMode: runMode)

		do {
			try from.importer.importVM(location: tempLocation, source: source, runMode: runMode)
			try storageLocation.relocate(name, from: tempLocation)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = "VM \(name) imported successfully from \(from) at \(source)"
				}
			}
		} catch {
			try? tempLocation.delete()

			return Caked_Reply.with { reply in
				reply.error = Caked_Error.with {
					$0.code = 1
					$0.reason = "Failed to import VM from \(from) at \(source), \(error.localizedDescription)"
				}
			}
		}
	}
}
