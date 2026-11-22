import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib

// MARK: - App command group

/// The local counterpart of `cakectl app`: lists and starts the applications of a running Linux VM through its agent.
/// There are no windows to show here: they belong to the process that runs the VM (`caked vmrun`, Caker.app).
struct Apps: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "app",
		abstract: String(localized: "List and start the applications of a Linux VM"),
		discussion: String(localized: "Uses the .desktop files of the guest and its cakeagent. The VM must be running; its windows are shown by the process that runs it."),
		subcommands: [ListApplications.self, RunApplication.self, CreateLauncher.self]
	)

	/// The user's applications of a running Linux VM, and how to run a command line in it. With `start`, a stopped VM is
	/// started first (the process that runs it shows its seamless windows).
	static func connect(name: String, runMode: Utils.RunMode, start: Bool = false, wait: Int = 0) throws -> (user: String, run: GuestApplications.Runner) {
		let location = try StorageLocation(runMode: runMode).find(name)
		let config = try location.config()

		guard config.os == .linux else {
			throw ValidationError(String(format: String(localized: "VM %@ is not a Linux VM"), name))
		}

		if case .running = location.status {
		} else if start {
			let reply = CakedLib.StartHandler.startVM(location: location, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: max(wait, 180), startMode: .background, gcd: false, recoveryMode: false, runMode: runMode)

			guard reply.started else {
				throw ServiceError(reply.reason.isEmpty ? String(format: String(localized: "Unable to start VM %@"), name) : reply.reason)
			}
		} else {
			throw ValidationError(String(format: String(localized: "VM %@ is not running"), name))
		}

		let connection = try retrying(wait: wait) {
			try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: location.agentURL, timeout: 10, runMode: runMode, retries: .upTo(1))
		}

		return (user: config.configuredUser, run: { try connection.run(command: $0) })
	}

	/// The guest's agent can take a moment to answer after a start: retry what failed because of it, not a wrong name.
	static func retrying<T>(wait: Int, _ body: () throws -> T) throws -> T {
		let deadline = Date().addingTimeInterval(Double(max(wait, 0)))

		while true {
			do {
				return try body()
			} catch {
				switch error {
				case GuestApplications.Failure.notFound, GuestApplications.Failure.ambiguous, GuestApplications.Failure.invalidIdentifier, GuestApplications.Failure.invalidUser:
					throw error
				default:
					break
				}

				guard Date() < deadline else {
					throw error
				}

				Thread.sleep(forTimeInterval: 2)
			}
		}
	}

	struct ListApplications: ParsableCommand {
		static let configuration = CommandConfiguration(commandName: "list", abstract: String(localized: "List the applications of a VM"), aliases: ["ls"])

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			let guest = try Apps.connect(name: self.name, runMode: self.common.runMode)

			Logger.appendNewLine(self.common.format.render(try GuestApplications.list(user: guest.user, run: guest.run)))
		}
	}

	struct RunApplication: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: String(localized: "Start an application of a VM"),
			discussion: String(localized: "The application is a desktop file ID (org.mozilla.firefox), its name, or the last word of its ID (firefox), as listed by 'app list'. With --command the arguments are a program and its arguments instead.")
		)

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Flag(name: [.customLong("command")], help: ArgumentHelp(String(localized: "Run a program of the guest instead of a desktop application")))
		var asCommand: Bool = false

		@Flag(name: [.customLong("start")], help: ArgumentHelp(String(localized: "Start the VM first if it is stopped")))
		var start: Bool = false

		@Option(name: [.customLong("wait")], help: ArgumentHelp(String(localized: "Seconds to wait for the guest to answer"), valueName: "seconds"))
		var wait: Int = 0

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Argument(parsing: .remaining, help: ArgumentHelp(String(localized: "Application, or with --command a program and its arguments")))
		var application: [String] = []

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)

			guard self.application.isEmpty == false else {
				throw ValidationError(String(localized: "An application is required"))
			}

			guard self.asCommand || self.application.count == 1 else {
				throw ValidationError(String(localized: "Arguments are only passed to a program started with --command"))
			}
		}

		func run() throws {
			let guest = try Apps.connect(name: self.name, runMode: self.common.runMode, start: self.start, wait: self.wait)
			let wait = self.wait
			let pid: Int
			let started: String

			if self.asCommand {
				// The agent's launch has no deduplication, and a lost reply doesn't say whether the program started: it is
				// never retried. Wait for the agent with a read-only call instead, then launch once.
				_ = try Apps.retrying(wait: wait) { try GuestApplications.list(user: guest.user, run: guest.run) }
				pid = try GuestApplications.launch(program: self.application, user: guest.user, run: guest.run)
				started = self.application[0]
			} else {
				let applications = try Apps.retrying(wait: wait) { try GuestApplications.list(user: guest.user, run: guest.run) }
				let application = try GuestApplications.resolve(self.application[0], in: applications)

				pid = try GuestApplications.launch(application, among: applications, user: guest.user, run: guest.run)
				started = application.name
			}

			Logger.appendNewLine(self.common.format.render(String(format: String(localized: "Started %@ (process %d)"), started, pid)))
		}
	}

	struct CreateLauncher: ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "create-launcher",
			abstract: String(localized: "Create a macOS application that starts a guest application"),
			discussion: String(localized: "The application is a small .app running 'caked app run': it starts the VM if needed, then the guest application, and its windows show on this desktop through the process that runs the VM. Its icon is the application's icon in the guest, when it has one.")
		)

		@OptionGroup(title: String(localized: "Global options"))
		var common: CommonOptions

		@Option(name: [.customLong("output"), .customShort("o")], help: ArgumentHelp(String(localized: "Directory the application is created in (default ~/Applications)"), valueName: "directory"), completion: .directory)
		var output: String?

		@Flag(name: [.customLong("force")], help: ArgumentHelp(String(localized: "Replace an existing launcher")))
		var force: Bool = false

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Argument(help: ArgumentHelp(String(localized: "Application, as listed by 'app list'")))
		var application: String

		mutating func validate() throws {
			Logger.setLevel(self.common.logLevel)
		}

		func run() throws {
			let guest = try Apps.connect(name: self.name, runMode: self.common.runMode)
			let found = try GuestApplications.resolve(self.application, in: GuestApplications.list(user: guest.user, run: guest.run))
			let directory = self.output.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath, isDirectory: true) } ?? GuestApplicationLauncher.defaultDirectory

			guard let caked = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
				throw ServiceError(String(localized: "Unable to find the caked executable"))
			}

			let bundle = try GuestApplicationLauncher.create(vm: self.name, application: found, tool: caked, extraArguments: self.common.runMode == .system ? ["--system"] : [], in: directory, overwrite: self.force, icon: try? GuestApplications.icon(for: found, run: guest.run))

			Logger.appendNewLine(self.common.format.render(String(format: String(localized: "Created %@"), bundle.path(percentEncoded: false))))
		}
	}
}
