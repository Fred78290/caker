import Dispatch
import Foundation
import GRPCLib
import NIOCore
import Virtualization

public struct ConfigureHandler {
	public static func configure(name: String, options: ConfigureOptions, runMode: Utils.RunMode) -> ConfiguredReply {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)
			let config = try location.config()

			if let user = options.user {
				config.configuredUser = user
			}

			if let password = options.password {
				config.configuredPassword = password
			}

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
				config.dynamicPortForwarding = dynamicPortForwarding
			}

			if let suspendable = options.suspendable {
				config.suspendable = suspendable
			}

			try config.save()

			if let diskSize = options.diskSize {
				if location.status == .running {
					throw ServiceError("VM is running, please stop it before resizing the disk")
				}

				if config.os == .linux {
					try location.resizeDisk(diskSize)
				} else {
					try location.expandDisk(diskSize)
				}
			}

			return ConfiguredReply(name: name, configured: true, reason: "VM reconfigured")
		} catch {
			return ConfiguredReply(name: name, configured: false, reason: "\(error)")
		}
	}
}
