import ArgumentParser
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore

class ReplyMountService: NSObject, NSSecureCoding, ReplyMountServiceProtocol {
	static let supportsSecureCoding: Bool = false
	
	enum ServiceReply {
		case mountInfos(MountInfos)
		case vncURL(String)
		case none
	}
	
	private let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
	private var response: ServiceReply? = nil
	
	override init() {
		self.response = ReplyMountService.ServiceReply.none
	}
	
	required init?(coder: NSCoder) {
		self.response = coder.decodeObject(forKey: "response") as? ServiceReply
	}
	
	func vncURLReply(response: String) {
		self.response = .vncURL(response)
	}
	
	func mountReply(response: String) {
		self.response = .mountInfos(MountInfos(fromJSON: response))
		self.semaphore.signal()
	}
	
	func wait() -> ServiceReply? {
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
		coder.encode(self.response, forKey: "response")
	}
	
	func waitForMountInfosReply() -> MountInfos {
		if let reply = self.wait() {
			if case let .mountInfos(mountInfos) = reply {
				return mountInfos
			}

			return MountInfos.with {
				$0.response = .error("Unexpected reply from MountService \(reply)")
			}
		}

		return MountInfos.with {
			$0.response = .error("Timeout")
		}
	}
}

public struct MountHandler {
	public static func VncURL(location: VMLocation) throws -> URL? {
		return try createMountServiceClient(location: location).vncURL()
	}

	public static func Mount(location: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		return try createMountServiceClient(location: location).mount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}

	public static func Umount(location: VMLocation, mounts: [DirectorySharingAttachment]) throws -> MountInfos {
		return try createMountServiceClient(location: location).umount(mounts: mounts).withDirectorySharingAttachment(directorySharingAttachment: mounts)
	}
}
