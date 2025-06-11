import Dispatch
import Foundation
import GRPCLib
import NIOCore
import Virtualization

struct ConfigureHandler: CakedCommandAsync, Sendable {
	var options: ConfigureOptions

	static func configure(name: String, options: ConfigureOptions, runMode: Utils.RunMode) throws -> String {
		let vmLocation = try StorageLocation(runMode: runMode).find(name)
		let config = try vmLocation.config()

		if let cpu = options.cpu {
			config.cpuCount = Int(cpu)
		}

		if let memory = options.memory {
			config.memorySize = memory * 1024 * 1024
		}

		if options.randomMAC {
			config.macAddress = VZMACAddress.randomLocallyAdministered()
		}

		if let displayRefit = options.displayRefit {
			config.displayRefit = displayRefit
		}

		if let autostart = options.autostart {
			config.autostart = autostart
		}

		if let nested = options.nested {
			config.nested = nested
		}

		if let mounts = options.mounts {
			config.mounts = mounts
		}

		if let networks = options.networks {
			config.networks = networks
		}

		if let sockets = options.sockets {
			config.sockets = sockets
		}

		if let consoleURL = options.consoleURL {
			config.console = consoleURL
		}

		if let forwardedPort = options.forwardedPort {
			config.forwardedPorts = forwardedPort
		}

		if let attachedDisks = options.attachedDisks {
			config.attachedDisks = attachedDisks
		}

		if let dynamicPortForwarding = options.dynamicPortForwarding {
			config.dynamicPortFarwarding = dynamicPortForwarding
		}

		if let suspendable = options.suspendable {
			config.suspendable = suspendable
		}

		try config.save()

		if let diskSize = options.diskSize {
			if vmLocation.status == .running {
				throw ServiceError("VM is running, please stop it before resizing the disk")
			}

			if config.os == .linux {
				try vmLocation.resizeDisk(diskSize)
			} else {
				try vmLocation.expandDisk(diskSize)
			}
		}

		return "VM \(name) reconfigured"
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		return on.submit {
			return try Caked_Reply.with { reply in
				reply.vms = try Caked_VirtualMachineReply.with {
					$0.message = try Self.configure(name: self.options.name, options: options, runMode: runMode)
				}
			}
		}
	}
}
