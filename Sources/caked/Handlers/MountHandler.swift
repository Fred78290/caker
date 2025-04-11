import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib
import NIO
import Semaphore

class ReplyMountService: NSObject, NSSecureCoding, ReplyMountServiceProtocol {
	static let supportsSecureCoding: Bool = false

	private let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
	private var response: MountReply? = nil

	init(response: MountReply? = nil) {
		self.response = response
	}

	required init?(coder: NSCoder) {
		self.response = coder.decodeObject(forKey: "reply") as? MountReply
	}

	func reply(response: String) -> Void {
		self.response = MountReply(fromJSON: response)
		self.semaphore.signal()
	}

	func wait() -> MountReply? {
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

	struct MountVirtioFSReply: Codable {
		var name: String = ""
		var path: String = ""
		var success: Bool = false
		var reason: String = ""

		public static func with(
			_ populator: (inout Self) throws -> Void
		) rethrows -> Self {
			var message = Self()
			try populator(&message)
			return message
		}

		func toCaked_MountVirtioFSReply() -> Caked_MountVirtioFSReply {
			Caked_MountVirtioFSReply.with {
				$0.name = self.name
				$0.path = self.path

				if self.success {
					$0.success = true
				} else {
					$0.error = self.reason
				}
			}
		}
	}

	struct MountReply: Codable {
		var mounts: [MountVirtioFSReply] = []
		var response: OneOf_Response? = .success(true)

		public enum OneOf_Response: Codable, Equatable, Sendable {
			case error(String)
			case success(Bool)
		}

		public static func with(
			_ populator: (inout Self) throws -> Void
		) rethrows -> Self {
			var message = Self()
			try populator(&message)
			return message
		}

		func render(format: Format, directorySharingAttachment: [DirectorySharingAttachment]) -> String {
			return format.renderSingle(style: Style.grid, uppercased: true, self.mounts.map { mount in
				if let attachement = directorySharingAttachment.first(where: { attachement in attachement.name == mount.name}) {
					return MountHandler.MountVirtioFSReply.with {
						$0.name = mount.name
						$0.success = mount.success
						$0.reason = mount.reason
						$0.path = attachement.path.path
					}
				}

				return mount
			})
		}
	}

	static func Mount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountHandler.MountReply {
		return try createMountServiceClient(vmLocation: vmLocation).mount(mounts: mounts)
	}

	static func Umount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountHandler.MountReply {
		return try createMountServiceClient(vmLocation: vmLocation).umount(mounts: mounts)
	}

	mutating func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<Caked_Reply> {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.request.name)
		let directorySharingAttachment = self.request.directorySharingAttachment()
		let command = self.request.command

		return on.submit {
			let response: MountHandler.MountReply

			if command == .add {
				response = try Self.Mount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			} else {
				response = try Self.Umount(vmLocation: vmLocation, mounts: directorySharingAttachment)
			}

			if case let .error(v) = response.response {
				throw ServiceError(v)
			}

			return Caked_Reply.with {
				$0.mounts = Caked_MountReply.with {
					$0.mounts = response.mounts.map { $0.toCaked_MountVirtioFSReply() }
				}
			}
		}
	}
}
