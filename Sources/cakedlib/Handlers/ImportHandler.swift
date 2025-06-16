import Foundation
import ArgumentParser
import GRPCLib

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
	}

	private static func importFromMultipass(location: VMLocation, path: String) async throws {
		// Logic to import from a multipass source
		throw ServiceError("Unimplemented import logic for Multipass files.")
	}

	private static func importFromVMDK(location: VMLocation, path: String) async throws {
		// Logic to import from a VMDK source
		if URL.binary("qemu-img") == nil {
			throw ServiceError("qemu-img binary not found. Please install qemu to import VMDK files.")
		}

		throw ServiceError("Unimplemented import logic for VMDK files.")
	}

	public static func importVM(from: ImportSource, name: String, source: String, runMode: Utils.RunMode) async throws -> Caked_Reply {	
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
			switch from {
			case .multipass:
				try await importFromMultipass(location: tempLocation, path: source)
			case .vmdk:	
				try await importFromVMDK(location: tempLocation, path: source)
			}

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
					$0.code
					$0.reason = "Failed to import VM from \(from) at \(source), \(error.localizedDescription)"
				}
			}
		}
	}
}
