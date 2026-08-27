//
//  RecordHandler.swift
//  CakedLib
//
//  Boots a VM to its first-boot screen, starts its VNC server, and arms an ActionRecorder against
//  it — the shared engine behind `caked record` (Sources/caked/Commands/Record.swift). Mirrors
//  ProvisionHandler's VM-boot/VNC pattern (Sources/cakedlib/Handlers/ProvisionHandler.swift) but
//  skips everything PackerLite itself needs (template, IP wait, agent install): recording drives
//  no automation of its own, it only watches whatever a human operator does over VNC and writes
//  down what happened. `caked`-local only for now — see CLAUDE.md's PackerLite section for the
//  planned (not yet built) cakectl/gRPC counterpart, mirroring how `caked provision` itself
//  started local-only before later gaining one.
//

import CakeAgentLib
import Foundation
import GRPCLib

public struct RecordHandler {
	/// A booted, VNC-armed recording session, returned once the VM's VNC server is up and ready
	/// for a client (typically `caked record`'s own inline VNCApp window) to connect through.
	public final class Session: @unchecked Sendable {
		public let vm: VirtualMachine
		public let recorder: ActionRecorder
		public let vncURL: URL
		public let screenSize: ViewSize
		public let config: CakedConfiguration

		private let lock = NSLock()
		private var stopped = false

		init(vm: VirtualMachine, recorder: ActionRecorder, vncURL: URL, screenSize: ViewSize, config: CakedConfiguration) {
			self.vm = vm
			self.recorder = recorder
			self.vncURL = vncURL
			self.screenSize = screenSize
			self.config = config
		}

		/// Stops recording, tears the VM down, and returns the recorded session serialized as a
		/// `boot_command:` YAML document (see `ActionRecorder.finish()`). Safe to call more than
		/// once or from a signal handler — only the first call tears anything down; later calls
		/// just re-return the already-finished YAML.
		@discardableResult
		public func stop() -> String {
			self.lock.lock()

			guard self.stopped == false else {
				self.lock.unlock()
				return self.recorder.finish()
			}

			self.stopped = true
			self.lock.unlock()

			self.vm.setActionRecorder(nil)
			self.vm.stopVncServer()

			// disposeWindow() already dispatches its own work onto the main queue internally —
			// wrapping it in MainActor.assumeIsolated here was both unnecessary and unsafe, since
			// stop() is documented as callable from a signal handler, which isn't the main actor;
			// assumeIsolated traps if that assumption is ever wrong.
			self.vm.disposeWindow()

			let yaml = self.recorder.finish()

			self.vm.terminateVM { _ in }

			return yaml
		}
	}

	/// Boots `location`'s VM (must not already be running) and starts recording. The returned
	/// `Session.vncURL`/`screenSize`/`config` are exactly what a VNC client (e.g.
	/// `VNCApp.startVncClient(...)`) needs to connect and let an operator drive the VM by hand.
	@MainActor
	public static func record(
		location: VMLocation,
		storageLocation: StorageLocation,
		runMode: Utils.RunMode
	) throws -> Session {
		let config = try location.config()
		let displaySize = config.display.cgSize
		let vncPassword = config.vncPassword ?? UUID().uuidString

		if location.status.isRunning {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		let handler = VMRunHandler(
			mode: .default,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: .vnc,
			config: config,
			screenSize: displaySize,
			vncPassword: vncPassword,
			vncPort: 0,
			recoveryMode: false,
			provisioning: true,
			runMode: runMode)

		return try handler.run { _, vm in
			let vncURLs = try vm.startVncServer(vncPassword: vncPassword, port: 0)

			guard let vzMachineView = vm.vzMachineView else {
				throw ServiceError(String(localized: "Unable to get VZMachineView for VM \(location.name)"))
			}

			guard let vncURL = vncURLs.first else {
				throw ServiceError(String(localized: "Unable to get VNC URL for VM \(location.name)"))
			}

			let recorder = ActionRecorder(username: config.configuredUser, password: config.configuredPassword)

			vm.setActionRecorder(recorder.record)

			return Session(vm: vm, recorder: recorder, vncURL: vncURL, screenSize: ViewSize(vzMachineView.bounds.size), config: CakedConfiguration(config))
		}
	}
}
