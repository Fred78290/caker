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
	let gcd: Bool

	init(request: Caked_StartRequest, startMode: CakedLib.StartHandler.StartMode, gcd: Bool, runMode: Utils.RunMode) throws {
		let location: VMLocation = try StorageLocation(runMode: runMode).find(request.name)

		self.location = location
		self.config = try location.config()
		self.waitIPTimeout = request.hasWaitIptimeout ? Int(request.waitIptimeout) : 120
		self.startMode = startMode
		self.gcd = gcd

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
					$0.reason = error.reason
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.started = CakedLib.StartHandler.startVM(on: on,
														   location: self.location,
														   screenSize: self.screenSize,
														   vncPassword: self.vncPassword,
														   vncPort: self.vncPort,
														   waitIPTimeout: waitIPTimeout,
														   startMode: self.startMode,
														   gcd: self.gcd,
														   runMode: runMode
				).caked
			}
		}
	}

}
