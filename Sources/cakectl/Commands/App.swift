import AppKit
import ArgumentParser
import CakedLib
import Foundation
import GRPC
import GRPCLib

// MARK: - App command group

struct Apps: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "app",
		abstract: String(localized: "List and start the applications of a Linux VM"),
		discussion: String(localized: "Uses the .desktop files of the guest and its cakeagent. The windows of a started application are shown on this desktop when the VM has seamless windows enabled."),
		subcommands: [ListApplications.self, RunApplication.self, CreateLauncher.self]
	)

	/// Runs a command line in the guest through caked's `Run` call.
	static func runner(client: CakedServiceClient, name: String, callOptions: CallOptions?) -> GuestApplications.Runner {
		return { commandLine in
			try client.run(.with {
				$0.vmname = name
				$0.command = commandLine
			}, callOptions: callOptions).response.wait().run
		}
	}

	/// The applications only exist in a running Linux VM: `Run` would start a stopped one, which is not what a listing should do.
	static func requireRunning(client: CakedServiceClient, name: String) throws -> (user: String, seamless: Bool) {
		let status = try client.info(name: name, includeConfig: true).vms.status

		guard status.infos.status == .running || status.infos.status == .agentReady else {
			throw ValidationError(String(format: String(localized: "VM %@ is not running"), name))
		}

		guard status.config.os == .linux else {
			throw ValidationError(String(format: String(localized: "VM %@ is not a Linux VM"), name))
		}

		return (user: status.config.configuredUser, seamless: status.config.seamless)
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

	// MARK: list
	struct ListApplications: GrpcParsableCommand {
		static let configuration = CommandConfiguration(commandName: "list", abstract: String(localized: "List the applications of a VM"), aliases: ["ls"])

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let config = try Apps.requireRunning(client: client, name: self.name)
			let applications = try GuestApplications.list(user: config.user, run: Apps.runner(client: client, name: self.name, callOptions: callOptions))

			return self.options.format.render(applications)
		}
	}

	// MARK: run
	struct RunApplication: GrpcParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "run",
			abstract: String(localized: "Start an application of a VM"),
			discussion: String(localized: "The application is a desktop file ID (org.mozilla.firefox), its name, or the last word of its ID (firefox), as listed by 'app list'. With --command the arguments are a program and its arguments instead. The process then shows the guest's windows, unless another process (Caker.app, cakectl sh/exec/seamless) already does.")
		)

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Flag(name: [.customLong("command")], help: ArgumentHelp(String(localized: "Run a program of the guest instead of a desktop application")))
		var asCommand: Bool = false

		@Flag(name: [.customLong("start")], help: ArgumentHelp(String(localized: "Start the VM first if it is stopped")))
		var start: Bool = false

		@Option(name: [.customLong("wait")], help: ArgumentHelp(String(localized: "Seconds to wait for the guest to answer"), valueName: "seconds"))
		var wait: Int = 0

		@Option(name: [.customLong("windows")], help: ArgumentHelp(String(localized: "Show the guest's windows on this desktop, ending when the VM stops")))
		var showWindows: Bool = true

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Argument(parsing: .remaining, help: ArgumentHelp(String(localized: "Application, or with --command a program and its arguments")))
		var application: [String] = []

		func validate() throws {
			guard self.application.isEmpty == false else {
				throw ValidationError(String(localized: "An application is required"))
			}

			guard self.asCommand || self.application.count == 1 else {
				throw ValidationError(String(localized: "Arguments are only passed to a program started with --command"))
			}
		}

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			if self.start {
				try self.startIfStopped(client: client)
			}

			let config = try Apps.retrying(wait: self.wait) { try Apps.requireRunning(client: client, name: self.name) }

			guard config.seamless else {
				throw ValidationError(String(format: String(localized: "VM %@ does not have seamless windows enabled"), self.name))
			}

			let run = Apps.runner(client: client, name: self.name, callOptions: callOptions)
			let user = config.user
			let pid: Int
			var started: String

			if self.asCommand {
				// The agent's launch has no deduplication, and a lost reply doesn't say whether the program started: it is
				// never retried. Wait for the agent with a read-only call instead, then launch once.
				_ = try Apps.retrying(wait: self.wait) { try GuestApplications.list(user: user, run: run) }
				pid = try GuestApplications.launch(program: self.application, user: user, run: run)
				started = self.application[0]
			} else {
				let query = self.application[0]
				let applications = try Apps.retrying(wait: self.wait) { try GuestApplications.list(user: user, run: run) }
				let application = try GuestApplications.resolve(query, in: applications)

				pid = try GuestApplications.launch(application, among: applications, user: user, run: run)
				started = application.name
			}

			let message = String(format: String(localized: "Started %@ (process %d)"), started, pid)

			guard self.showWindows else {
				return message
			}

			fputs(message + "\n", stderr)

			try self.showGuestWindows(client: client, launched: pid > 0 ? pid : nil, run: run)

			return String.empty
		}

		private func startIfStopped(client: CakedServiceClient) throws {
			let status = try client.info(name: self.name, includeConfig: false).vms.status.infos.status

			guard status != .running && status != .agentReady && status != .provisioning else {
				return
			}

			let reply = try client.start(.with {
				$0.name = self.name
				$0.waitIptimeout = Int32(max(self.wait, 180))
			}).response.wait().vms.started

			guard reply.started else {
				throw ServiceError(reply.hasReason ? reply.reason : String(format: String(localized: "Unable to start VM %@"), self.name))
			}
		}

		/// Owns the windows for as long as the VM and the connection last, unless someone else does: then the application is
		/// started and this process has nothing left to do. It ends when the launched process is gone and no guest window is
		/// left; without a process to watch, when the last window closes.
		private func showGuestWindows(client: CakedServiceClient, launched pid: Int?, run: @escaping GuestApplications.Runner) throws {
			let name = self.name

			Client.sigintSrc.cancel()

			try MainActor.assumeIsolated {
				let app = NSApplication.shared

				app.setActivationPolicy(.accessory)

				let connection = Sh.SeamlessConnection(name: name, client: client, displayMode: .ui, waitsForOwner: false, endsWithLastWindow: true)

				let watch = pid.map { LaunchedProcessWatch(pid: $0, run: run) }

				if let watch {
					connection.mayEnd = { watch.isGone }
					watch.start {
						connection.endWhenNoWindowLeft(after: connection.closedLastWindow ? 0 : LaunchedProcessWatch.handoffGracePeriod)
					}
				}

				try connection.connect()

				let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

				signal(SIGINT, SIG_IGN)
				source.setEventHandler {
					connection.stop()
					NSApplication.shared.terminate(nil)
				}
				source.resume()

				app.run()

				source.cancel()
				watch?.stop()
				connection.stop()
			}
		}
	}

	/// Asks the guest every few seconds whether the process `app run` launched still runs. The agent starts it detached
	/// and says nothing when it exits, so it is polled; a failed poll tells nothing and the next one asks again.
	@MainActor
	final class LaunchedProcessWatch {
		static let pollInterval: TimeInterval = 3
		/// After the process is gone, how long a window it handed to another process has to show up.
		static let handoffGracePeriod: TimeInterval = 5

		let pid: Int
		let run: GuestApplications.Runner
		private(set) var isGone = false
		private var identity: String?
		private var timer: Timer?
		private var polling = false
		private var onGone: (() -> Void)?

		init(pid: Int, run: @escaping GuestApplications.Runner) {
			self.pid = pid
			self.run = run
		}

		func start(onGone: @escaping () -> Void) {
			self.onGone = onGone
			self.poll()
			self.timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
				MainActor.assumeIsolated {
					self?.poll()
				}
			}
		}

		func stop() {
			self.timer?.invalidate()
			self.timer = nil
			self.onGone = nil
		}

		private func poll() {
			guard self.polling == false, self.isGone == false else { return }

			self.polling = true

			let pid = self.pid
			let run = self.run

			// The Run call blocks: off the main thread.
			DispatchQueue.global(qos: .utility).async {
				let outcome = Result { try GuestApplications.processIdentity(pid: pid, run: run) }

				DispatchQueue.main.async {
					MainActor.assumeIsolated {
						self.polling = false
						self.handle(outcome)
					}
				}
			}
		}

		private func handle(_ outcome: Result<String?, Error>) {
			guard self.isGone == false, case .success(let current) = outcome else { return }

			// The first answer names the process; a later one that differs is another process that took its ID.
			if let current, self.identity == nil || self.identity == current {
				self.identity = current

				return
			}

			self.isGone = true
			self.timer?.invalidate()
			self.timer = nil
			self.onGone?()
		}
	}

	// MARK: create-launcher
	struct CreateLauncher: GrpcParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "create-launcher",
			abstract: String(localized: "Create a macOS application that starts a guest application"),
			discussion: String(localized: "The application is a small .app running 'cakectl app run': it starts the VM if needed, then the guest application, and its windows show on this desktop. Its icon is the application's icon in the guest, when it has one. Connection options (--connect, --disable-tls, --system) are kept in it, a password is not.")
		)

		@OptionGroup(title: String(localized: "Client options"))
		var options: Client.Options

		@Option(name: [.customLong("output"), .customShort("o")], help: ArgumentHelp(String(localized: "Directory the application is created in (default ~/Applications)"), valueName: "directory"), completion: .directory)
		var output: String?

		@Flag(name: [.customLong("force")], help: ArgumentHelp(String(localized: "Replace an existing launcher")))
		var force: Bool = false

		@Argument(help: ArgumentHelp(String(localized: "VM name")))
		var name: String

		@Argument(help: ArgumentHelp(String(localized: "Application, as listed by 'app list'")))
		var application: String

		func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
			let config = try Apps.requireRunning(client: client, name: self.name)
			let run = Apps.runner(client: client, name: self.name, callOptions: callOptions)
			let found = try GuestApplications.resolve(self.application, in: GuestApplications.list(user: config.user, run: run))
			let directory = self.output.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath, isDirectory: true) } ?? GuestApplicationLauncher.defaultDirectory

			guard let cakectl = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
				throw ServiceError(String(localized: "Unable to find the cakectl executable"))
			}

			let bundle = try GuestApplicationLauncher.create(vm: self.name, application: found, tool: cakectl, extraArguments: self.connectionArguments, in: directory, overwrite: self.force, icon: try? GuestApplications.icon(for: found, run: run))

			return self.options.format.render(String(format: String(localized: "Created %@"), bundle.path(percentEncoded: false)))
		}

		/// What `cakectl` needs to reach the same service again. The password is left out: the script is a readable file.
		private var connectionArguments: [String] {
			var arguments: [String] = []

			if self.options.address != (try? Utils.getDefaultServerAddress(runMode: .user)) {
				arguments.append("--connect=\(self.options.address)")
			}

			if self.options.insecure {
				arguments.append("--disable-tls")
			}

			if self.options.asSystem {
				arguments.append("--system")
			}

			// Certificate paths (not their contents), absolute since the launcher runs from another directory. The
			// default location's certificates are found again by `cakectl` itself, so they are left out.
			let defaults = try? ClientCertificatesLocation.getCertificats(runMode: self.options.runMode)

			if self.options.insecure == false {
				let certificates: [(option: String, path: String?, standard: URL?)] = [
					("--ca-cert", self.options.caCert, defaults?.caCertURL),
					("--tls-cert", self.options.tlsCert, defaults?.clientCertURL),
					("--tls-key", self.options.tlsKey, defaults?.clientKeyURL),
				]

				for certificate in certificates {
					guard let path = certificate.path, path.isEmpty == false else {
						continue
					}

					let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL

					if let standard = certificate.standard, standard.standardizedFileURL.path == url.path {
						continue
					}

					arguments.append("\(certificate.option)=\(url.path(percentEncoded: false))")
				}
			}

			return arguments
		}
	}
}
