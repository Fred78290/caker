import Foundation
import NIOCore
import NIOPosix
import Virtualization
import GRPCLib

// This class represents the console device and socket devices that is used to communicate with the virtual machine.
class CommunicationDevices {
	let virtioSocketDevices: VirtioSocketDevices
	let consoleDevice: ConsoleDevice

	var delegate: VirtioSocketDeviceDelegate? {
		set {
			virtioSocketDevices.delegate = newValue
		}
		
		get {
			return virtioSocketDevices.delegate
		}
	}

	private init(group: EventLoopGroup, configuration: VZVirtualMachineConfiguration, consoleURL: URL?, sockets: [SocketDevice], delegate: VirtioSocketDeviceDelegate? = nil) throws {
		self.virtioSocketDevices = VirtioSocketDevices.setupVirtioSocketDevices(on: group, configuration: configuration, sockets: sockets, delegate: delegate)
		self.consoleDevice = try ConsoleDevice.setupConsole(on: group, consoleURL: consoleURL, configuration: configuration)
	}

	// Close the communication devices
	public func close() {
		virtioSocketDevices.close()
		consoleDevice.close()
	}

	// Connect the virtual machine to the devices
	public func connect(virtualMachine: VZVirtualMachine) {
		virtioSocketDevices.connect(virtualMachine: virtualMachine)
	}

	// Create the communication devices console and socket devices
	public static func setup(group: EventLoopGroup, configuration: VZVirtualMachineConfiguration, consoleURL: URL?, sockets: [SocketDevice], delegate: VirtioSocketDeviceDelegate? = nil) throws -> CommunicationDevices {
		return try CommunicationDevices(group: group, configuration: configuration, consoleURL: consoleURL, sockets: sockets, delegate: delegate)
	}
}
