import AppKit
import ArgumentParser
import CakeAgentLib
import CakedLib
import Darwin
import Foundation
import GRPCLib

/// Records a human operator manually driving a freshly-installed VM's first-boot setup (macOS
/// Setup Assistant, or a Linux installer) over VNC, and writes out a ready-to-use PackerLite
/// `boot_command` template — the reverse of `caked provision`, which replays such a template
/// instead of recording one. `caked`-local only for now, no `cakectl` counterpart yet (see
/// CLAUDE.md's PackerLite section) — run directly against `caked` on the host where the VM lives.
struct Record: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "record",
		abstract: String(localized: "Record a manual VM setup session into a PackerLite boot_command template"),
		discussion: String(
			localized:
				"Boots <vm> (typically built with `build`/`create` and *without* --autoinstall, so it's sitting at its first-boot screen) and opens a VNC window you drive by hand. Every click and keystroke you perform is recorded; press Ctrl-C to stop and write the recorded boot_command out to --output. The result is a first draft, not a finished template — review it and consider hardening timing-sensitive waits with <locate> anchors before relying on it for unattended --autoinstall runs."
		)
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	@Option(help: ArgumentHelp(String(localized: "Where to write the recorded template"), discussion: String(localized: "Defaults to record.packerlite.yaml inside the VM's own storage directory"), valueName: "path"))
	var output: String?

	/// Unlike `Provision.locations`, this never falls back to treating `name` as a raw disk path —
	/// `record`'s `<vm>` argument is documented as a VM name only — so `exists(_:)` is checked
	/// first and a clean `ValidationError` thrown instead of letting `find(_:)` throw past a `try!`.
	func resolveLocation() throws -> (StorageLocation, VMLocation) {
		let storageLocation = StorageLocation(runMode: self.common.runMode)

		guard storageLocation.exists(self.name) else {
			throw ValidationError(String(localized: "VM at \(self.name) does not exist"))
		}

		return (storageLocation, try storageLocation.find(self.name))
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let (_, location) = try self.resolveLocation()

		if case .running = location.status {
			throw ValidationError(String(localized: "VM at \(self.name) is running — stop it first"))
		}
	}

	private func outputURL(_ location: VMLocation) -> URL {
		guard let output else {
			return location.recordedTemplateURL
		}

		return URL(fileURLWithPath: output.expandingTildeInPath)
	}

	@MainActor
	func run() async throws {
		let (storageLocation, location) = try self.resolveLocation()
		let destination = self.outputURL(location)
		let logger = Logger(self)

		let session = try CakedLib.RecordHandler.record(location: location, storageLocation: storageLocation, runMode: self.common.runMode)

		func stopAndSave() {
			let yaml = session.stop()

			do {
				try yaml.write(to: destination, atomically: true, encoding: .utf8)

				Logger.appendNewLine(String(localized: "Recorded template saved to \(destination.path)"))
				Logger.appendNewLine(String(localized: "This is a first draft — review it and consider hardening timing-sensitive waits with <locate> anchors before relying on it for unattended --autoinstall runs."))
			} catch {
				logger.error("Failed to write recorded template to \(destination.path): \(error)")
			}

			NSApplication.shared.terminate(self)
		}

		// caked's default top-level SIGINT handler (Root.sigintSrc) just force-exits the process —
		// fine for most commands, but here Ctrl-C is the documented way to stop-and-save, so it
		// needs to run our own teardown first. Same cancel-then-install-our-own pattern Exec/Sh
		// already use for their own interactive needs (see Sources/caked/Commands/Exec.swift).
		Root.sigintSrc.cancel()
		signal(SIGINT, SIG_IGN)

		let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

		sigintSrc.setEventHandler {
			stopAndSave()
		}

		sigintSrc.activate()

		Logger.appendNewLine(String(localized: "Recording started for VM \(self.name) — drive the VM through the VNC window, press Ctrl-C here when done."))

		// Blocks (via VNCApp's own NSApplication.run()) until stopAndSave() above calls
		// NSApplication.terminate(), same inline-VNC-window pattern `cakectl provision` uses.
		try VNCApp.startVncClient(
			name: location.name,
			config: session.config,
			vncURL: session.vncURL,
			screenSize: session.screenSize,
			tunnel: nil,
			allowClientResize: false,
			vmStatus: { .running }
		)
	}
}
