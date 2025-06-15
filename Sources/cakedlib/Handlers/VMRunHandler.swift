import Cocoa
import Foundation
import GRPCLib
import Logging
import System
import Virtualization

public struct VMRunHandler {
	public static var launchedFromService = false

	let storageLocation: StorageLocation
	let vmLocation: VMLocation
	let name: String
	let runMode: Utils.RunMode
	let display: Bool
	let config: CakeConfig

	public init(storageLocation: StorageLocation, vmLocation: VMLocation, name: String, runMode: Utils.RunMode, display: Bool, config: CakeConfig) {
		self.storageLocation = storageLocation
		self.vmLocation = vmLocation
		self.name = name
		self.runMode = runMode
		self.display = display
		self.config = config
	}

	public func run(_ completionHandler: @escaping (VirtualMachine) -> Void) throws {
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
				Logger(self).warn("This VM \(vmHavingSameMacAddress!.value.name) is running with the same mac address. Generating a new mac address")
				config.resetMacAddress()
				try config.save()
			}
		}

		let (_, vm) = try vmLocation.startVirtualMachine(on: Utilities.group.next(), config: config, internalCall: false, runMode: runMode)

		completionHandler(vm)
/*		if display {
			MainApp.runUI(name: name, vm: vm, config: config)
		} else {
			NSApplication.shared.setActivationPolicy(.prohibited)
			NSApplication.shared.run()
		}*/
	}
}
