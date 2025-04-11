import Dispatch
import Foundation
import Virtualization
import GRPCLib
import NIOCore

struct ConfigureHandler: CakedCommandAsync, Sendable {
	var options: ConfigureOptions

	static func configure(name: String, options: ConfigureOptions, asSystem: Bool) throws {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(name)
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

		try config.save()

		if let diskSize = options.diskSize {
			try vmLocation.expandDiskTo(diskSize)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		return on.submit {
			try Self.configure(name: self.options.name, options: options, asSystem: asSystem)

			return Caked_Reply.with { reply in
				reply.vms = Caked_VirtualMachineReply.with {
					$0.message = "VM \(self.options.name) configured"
				}
			}
		}
	}
}
