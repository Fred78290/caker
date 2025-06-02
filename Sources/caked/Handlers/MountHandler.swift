import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore
import TextTable

class ReplyMountService: NSObject, NSSecureCoding, ReplyMountServiceProtocol {
	static let supportsSecureCoding: Bool = false

	private let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
	private var response: MountInfos? = nil

	init(response: MountInfos? = nil) {
		self.response = response
	}

	required init?(coder: NSCoder) {
		self.response = coder.decodeObject(forKey: "reply") as? MountInfos
	}

	func reply(response: String) {
		self.response = MountInfos(fromJSON: response)
		self.semaphore.signal()
	}

	func wait() -> MountInfos? {
		if self.response == nil {
			self.semaphore.wait()
			/*
			 guard self.semaphore.wait(timeout: .now().advanced(by: .seconds(300))) == .timedOut else {
			 	Logger(self).error("Timeout")
			 	return nil
			 }*/
		}

		return self.response
	}

	func encode(with coder: NSCoder) {
		coder.encode(self.reply, forKey: "reply")
	}
}

struct MountHandler: CakedCommandAsync {
	var request: Caked_MountRequest

	static func Mount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		return try createMountServiceClient(vmLocation: vmLocation).mount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}

	static func Umount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		return try createMountServiceClient(vmLocation: vmLocation).umount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}

	mutating func run(on: EventLoop, runMode: Utils.RunMode) throws -> EventLoopFuture<Caked_Reply> {
		let vmLocation = try StorageLocation(runMode: runMode).find(self.request.name)
		let directorySharingAttachment = self.request.directorySharingAttachment()
		let command = self.request.command

		return on.submit {
			let response: MountInfos

			if command == .mount {
				response = try Self.Mount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			} else {
				response = try Self.Umount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			}

			if case let .error(v) = response.response {
				throw ServiceError(v)
			}

			return Caked_Reply.with {
				$0.mounts = Caked_MountReply.with {
					$0.mounts = response.mounts.map {
						$0.toCaked_MountVirtioFSReply()
					}

					if case let .error(v) = response.response {
						$0.response = .error(v)
					} else {
						$0.response = .success(true)
					}
				}
			}
		}
	}
}
