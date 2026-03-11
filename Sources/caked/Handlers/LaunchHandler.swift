import CakedLib
import Foundation
import GRPCLib
import NIOCore

struct LaunchHandler: CakedCommandAsync {
	var options: BuildOptions
	let startMode: CakedLib.StartHandler.StartMode
	let gcd: Bool
	var waitIPTimeout = 180

	init(options: BuildOptions, startMode: CakedLib.StartHandler.StartMode, gcd: Bool, waitIPTimeout: Int = 180) {
		self.options = options
		self.gcd = gcd
		self.startMode = startMode
		self.waitIPTimeout = waitIPTimeout
	}

	func replyError(error: any Error) -> GRPCLib.Caked_Reply {
		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.launched = .with {
					$0.name = self.options.name
					$0.launched = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
		let result = await CakedLib.LaunchHandler.buildAndLaunchVM(runMode: runMode, options: options, waitIPTimeout: waitIPTimeout, startMode: startMode, gcd: gcd)

		return Caked_Reply.with { reply in
			reply.vms = Caked_VirtualMachineReply.with {
				$0.launched = result.caked
			}
		}
	}

}
