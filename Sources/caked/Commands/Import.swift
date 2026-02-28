import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib

struct Import: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "import", abstract: "Import an external VM from a file or URL.")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Option(help: "Kind of virtual machine to convert from.")
	var from: CakedLib.ImportHandler.ImportSource = .vmdk

	@Option(name: .shortAndLong, help: "The user to use for the VM")
	public var user: String = "admin"

	@Option(name: .shortAndLong, help: "The user password for login")
	public var password: String = "admin"

	@Flag(name: [.long, .customShort("k")], help: ArgumentHelp("Tell if the user admin allow password for ssh"))
	public var clearPassword: Bool = false

	@Option(name: [.customLong("ssh-key"), .customShort("i")], help: "Optional SSH private key to use for the VM")
	public var sshPrivateKey: String? = nil

	@Option(name: [.customLong("ssh-passphrase"), .customShort("l")], help: "Optional SSH private key passphrase to use for the VM")
	public var sshPrivateKeyPassphrase: String? = nil

	@Option(help: .hidden)
	public var uid: UInt32 = geteuid()

	@Option(help: .hidden)
	public var gid: UInt32 = getegid()

	@Argument(help: "The name virtual machine to convert from or absolute path to the directory containing the VMs.")
	var source: String

	@Argument(help: "The name of the virtual machine to create.")
	var name: String

	var logLevel: Logger.LogLevel {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	func run() throws {
		let importer = self.from.importer

		if importer.needSudo && geteuid() != 0 {
			var arguments = [
				"convert",
				self.name,
				self.source,
				"--from=\(self.from.rawValue)",
				"--user=\(self.user)",
				"--password=\(self.password)",
				"--uid=\(self.uid)",
				"--gid=\(self.gid)",
			]

			if let sshPrivateKey = self.sshPrivateKey {
				arguments.append("--ssh-key=\(sshPrivateKey)")
			}

			if let sshPrivateKeyPassphrase = self.sshPrivateKeyPassphrase {
				arguments.append("--ssh-passphrase=\(sshPrivateKeyPassphrase)")
			}

			let exitCode = try SudoCaked(arguments: arguments, runMode: runMode, standardOutput: FileHandle.standardOutput, standardError: FileHandle.standardError).runAndWait()

			if exitCode != 0 {
				Foundation.exit(Int32(exitCode))
			}
		} else {
			Logger.appendNewLine(
				self.common.format.render(
					ImportHandler.importVM(importer: importer, name: name, source: source, userName: user, password: password, clearPassword: clearPassword, sshPrivateKey: sshPrivateKey, passphrase: sshPrivateKeyPassphrase, uid: uid, gid: gid, runMode: .user)))
		}
	}
}
