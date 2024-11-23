import ArgumentParser
import Foundation
import GRPC
import GRPCLib

private func saveToTempFile(_ data: Data) throws -> String {
	let url = FileManager.default.temporaryDirectory
		.appendingPathComponent(UUID().uuidString)
		.appendingPathExtension("txt")

	try data.write(to: url)

	return url.absoluteURL.path()
}

extension Tartd_TartCommandRequest {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}
}

extension Tartd_BuildRequest {

	init(command: Build) throws {
		self.init()
		self.name = command.name
		self.cpu = Int32(command.cpu)
		self.memory = Int32(command.memory)
		self.diskSize = Int32(command.diskSize)
		self.user = command.user
		self.mainGroup = command.mainGroup
		self.insecure = command.insecure
		self.remoteContainerServer = command.remoteContainerServer

		if let cloudImage = command.cloudImage {
			self.cloudImage = cloudImage
		}

		if let aliasImage = command.aliasImage {
			self.aliasImage = aliasImage
		}

		if let fromImage = command.fromImage {
			self.fromImage = fromImage
		}

		if let ociImage = command.ociImage {
			self.fromImage = ociImage
		}

		if let sshAuthorizedKey = command.sshAuthorizedKey {
			self.sshAuthorizedKey = try Data(contentsOf: URL(filePath: sshAuthorizedKey))
		}

		if let vendorData = command.vendorData {
			self.vendorData = try Data(contentsOf: URL(filePath: vendorData))
		}

		if let userData = command.userData {
			self.userData = try Data(contentsOf: URL(filePath: userData))
		}

		if let networkConfig = command.networkConfig {
			self.networkConfig = try Data(contentsOf: URL(filePath: networkConfig))
		}
	}
}

extension Tartd_LaunchRequest {
	init(command: Launch) throws {
		self.init()
		self.name = command.name
		self.cpu = Int32(command.cpu)
		self.memory = Int32(command.memory)
		self.diskSize = Int32(command.diskSize)
		self.user = command.user
		self.mainGroup = command.mainGroup
		self.insecure = command.insecure
		self.remoteContainerServer = command.remoteContainerServer
		self.dir = command.dir
		self.netBridged = command.netBridged
		self.netSofnet = command.netSoftnet
		self.netHost = command.netHost

		if let netSoftnetAllow: String = command.netSoftnetAllow {
			self.netSoftnetAllow = netSoftnetAllow
		}

		if let cloudImage: String = command.cloudImage {
			self.cloudImage = cloudImage
		}

		if let aliasImage = command.aliasImage {
			self.aliasImage = aliasImage
		}

		if let fromImage = command.fromImage {
			self.fromImage = fromImage
		}

		if let ociImage = command.ociImage {
			self.fromImage = ociImage
		}

		if let sshAuthorizedKey = command.sshAuthorizedKey {
			self.sshAuthorizedKey = try Data(contentsOf: URL(filePath: sshAuthorizedKey))
		}

		if let vendorData = command.vendorData {
			self.vendorData = try Data(contentsOf: URL(filePath: vendorData))
		}

		if let userData = command.userData {
			self.userData = try Data(contentsOf: URL(filePath: userData))
		}

		if let networkConfig = command.networkConfig {
			self.networkConfig = try Data(contentsOf: URL(filePath: networkConfig))
		}
	}
}

extension Tartd_StartRequest {
	init(command: Start) {
		self.init()
		self.name = command.name
	}
}
