import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib

struct Launch: AsyncParsableCommand {
	static let configuration = BuildOptions.launch

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Build VM options"))
	var options: BuildOptions

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	@Flag(help: ArgumentHelp(String(localized: "Launch vm in foreground"), discussion: String(localized: "This option allow display window of running vm to debug it"), visibility: .hidden))
	var foreground: Bool = false

	@Flag(name: [.customLong("recovery")], help: ArgumentHelp(String(localized: "Launch vm in recovery mode"), discussion: String(localized: "This option allows starting the MacOS VM in recovery mode")))
	var recoveryMode: Bool = false

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.options.validate(remote: false)

		if StorageLocation(runMode: self.common.runMode).exists(self.options.name) {
			throw ValidationError(String(localized: "\(self.options.name) already exists"))
		}
		if let imageSource = self.options.imageSource, foreground == false {
			if imageSource == .iso || imageSource == .ipsw {
				throw ValidationError(String(localized: "Imagesource \(imageSource.description) need display to launch it"))
			}
		}
	}

	func run() async throws {
		Logger.appendNewLine(self.common.format.render(await CakedLib.LaunchHandler.buildAndLaunchVM(runMode: self.common.runMode, options: options, waitIPTimeout: self.waitIPTimeout, startMode: self.foreground ? .foreground : .background, gcd: false, recoveryMode: self.recoveryMode, progressHandler: ProgressObserver.progressHandler)))
	}
}
