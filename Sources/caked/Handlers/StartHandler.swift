import ArgumentParser
import Foundation
import GRPCLib
import NIOCore
import NIOPortForwarding
import Semaphore
import Shout
import SystemConfiguration
import CakedLib

struct StartHandler: CakedCommand {
	var startMode: CakedLib.StartHandler.StartMode = .background
	var location: VMLocation
	var config: CakeConfig
	var waitIPTimeout: Int = 180

	init(location: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: CakedLib.StartHandler.StartMode) {
		self.startMode = startMode
		self.location = location
		self.config = config
		self.waitIPTimeout = waitIPTimeout
	}

	init(location: VMLocation, waitIPTimeout: Int, startMode: CakedLib.StartHandler.StartMode) throws {
		self.location = location
		self.config = try location.config()
		self.waitIPTimeout = waitIPTimeout
		self.startMode = startMode
	}

	init(name: String, waitIPTimeout: Int, startMode: CakedLib.StartHandler.StartMode, runMode: Utils.RunMode) throws {
		let location: VMLocation = try StorageLocation(runMode: runMode).find(name)

		self.location = location
		self.config = try location.config()
		self.waitIPTimeout = waitIPTimeout
		self.startMode = startMode
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		let message = try CakedLib.StartHandler.startVM(on: on, location: self.location, config: self.config, waitIPTimeout: waitIPTimeout, startMode: .service, runMode: runMode)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.message = message
			}
		}
	}

}
