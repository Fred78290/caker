import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import NIOCore
import NIOPortForwarding
import Semaphore
import Shout
import SystemConfiguration

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

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.started = .with {
					$0.started = false
					$0.reason = "\(error)"
				}
			}
		}
	}
	
	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.started = CakedLib.StartHandler.startVM(on: on, location: self.location, config: self.config, waitIPTimeout: waitIPTimeout, startMode: .service, runMode: runMode).caked
			}
		}
	}

}
