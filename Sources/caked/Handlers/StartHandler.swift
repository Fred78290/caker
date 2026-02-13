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
	let startMode: CakedLib.StartHandler.StartMode
	let location: VMLocation
	let screenSize: ViewSize?
	let vncPassword: String?
	let vncPort: Int?
	let config: CakeConfig
	let waitIPTimeout: Int

	/*init(location: VMLocation, config: CakeConfig, waitIPTimeout: Int, startMode: CakedLib.StartHandler.StartMode) {
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
	}*/

	init(request: Caked_StartRequest, startMode: CakedLib.StartHandler.StartMode, runMode: Utils.RunMode) throws {
		let location: VMLocation = try StorageLocation(runMode: runMode).find(request.name)

		self.location = location
		self.config = try location.config()
		self.waitIPTimeout = request.hasWaitIptimeout ? Int(request.waitIptimeout) : 120
		self.startMode = startMode

		if request.hasScreenSize {
			self.screenSize = ViewSize(width: Int(request.screenSize.width), height: Int(request.screenSize.height))
		} else {
			self.screenSize = nil
		}

		if request.hasVncPassword {
			self.vncPassword = request.vncPassword
		} else {
			self.vncPassword = nil
		}

		if request.hasVncPort {
			self.vncPort = Int(request.vncPort)
		} else {
			self.vncPort = nil
		}
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
				$0.started = CakedLib.StartHandler.startVM(on: on, location: self.location, screenSize: self.screenSize, vncPassword: self.vncPassword, vncPort: self.vncPort, waitIPTimeout: waitIPTimeout, startMode: .service, runMode: runMode).caked
			}
		}
	}

}
