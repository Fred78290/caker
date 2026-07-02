import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib

struct Import: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "import", abstract: String(localized: "Import an external VM from a file or URL."))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(help: ArgumentHelp(String(localized: "Kind of virtual machine to convert from.")))
	var from: CakedLib.ImportHandler.ImportSource = .vmdk

	@Option(name: .shortAndLong, help: ArgumentHelp(String(localized: "The user to use for the VM")))
	public var user: String = "admin"

	@Option(name: .shortAndLong, help: ArgumentHelp(String(localized: "The user password for login")))
	public var password: String = "admin"

	@Flag(name: [.long, .customShort("k")], help: ArgumentHelp(String(localized: "Tell if the user admin allow password for ssh")))
	public var clearPassword: Bool = false

	@Option(name: [.customLong("ssh-key"), .customShort("i")], help: ArgumentHelp(String(localized: "Optional SSH private key to use for the VM")))
	public var sshPrivateKey: String? = nil

	@Option(name: [.customLong("ssh-passphrase"), .customShort("l")], help: ArgumentHelp(String(localized: "Optional SSH private key passphrase to use for the VM")))
	public var sshPrivateKeyPassphrase: String? = nil

	@Flag(name: .customLong("no-copy-disk"), help: ArgumentHelp(String(localized: "Don't copy the source image disk, reference it in place instead. Only supported by importers that already use a raw disk image (tart, utm, virtualbuddy).")))
	public var noCopyDisk: Bool = false

	@Option(help: .hidden)
	public var uid: UInt32 = geteuid()

	@Option(help: .hidden)
	public var gid: UInt32 = getegid()

	@Argument(help: ArgumentHelp(String(localized: "The name virtual machine to convert from or absolute path to the directory containing the VMs.")))
	var source: String

	@Argument(help: ArgumentHelp(String(localized: "The name of the virtual machine to create.")))
	var name: String

	var logLevel: Logger.LogLevel {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	func run() throws {
		let importer = self.from.importer

		Logger.appendNewLine(
			self.common.format.render(
				ImportHandler.importVM(
					importer: importer,
					source: source,
					name: name,
					userName: user,
					password: password,
					clearPassword: clearPassword,
					sshPrivateKey: sshPrivateKey,
					passphrase: sshPrivateKeyPassphrase,
					copyDisk: !noCopyDisk,
					uid: uid,
					gid: gid,
					runMode: self.runMode,
					standardOutput: FileHandle.standardOutput,
					standardError: FileHandle.standardError)))
	}
}
