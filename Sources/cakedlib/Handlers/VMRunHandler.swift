import ArgumentParser
import CakeAgentLib
import Cocoa
import Foundation
import GRPCLib
import NIO
import System
import Virtualization

public struct VMRunHandler {
	public static var launchedFromService = false
	public static var serviceMode: VMRunServiceMode = VMRunServiceMode.default

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
	public let screenSize: CGSize
	public let recoveryMode: Bool
	public let provisioning: Bool

	public init(
		mode: VMRunServiceMode,
		storageLocation: StorageLocation,
		location: VMLocation,
		name: String,
		display: DisplayMode,
		config: CakeConfig,
		screenSize: CGSize,
		vncPassword: String,
		vncPort: Int,
		recoveryMode: Bool,
		provisioning: Bool,
		runMode: Utils.RunMode
	) {
		self.storageLocation = storageLocation
		self.location = location
		self.name = name
		self.runMode = runMode
		self.display = display
		self.config = config
		self.mode = mode
		self.vncPort = vncPort
		self.vncPassword = vncPassword
		self.screenSize = screenSize
		self.recoveryMode = recoveryMode
		self.provisioning = provisioning
	}

	public typealias CompletionHandler<T> = (EventLoopFuture<String?>, VirtualMachine) throws -> T
	public typealias AsyncCompletionHandler<T> = (EventLoopFuture<String?>, VirtualMachine) async throws -> T

	@MainActor
	public func run<T>(queue: DispatchQueue? = nil, _ completionHandler: CompletionHandler<T>) throws -> T {
		if let macAddress = config.macAddress {
			let vmHavingSameMacAddress = try storageLocation.list().first {
				var result = false

				if let addr = $1.macAddress {
					if case .running = $1.status {
						result = addr.string == macAddress
					} else {
						result = false
					}
				}

				return result
			}

			if vmHavingSameMacAddress != nil {
				Logger(self).warn("This VM \(vmHavingSameMacAddress!.value.name) is running with the same mac address. Generating a new mac address")
				config.resetMacAddress()
				try config.save()
			}
		}

		let result = try location.startVirtualMachine(
			mode: mode, on: Utilities.group.next(),
			config: config,
			screenSize: screenSize,
			display: display,
			vncPassword: vncPassword,
			vncPort: vncPort,
			recoveryMode: self.recoveryMode,
			provisioning: provisioning,
			runMode: runMode,
			queue: queue)

		return try completionHandler(result.address, result.vm)
	}

	public func run(queue: DispatchQueue? = nil) async throws -> (address: EventLoopFuture<String?>, vm: VirtualMachine) {
		if let macAddress = config.macAddress {
			let vmHavingSameMacAddress = try storageLocation.list().first {
				var result = false

				if let addr = $1.macAddress {
					if case .running = $1.status {
						result = addr.string == macAddress
					} else {
						result = false
					}
				}

				return result
			}

			if vmHavingSameMacAddress != nil {
				Logger(self).warn("This VM \(vmHavingSameMacAddress!.value.name) is running with the same mac address. Generating a new mac address")
				config.resetMacAddress()
				try config.save()
			}
		}

		return try await location.startVirtualMachine(
			mode: mode,
			on: Utilities.group.next(),
			config: config,
			screenSize: screenSize,
			display: display,
			vncPassword: vncPassword,
			vncPort: vncPort,
			recoveryMode: self.recoveryMode,
			provisioning: false,
			runMode: runMode,
			queue: queue)
	}
}
