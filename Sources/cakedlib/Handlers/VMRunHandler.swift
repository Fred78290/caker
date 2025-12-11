import ArgumentParser
import Cocoa
import Foundation
import GRPCLib
import Logging
import NIO
import System
import Virtualization

public struct VMRunHandler {
	public static var launchedFromService = false
	public static var serviceMode: VMRunServiceMode = .grpc

	public enum DisplayMode: String, CustomStringConvertible, ExpressibleByArgument, CaseIterable, EnumerableFlag {
		public var description: String {
			switch self {
			case .none: return "none"
			case .ui: return "ui"
			case .vnc: return "vnc"
			case .all: return "all"
			}
		}

		case none
		case ui
		case vnc
		case all
	}

	public let storageLocation: StorageLocation
	public let location: VMLocation
	public let name: String
	public let runMode: Utils.RunMode
	public let display: DisplayMode
	public let config: CakeConfig
	public let mode: VMRunServiceMode
	public let vncPassword: String
	public let vncPort: Int
	public let captureMethod: VNCCaptureMethod
	public let screenSize: CGSize

	public init(_ mode: VMRunServiceMode, storageLocation: StorageLocation, location: VMLocation, name: String, display: DisplayMode, config: CakeConfig, screenSize: CGSize, vncPassword: String, vncPort: Int, captureMethod: VNCCaptureMethod, runMode: Utils.RunMode) {
		self.storageLocation = storageLocation
		self.location = location
		self.name = name
		self.runMode = runMode
		self.display = display
		self.config = config
		self.mode = mode
		self.vncPort = vncPort
		self.vncPassword = vncPassword
		self.captureMethod = captureMethod
		self.screenSize = screenSize
	}

	public func run(_ completionHandler: @escaping (EventLoopFuture<String?>, VirtualMachine) -> Void) throws {
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

		let result = try location.startVirtualMachine(mode, on: Utilities.group.next(), config: config, screenSize: screenSize, display: display, vncPassword: vncPassword, vncPort: vncPort, captureMethod: captureMethod, internalCall: false, runMode: runMode)

		completionHandler(result.address, result.vm)
	}
}
