import Cocoa
import Foundation
import GRPCLib
import Logging
import System
import Virtualization

public struct VMRunHandler {
	public static var launchedFromService = false

	let storageLocation: StorageLocation
	let location: VMLocation
	let name: String
	let runMode: Utils.RunMode
	let display: Bool
	let config: CakeConfig

	public init(storageLocation: StorageLocation, location: VMLocation, name: String, runMode: Utils.RunMode, display: Bool, config: CakeConfig) {
		self.storageLocation = storageLocation
		self.location = location
		self.name = name
		self.runMode = runMode
		self.display = display
		self.config = config
	}

	public func run(_ completionHandler: @escaping (VirtualMachine) -> Void) throws {
		defer {
			location.removePID()
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

		let (_, vm) = try location.startVirtualMachine(on: Utilities.group.next(), config: config, internalCall: false, runMode: runMode)

		completionHandler(vm)
/*		if display {
			MainApp.runUI(name: name, vm: vm, config: config)
		} else {
			NSApplication.shared.setActivationPolicy(.prohibited)
			NSApplication.shared.run()
		}*/
	}
}
