import Foundation
import System
import GRPCLib
import Cocoa
import Virtualization
import Logging

struct VMRunHandler {
	let storageLocation: StorageLocation
	let vmLocation: VMLocation
	let name: String
	let asSystem: Bool
	let display: Bool
	let config: CakeConfig

	func handle() throws {
		defer {
			vmLocation.removePID()
		}

		if let macAddress = config.macAddress {
			let vmHavingSameMacAddress = try storageLocation.list().first {
				var result = false

				if let addr = $1.macAddress {
					result = $1.status == .running && addr.string == macAddress.string
				}

				return result
			}

			if vmHavingSameMacAddress != nil {
				Logger.warn("This VM \(vmHavingSameMacAddress!.value.name) is running with the same mac address. Generating a new mac address")
				config.resetMacAddress()
				try config.save()
			}
		}

		let (_, vm) = try vmLocation.startVirtualMachine(on: Root.group.next(), config: config, asSystem: asSystem)

		if display {
			MainApp.runUI(name: name, vm: vm, config: config)
		} else {
			NSApplication.shared.setActivationPolicy(.prohibited)
			NSApplication.shared.run()
		}
	}
}