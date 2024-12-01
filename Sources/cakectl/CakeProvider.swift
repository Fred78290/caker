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

extension Caked_CakedCommandRequest {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}
}

extension Caked_BuildRequest {

	init(command: Build) throws {
		self.init()
		self.name = command.name
		self.cpu = Int32(command.cpu)
		self.memory = Int32(command.memory)
		self.diskSize = Int32(command.diskSize)
		self.user = command.user
		self.mainGroup = command.mainGroup
		self.sshPwAuth = command.clearPassword
		self.autostart = command.autostart
		self.nested = command.nested
		self.remoteContainerServer = command.remoteContainerServer

		if command.forwardedPort.isEmpty == false {
			self.forwardedPort = command.forwardedPort.map { forwardedPort in
				return forwardedPort.description
			}.joined(separator: ",")
		}

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

extension Caked_LaunchRequest {
	init(command: Launch) throws {
		self.init()
		self.name = command.name
		self.cpu = Int32(command.cpu)
		self.memory = Int32(command.memory)
		self.diskSize = Int32(command.diskSize)
		self.user = command.user
		self.mainGroup = command.mainGroup
		self.sshPwAuth = command.clearPassword
		self.remoteContainerServer = command.remoteContainerServer
		self.dir = command.dir.joined(separator: ",")
		self.netBridged = command.netBridged.joined(separator: ",")
		self.netSofnet = command.netSoftnet
		self.netHost = command.netHost
		self.nested = command.nested
		self.autostart = command.autostart

		if command.forwardedPort.isEmpty == false {
			self.forwardedPort = command.forwardedPort.map { forwardedPort in
				return forwardedPort.description
			}.joined(separator: ",")
		}

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

extension Caked_StartRequest {
	init(command: Start) {
		self.init()
		self.name = command.name
	}
}

extension Caked_PurgeRequest {
	init (command: Purge) {
		self.init()
		self.entries = command.entries

		if let olderThan = command.olderThan {
			self.olderThan = Int32(olderThan)
		}

		if let cacheBudget = command.cacheBudget {
			self.cacheBudget = Int32(cacheBudget)
		}

		if let spaceBudget = command.spaceBudget {
			self.spaceBudget = Int32(spaceBudget)
		}
	}
}

extension Caked_LoginRequest {
	init (command: Login) throws {
		self.init()

		self.insecure = command.insecure
		self.noValidate = command.noValidate

		if let username = command.username {
			self.username = username
		}
		if command.passwordStdin {
			if let password = readLine(strippingNewline: true) {
				self.password = password
			}
		} else if let password = command.password {
			self.password = password
		}
	}
}

extension Caked_ConfigureRequest {
	init (command: Configure) {
		self.init()
		self.name = command.name

		if let cpu = command.cpu {
			self.cpu = Int32(cpu)
		}

		if let memory = command.memory {
			self.memory = Int32(memory)
		}

		if let diskSize = command.diskSize {
			self.diskSize = Int32(diskSize)
		}

		if let displayRefit = command.displayRefit {
			self.displayRefit = displayRefit
		}

		if let autostart = command.autostart {
			self.autostart = autostart
		}

		if let nested = command.nested {
			self.nested = nested
		}

		if command.dir.contains("unset") == false {
			self.dir = command.dir.joined(separator: ",")
		}

		if command.netBridged.contains("unset") == false {
			self.netBridged = command.netBridged.joined(separator: ",")
		}

		if let netSoftnet = command.netSoftnet {
			self.netSoftnet = netSoftnet
		}

		if let netSoftnetAllow = command.netSoftnetAllow {
			self.netSoftnetAllow = netSoftnetAllow
		}

		if let netHost = command.netHost {
			self.netHost = netHost
		}

		self.randomMac = command.randomMAC
	}
}
