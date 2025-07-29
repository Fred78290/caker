import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore

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

public struct MountHandler {
	public  static func Mount(location: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		return try createMountServiceClient(location: location).mount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}

	public  static func Umount(location: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		return try createMountServiceClient(location: location).umount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}
}
