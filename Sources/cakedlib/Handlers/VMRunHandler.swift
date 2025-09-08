import Cocoa
import Foundation
import GRPCLib
import Logging
import System
import Virtualization
import ArgumentParser

public struct VMRunHandler {
	public static var launchedFromService = false
	public static var serviceMode: VMRunServiceMode = .grpc

	public enum DisplayMode: String, CustomStringConvertible, ExpressibleByArgument, CaseIterable, EnumerableFlag {
		public var description: String {
			switch self {
			case .none: return "none"
			case .ui: return "ui"
			case .vnc: return "vnc"
			}
		}
		
		case none
		case ui
		case vnc
	}

	let storageLocation: StorageLocation
	let location: VMLocation
	let name: String
	let runMode: Utils.RunMode
	let display: DisplayMode
	let config: CakeConfig
	let mode: VMRunServiceMode

	public init(_ mode: VMRunServiceMode, storageLocation: StorageLocation, location: VMLocation, name: String, runMode: Utils.RunMode, display: DisplayMode, config: CakeConfig) {
		self.storageLocation = storageLocation
		self.location = location
		self.name = name
		self.runMode = runMode
		self.display = display
		self.config = config
		self.mode = mode
	}

	public func run(display: VMRunHandler.DisplayMode, vncPassword: String, vncPort: Int, _ completionHandler: @escaping (VirtualMachine) -> Void) throws {
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

		let (_, vm) = try location.startVirtualMachine(mode, on: Utilities.group.next(), config: config, display: display, vncPassword: vncPassword, vncPort: vncPort, internalCall: false, runMode: runMode)

		completionHandler(vm)
	}
}
