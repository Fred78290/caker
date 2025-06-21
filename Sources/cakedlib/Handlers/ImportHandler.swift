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

		public var importer: Importer {
			switch self {
			case .multipass:
				return MultipassImporter()
			case .vmdk:
				return VMWareImporter()
			}
		}
	}

	public static func importVM(importer: Importer, name: String, source: String, userName: String, password: String, sshPrivateKey: String?, passphrase: String?, uid: UInt32, gid: UInt32, runMode: Utils.RunMode) throws -> Caked_Reply {
		let storageLocation = StorageLocation(runMode: runMode)

		if importer.needSudo && geteuid() != 0 {
			return Caked_Reply.with { reply in
				reply.error = Caked_Error.with {
					$0.code = 1
					$0.reason = "Importing from \(importer.name) requires root privileges."
				}
			}
		}

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
			try importer.importVM(location: tempLocation, source: source, userName: userName, password: password, sshPrivateKey: sshPrivateKey, passphrase: passphrase, runMode: runMode)
			try FileManager.default.setAttributesRecursively([.ownerAccountID: uid, .groupOwnerAccountID: gid], atPath: tempLocation.rootURL.path)
			try storageLocation.relocate(name, from: tempLocation)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = "VM \(name) imported successfully from \(importer.name) at \(source)"
				}
			}
		} catch {
			try? tempLocation.delete()

			if let serviceError = error as? ServiceError {
				return Caked_Reply.with { reply in
					reply.error = Caked_Error.with {
						$0.code = serviceError.exitCode
						$0.reason = "Failed to import VM from \(importer.name) at \(source), \(serviceError.description)"
					}
				}
			}

			return Caked_Reply.with { reply in
				reply.error = Caked_Error.with {
					$0.code = 1
					$0.reason = "Failed to import VM from \(importer.name) at \(source), \(error)"
				}
			}
		}
	}
}
