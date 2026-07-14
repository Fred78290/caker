import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib

struct Spawn: AsyncParsableCommand {
	static let configuration = SpawnOptions.spawn

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Spawn VM options"))
	var options: SpawnOptions

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.options.validate()

		if self.options.bridgedNetwork {
			guard CakedKeyConfig.bridgedNetwork.string() != nil else {
				throw ValidationError(String(localized: "Any bridged network is not configured"))
			}
		}

		if StorageLocation(runMode: self.common.runMode).exists(self.options.name) {
			throw ValidationError(String(localized: "\(self.options.name) already exists"))
		}

		if self.options.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError(String(localized: "Shared file descriptors are not supported, use launch instead"))
		}
	}

	func run() async throws {
		Logger.appendNewLine(self.common.format.render(await CakedLib.SpawnHandler.spawn(options: self.options, runMode: self.common.runMode)))
	}
}

struct SpawnAndStart: AsyncParsableCommand {
	static let configuration = SpawnOptions.spawnAndStart

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Spawn VM options"))
	var options: SpawnOptions

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	@Flag(help: ArgumentHelp(String(localized: "Launch vm in foreground"), discussion: String(localized: "This option allows display window of running vm to debug it"), visibility: .hidden))
	var foreground: Bool = false

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.options.validate()

		if self.options.bridgedNetwork {
			guard CakedKeyConfig.bridgedNetwork.string() != nil else {
				throw ValidationError(String(localized: "Any bridged network is not configured"))
			}
		}

		if StorageLocation(runMode: self.common.runMode).exists(self.options.name) {
			throw ValidationError(String(localized: "\(self.options.name) already exists"))
		}

		if self.options.sockets.first(where: { $0.sharedFileDescriptors != nil }) != nil {
			throw ValidationError(String(localized: "Shared file descriptors are not supported, use launch instead"))
		}
	}

	func run() async throws {
		let build = await CakedLib.SpawnHandler.spawn(options: self.options, runMode: self.common.runMode)

		guard build.builded else {
			Logger.appendNewLine(self.common.format.render(build))
			return
		}

		let storageLocation = StorageLocation(runMode: self.common.runMode)
		let location = try storageLocation.find(self.options.name)
		let reply = CakedLib.StartHandler.startVM(location: location, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: waitIPTimeout, startMode: self.foreground ? .foreground : .background, gcd: false, recoveryMode: false, runMode: self.common.runMode)

		Logger.appendNewLine(self.common.format.render(reply))
	}
}
