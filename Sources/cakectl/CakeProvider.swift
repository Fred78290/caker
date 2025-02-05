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

extension Caked_ListRequest {
	init(command: List) {
		self.init()
		self.format = command.format == .text ? .text : .json
		self.vmonly = command.vmonly
	}
}

extension Caked_CakedCommandRequest {
	init(command: String, arguments: [String]) {
		self.init()
		self.command = command
		self.arguments = arguments
	}
}

extension Caked_CommonBuildRequest {
	init(buildOptions: BuildOptions) throws {
		self.init()
		self.name = buildOptions.name
		self.cpu = Int32(buildOptions.cpu)
		self.memory = Int32(buildOptions.memory)
		self.diskSize = Int32(buildOptions.diskSize)
		self.user = buildOptions.user
		self.mainGroup = buildOptions.mainGroup
		self.sshPwAuth = buildOptions.clearPassword
		self.autostart = buildOptions.autostart
		self.nested = buildOptions.nested
		self.image = buildOptions.image
		self.mounts = buildOptions.mounts.map{$0.description}.joined(separator: ",")
		self.networks = buildOptions.networks.map{$0.description}.joined(separator: ",")
		self.sockets = buildOptions.sockets.map{$0.description}.joined(separator: ",")

		if let console = buildOptions.consoleURL {
			self.console = console.description
		}

		if buildOptions.forwardedPorts.isEmpty == false {
			self.forwardedPort = buildOptions.forwardedPorts.map { forwardedPort in
				return forwardedPort.description
			}.joined(separator: ",")
		}

		if let sshAuthorizedKey = buildOptions.sshAuthorizedKey {
			self.sshAuthorizedKey = try Data(contentsOf: URL(filePath: sshAuthorizedKey))
		}

		if let vendorData = buildOptions.vendorData {
			self.vendorData = try Data(contentsOf: URL(filePath: vendorData))
		}

		if let userData = buildOptions.userData {
			if userData == "-" {
				if let input = (readLine(strippingNewline: true))?.split(whereSeparator: {$0 == " "}).map (String.init) {
					self.userData = input.joined(separator: "\n").data(using: .utf8)!
				}
			} else {
				self.userData = try Data(contentsOf: URL(filePath: userData))
			}
		}

		if let networkConfig = buildOptions.networkConfig {
			self.networkConfig = try Data(contentsOf: URL(filePath: networkConfig))
		}

//		if let netSoftnetAllow: String = buildOptions.netSoftnetAllow {
//			self.netSoftnetAllow = netSoftnetAllow
//		}
	}
}

extension Caked_BuildRequest {
	init(buildOptions: BuildOptions) throws {
		self.init()
		self.options = try Caked_CommonBuildRequest(buildOptions: buildOptions)
	}
}

extension Caked_LaunchRequest {
	init(command: Launch) throws {
		self.init()
		self.options = try Caked_CommonBuildRequest(buildOptions: command.buildOptions)
		self.waitIptimeout = Int32(command.waitIPTimeout)
	}
}


extension Caked_StartRequest {
	init(command: Start) {
		self.init()
		self.name = command.name
	}
}

extension Caked_StopRequest {
	init(command: Stop) {
		self.init()
		self.name = command.name
		self.force = command.force
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
	init (options: ConfigureOptions) {
		self.init()
		self.name = options.name

		if let cpu = options.cpu {
			self.cpu = Int32(cpu)
		}

		if let memory = options.memory {
			self.memory = Int32(memory)
		}

		if let diskSize = options.diskSize {
			self.diskSize = Int32(diskSize)
		}

		if let displayRefit = options.displayRefit {
			self.displayRefit = displayRefit
		}

		if let autostart = options.autostart {
			self.autostart = autostart
		}

		if let nested = options.nested {
			self.nested = nested
		}

		if let mounts = options.mounts {
			self.mounts = mounts.map{$0.description}.joined(separator: ",")
		}

		if let networks = options.networks {
			self.networks = networks.map{$0.description}.joined(separator: ",")
		}

		if let sockets = options.sockets {
			self.networks = sockets.map{$0.description}.joined(separator: ",")
		}

		if let consoleURL = options.consoleURL {
			self.console = consoleURL.description
		}

		if let forwardedPort = options.forwardedPort {
			self.forwardedPort = forwardedPort.map{$0.description}.joined(separator: ",")
		}

		self.randomMac = options.randomMAC
	}
}
extension Caked_InfoRequest {
	init(command: Infos) {
		self.init()
		self.name = command.name
	}
}

extension Caked_ExecuteRequest {
	init(command: Exec) {
		var args = command.arguments

		self.init()
		
		self.name = command.name
		self.command = args.remove(at: 0)
		self.args = args

		if isatty(FileHandle.standardInput.fileDescriptor) == 0 {
			self.input = FileHandle.standardInput.readDataToEndOfFile()
		}
	}
}

extension Caked_ImageRequest {
	init(command: ImagesManagement.ListImage) {
		self.init()

		self.name = command.name
		self.format = command.format == .text ? .text : .json
	}

	init(command: ImagesManagement.InfoImage) {
		self.init()

		self.name = command.name
		self.format = command.format == .text ? .text : .json
	}
}

extension Caked_RemoteRequest {
	init(command: Remote.AddRemote) {
		self.init()
		var add: Caked_RemoteRequestAdd = Caked_RemoteRequestAdd()

		add.name = command.remote
		add.url = command.url

		self.command = .add
		self.add = add
	}

	init(command: Remote.DeleteRemote) {
		self.init()

		self.command = .delete
		self.delete = command.remote
	}

	init(command: Remote.ListRemote) {
		self.init()

		self.format = command.format == .text ? .text : .json
	}
}

extension Caked_NetworkRequest {
	init(command: Networks) {
		self.init()

		self.format = command.format == .text ? .text : .json
	}
}

extension Caked_WaitIPRequest {
	init(command: WaitIP) {
		self.init()

		self.name = command.name
		self.timeout = Int32(command.wait)
	}
}
