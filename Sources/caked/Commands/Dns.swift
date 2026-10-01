import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib

/// Runs the compose DNS resolver (`<service>.<project>.compose.internal`, see
/// `Sources/caked/ComposeDNS/ComposeDNSCoordinator.swift`) as its own standalone, persistent
/// command — for the cases where it isn't already running inside a `caked service listen`
/// process: `caked compose up`'s own one-shot local invocation, and `caker`'s `.app` mode (VMs
/// embedded in-process, no `caked` at all) both still tag a built VM's `CakeConfig` with
/// `composeProject`/`composeService` and still configure its guest to route `*.compose.internal`
/// to the NAT gateway, but neither one hosts a resolver to answer it. `caked dns` fills that gap:
/// point it at the same host any compose VMs are running on, `Ctrl-C` to stop.
///
/// Safe (and expected) to run alongside a `caked service listen` that also has compose DNS
/// enabled — both discover VMs by polling disk state (`ComposeDNSCoordinator.refreshFromDisk()`),
/// so whichever one actually manages to bind the NAT gateway's port 53 (or `--internal-port`,
/// unprivileged) serves every compose VM either process finds; the other's own `ensureServerRunning()`
/// simply fails to bind and logs a warning, it doesn't error out or contend for the port.
struct Dns: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "dns",
		abstract: String(localized: "Run the compose DNS resolver as a standalone, persistent service"),
		discussion: String(
			localized:
				"Answers <service>.<project>.compose.internal for every currently-running compose-tagged VM, on the NAT network gateway every VM already carries — see the \"Compose DNS\" section of CLAUDE.md for the full design. Use this when compose VMs are being started without a `caked service listen` daemon running (a one-shot `caked compose up`, or caker's .app mode) — those still configure a VM's guest to query this resolver, but don't host one themselves. Runs until Ctrl-C."
		)
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("internal-port")],
		help: ArgumentHelp(
			String(localized: "Unprivileged port the resolver listens on"),
			discussion: String(
				localized:
					"Ignored when caked runs as root, since the resolver then binds the standard port 53 directly. Otherwise, a `pf` redirect (needs passwordless sudo configured for caked) makes port 53 on the gateway reach this port instead — resolvectl has no syntax for a non-standard port, so without that redirect this flag alone isn't enough for guests to actually reach the resolver."
			)))
	var internalPort: Int = ComposeDNSServer.internalBindPort

	@Option(
		name: [.customLong("poll-interval")],
		help: ArgumentHelp(
			String(localized: "Seconds between rescans for compose-tagged VMs"),
			discussion: String(localized: "How often the resolver's registry is refreshed from disk. Lower values notice a new/removed service sooner, at the cost of more frequent DHCP-lease-table reads.")))
	var pollInterval: Double = 3

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		guard self.pollInterval > 0 else {
			throw ValidationError(String(localized: "--poll-interval must be greater than 0"))
		}
	}

	func run() async throws {
		let logger = Logger(self)
		let runMode = self.common.runMode
		let coordinator = ComposeDNSCoordinator(group: Utilities.group, runMode: runMode, internalPort: self.internalPort)

		// Same SIGINT-as-clean-shutdown pattern `caked service listen`/`caked record`/`caked
		// provision`/`caked build` already use: cancel the default top-level handler (which just
		// force-exits) and let ours tear the coordinator (server + pf redirect) down properly.
		Root.sigintSrc.cancel()

		// Same shape as `caked service listen`'s own SIGINT handling (`Service.swift`):
		// build every signal source first, `setEventHandler` on each, then `.activate()`
		// them all in one pass — once activated, a `DispatchSourceSignal` is retained by
		// libdispatch itself for as long as it's live, so no separate `var` needs to keep
		// `sigcaught` around past this synchronous closure returning.
		let sigcaught = [SIGINT, SIGHUP, SIGQUIT, SIGTERM].map { sig in
			signal(sig, SIG_IGN)

			return DispatchSource.makeSignalSource(signal: sig)
		}

		sigcaught.forEach {
			$0.setEventHandler {
				logger.info("Stopping compose DNS")

				Task {
					await coordinator.shutdown()
				}

				sigcaught.forEach {
					$0.setEventHandler {
						Foundation.exit(128)
					}

					$0.activate()
				}
			}

			$0.activate()
		}

		logger.info("Compose DNS running (poll interval: \(self.pollInterval)s) — Ctrl-C to stop")

		await coordinator.startPollingSync(interval: self.pollInterval, eager: true)
	}
}
