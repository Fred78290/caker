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

import AppKit
import CakeAgentLib
import Foundation
import GRPCLib
import Combine

public struct RecordHandler {
	public static var currentSession: Session?

	/// A booted recording session, returned once the VM's local window exists and its
	/// `VNCVirtualMachineView.actionRecorder` tap is armed — ready for an operator sitting at this
	/// host to drive the VM by hand through that window. `ObservableObject` so MainWindow's toolbar
	/// recording controls can track `state`/`hasRecordedActions` live.
	public final class Session: ObservableObject, @unchecked Sendable, Cancellable {
		public enum State: Sendable {
			case stopped
			case recording
			case suspended
		}

		public let vm: VirtualMachine
		public let recorder: ActionRecorder
		public let config: CakedConfiguration
		@Published public private(set) var state: State = .stopped

		@Published public private(set) var isVoiceOverActived: Bool = false

		/// Mirrors `recorder.hasRecordedActions` onto the main thread so SwiftUI can observe it —
		/// the recorder itself is lock-guarded, not observable.
		@Published public private(set) var hasRecordedActions = false

		/// Whether the OCR-assist overlay is currently armed — toggled explicitly from the
		/// recording window's toolbar (see `RecordingControls` in `Sources/caked/MainApp.swift`),
		/// not inferred from any held key. See `ActionRecorder.locateModeActive`'s doc comment for
		/// why: Fn is heavily used by genuine macOS accessibility shortcuts (VoiceOver's Fn+F5, Full
		/// Keyboard Access's Fn+Control+F7) that must still record normally.
		@Published public private(set) var isLocateModeActive = false

		private let targetView: VMView.NSViewType
		private let destination: URL

		@MainActor
		private static func setActionRecorder(_ actionRecorder: RecordedActionHandler?, on targetView: VMView.NSViewType) {
			targetView.actionRecorder = actionRecorder
		}

		@MainActor
		init(vm: VirtualMachine, targetView: VMView.NSViewType, config: CakedConfiguration, destination: URL) {
			self.vm = vm
			self.targetView = targetView
			self.recorder = ActionRecorder(os: config.os, username: config.configuredUser, password: config.configuredPassword)
			self.config = config
			self.destination = destination
			self.state = .recording

			Self.setActionRecorder(self.handleRecordedAction, on: targetView)

			RecordHandler.currentSession = self
		}

		/// The armed tap: forwards to the recorder, then keeps the published
		/// `hasRecordedActions` mirror in sync (on the main thread — the view tap delivers on
		/// main, but the VNC-server tap path arrives on a background queue).
		private func handleRecordedAction(_ sender: NSView, _ action: RecordedAction) {
			self.recorder.record(sender, action)

			let hasRecordedActions = self.recorder.hasRecordedActions

			if hasRecordedActions != self.hasRecordedActions {
				if Thread.isMainThread {
					self.hasRecordedActions = hasRecordedActions
				} else {
					DispatchQueue.main.async {
						self.hasRecordedActions = hasRecordedActions
					}
				}
			}
		}

		/// Stops recording, tears the VM down, and returns the recorded session serialized as a
		/// `boot_command:` YAML document (see `ActionRecorder.finish()`). Safe to call more than
		/// once or from a signal handler — only the first call tears anything down; later calls
		/// just re-return the already-finished YAML.
		@MainActor
		public func stop(completionHandler: @escaping(String) -> Void) {
			guard self.state != .stopped else {
				return completionHandler(self.recorder.finish())
			}

			self.state = .stopped

			Self.setActionRecorder(nil, on: self.targetView)

			// _stopVM() (VirtualMachine.swift) never disposes the window itself — that only
			// happens automatically via the VNC-server-stop delegate callback (didStop(_:)), which
			// this local-window-only capture path never triggers since it starts no VNC server.
			// Without this explicit call the window created by RecordHandler.record(...) below was
			// simply leaked (never closed) once a recording session stopped.
			self.vm.disposeWindow()

			let yaml = self.recorder.finish()

			self.vm.stopFromUI { _ in
				return completionHandler(yaml)
			}
		}

		@MainActor
		public func reset() {
			self.recorder.reset()
			self.hasRecordedActions = false
			self.isVoiceOverActived = false
		}

		@MainActor
		public func suspend() {
			if self.state == .recording {
				Self.setActionRecorder(nil, on: self.targetView)
				self.state = .suspended
			}
		}

		@MainActor
		public func resume() {
			if self.state == .suspended {
				Self.setActionRecorder(self.handleRecordedAction, on: self.targetView)
				self.state = .recording
			}
		}

		/// Arms or disarms the OCR-assist overlay from the toolbar. Distinct from `suspend()`/
		/// `resume()` — this doesn't stop action capture, it just toggles whether a click lands as
		/// `<locate>`/`<clickText>` (when text is recognized under it) versus a raw
		/// `<click point="X,Y">`, and suppresses modifier steps that are only the click-type
		/// selector (see `ActionRecorder.recordKey`).
		@MainActor
		public func toggleLocateMode() {
			self.isLocateModeActive.toggle()
			self.recorder.setLocateModeActive(self.isLocateModeActive, sender: self.targetView)
		}

		@MainActor
		public func toggleVoiceOver(confirm: Bool) {
			self.isVoiceOverActived.toggle()
			self.recorder.toggleVoiceOver(confirm: confirm)
			self.hasRecordedActions = true
		}

		public func cancel() {
			stopAndSave()
		}

		func stopAndSave() {
			let yaml = self.recorder.finish()

			do {
				try yaml.write(to: destination, atomically: true, encoding: .utf8)

				Logger.appendNewLine(String(localized: "Recorded template saved to \(destination.path)"))
				Logger.appendNewLine(String(localized: "This is a first draft — review it and consider hardening timing-sensitive waits with <locate> anchors before relying on it for unattended --autoinstall runs."))
			} catch {
				Logger(self).error("Failed to write recorded template to \(destination.path): \(error)")
			}
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
		destination: URL,
		runMode: Utils.RunMode
	) throws -> (Session, VMRunHandler) {
		let config = try location.config()
		let displaySize = config.display.cgSize

		if location.status.isRunning {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		let handler = VMRunHandler(
			serviceMode: .default,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: .none,
			config: config,
			screenSize: displaySize,
			vncPassword: config.vncPassword ?? UUID().uuidString,
			vncPort: 0,
			vmMode: .recording,
			runMode: runMode)

		return (try handler.run { _, vm in
			// Mirrors ProvisionHandler's `display == .none` branch exactly: a plain local
			// NSWindow around the VM's own VNCVirtualMachineView, no VNC server involved.
			let targetView = vm.createVirtualMachineView()

			//vm.setupWindow(canHide: false)

			return Session(vm: vm, targetView: targetView, config: CakedConfiguration(config), destination: destination)
		}, handler)
	}
}
