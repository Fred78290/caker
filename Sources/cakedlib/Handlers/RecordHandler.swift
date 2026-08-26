//
//  RecordHandler.swift
//  CakedLib
//
//  Boots a VM to its first-boot screen, shows it in a local window, and arms an ActionRecorder
//  against that window's native NSEvent stream — the shared engine behind `caked record`
//  (Sources/caked/Commands/Record.swift). Mirrors ProvisionHandler's `display == .none` VM-boot/
//  local-window pattern (Sources/cakedlib/Handlers/ProvisionHandler.swift) but skips everything
//  PackerLite itself needs (template, IP wait, agent install): recording drives no automation of
//  its own, it only watches whatever a human operator does through the window and writes down
//  what happened. No VNC server is started for this capture path — see
//  VNCVirtualMachineView.actionRecorder for why a direct local window can tap the same real
//  NSEvents AppKit already delivers to it, with no VNC-protocol keysym round-trip and no network
//  listener. `caked`-local only for now — see CLAUDE.md's PackerLite section for the planned (not
//  yet built) cakectl/gRPC counterpart, mirroring how `caked provision` itself started local-only
//  before later gaining one.
//

import CakeAgentLib
import Foundation
import GRPCLib

public struct RecordHandler {
	/// A booted recording session, returned once the VM's local window exists and its
	/// `VNCVirtualMachineView.actionRecorder` tap is armed — ready for an operator sitting at this
	/// host to drive the VM by hand through that window.
	public final class Session: @unchecked Sendable {
		public let vm: VirtualMachine
		public let recorder: ActionRecorder
		public let config: CakedConfiguration

		private let targetView: VMView.NSViewType
		private let lock = NSLock()
		private var stopped = false

		init(vm: VirtualMachine, targetView: VMView.NSViewType, recorder: ActionRecorder, config: CakedConfiguration) {
			self.vm = vm
			self.targetView = targetView
			self.recorder = recorder
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

			self.targetView.actionRecorder = nil

			MainActor.assumeIsolated {
				self.vm.disposeWindow()
			}

			let yaml = self.recorder.finish()

			self.vm.terminateVM { _ in }

			return yaml
		}
	}

	/// Boots `location`'s VM (must not already be running), shows it in a local window, and starts
	/// recording every mouse/keyboard `NSEvent` that window receives. No VNC server, no network
	/// listener — this is a single-local-operator-only capture path (see CLAUDE.md's PackerLite
	/// section for the trade-off against the VNC-server-tap approach).
	@MainActor
	public static func record(
		location: VMLocation,
		storageLocation: StorageLocation,
		runMode: Utils.RunMode
	) throws -> Session {
		let config = try location.config()
		let displaySize = config.display.cgSize

		if location.status.isRunning {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		let handler = VMRunHandler(
			mode: .default,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: .none,
			config: config,
			screenSize: displaySize,
			vncPassword: config.vncPassword ?? UUID().uuidString,
			vncPort: 0,
			recoveryMode: false,
			provisioning: true,
			runMode: .app)

		return try handler.run { _, vm in
			// Mirrors ProvisionHandler's `display == .none` branch exactly: a plain local
			// NSWindow around the VM's own VNCVirtualMachineView, no VNC server involved.
			let targetView = vm.createVirtualMachineView()

			vm.setupWindow()

			let recorder = ActionRecorder(username: config.configuredUser, password: config.configuredPassword)

			targetView.actionRecorder = recorder.record

			return Session(vm: vm, targetView: targetView, recorder: recorder, config: CakedConfiguration(config))
		}
	}
}
