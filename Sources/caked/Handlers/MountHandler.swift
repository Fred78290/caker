import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib
import NIO

struct MountHandler: CakedCommandAsync {
	var request: Caked_MountRequest

	struct MountVirtioFSReply: Codable {
		let name: String
		let success: Bool
		let reason: String

		init(_ reply: Cakeagent_MountVirtioFSReply) {
			self.name = reply.name
			self.success = reply.success
			self.reason = reply.error
		}

		init(_ reply: Caked_MountVirtioFSReply) {
			self.name = reply.name
			self.success = reply.success
			self.reason = reply.error
		}
	}

	static func Mount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment], client: CakeAgentClient) throws -> Caked_MountReply {
		let config: CakeConfig = try vmLocation.config()
		var response: Caked_MountReply = Caked_MountReply.with {
			$0.mounts = []
			$0.response = .success(true)
		}

		if config.appendMount(mounts) {
			if vmLocation.status == .running {
				let request = Caked_MountRequest.with {
					$0.mounts = mounts.map { mount in
						Caked_MountVirtioFS.with {
							$0.name = mount.name
							$0.target = mount.destination ?? ""
							$0.uid = Int32(mount.uid)
							$0.gid = Int32(mount.gid)
						}
					}
				}

				response = try client.mount(request: request)

				if case let .error(v) = response.response {
					throw ServiceError(v)
				}
			}
		}

		return response
	}

	static func Umount(vmLocation: VMLocation, mounts: [DirectorySharingAttachment], client: CakeAgentClient) throws -> Caked_MountReply {
		let config: CakeConfig = try vmLocation.config()
		var response: Caked_MountReply = Caked_MountReply.with {
			$0.mounts = []
			$0.response = .success(true)
		}

		if config.removeMount(mounts) {
			if vmLocation.status == .running {
				let request = Caked_MountRequest.with {
					$0.mounts = mounts.map { mount in
						Caked_MountVirtioFS.with {
							$0.name = mount.name
							$0.target = mount.destination ?? ""
							$0.uid = Int32(mount.uid)
							$0.gid = Int32(mount.gid)
						}
					}
				}

				response = try client.umount(request: request)

				if case let .error(v) = response.response {
					throw ServiceError(v)
				}
			}
		}

		return response
	}

	mutating func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		let vmLocation = try StorageLocation(asSystem: runAsSystem).find(self.request.name)
		let listeningAddress = vmLocation.agentURL
		let client = CakeAgentConnection(eventLoop: on.next(), listeningAddress: listeningAddress, certLocation: try CertificatesLocation.createAgentCertificats(asSystem: asSystem))
		let directorySharingAttachment = self.request.directorySharingAttachment()
		let format: Format = request.format == .text ? Format.text : Format.json
		let command = self.request.command

		return on.submit {
			let response: Caked_MountReply
			let agentClient = try client.createClient()
			
			defer {
				try? agentClient.close().wait()
			}

			if command == .add {
				response = try Self.Mount(vmLocation: vmLocation, mounts: directorySharingAttachment, client: agentClient)
			} else {
				response = try Self.Umount(vmLocation: vmLocation, mounts: directorySharingAttachment, client: agentClient)
			}

			if case let .error(v) = response.response {
				throw ServiceError(v)
			}

			return format.renderSingle(style: Style.grid, uppercased: true, response.mounts.map { MountVirtioFSReply($0) })
		}
	}
}
