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
import Combine

public struct RecordHandler {
	public static var currentSession: Session?

	/// A booted recording session, returned once the VM's local window exists and its
	/// `VNCVirtualMachineView.actionRecorder` tap is armed — ready for an operator sitting at this
	/// host to drive the VM by hand through that window.
	public final class Session: @unchecked Sendable, Cancellable {
		public enum State: Sendable {
			case stopped
			case recording
			case suspended
		}

		public let vm: VirtualMachine
		public let recorder: ActionRecorder
		public let config: CakedConfiguration
		public var state: State = .stopped

		private let targetView: VMView.NSViewType
		private let lock = NSLock()
		private let destination: URL

		init(vm: VirtualMachine, targetView: VMView.NSViewType, config: CakedConfiguration, destination: URL) {
			self.vm = vm
			self.targetView = targetView
			self.recorder = ActionRecorder(os: config.os, username: config.configuredUser, password: config.configuredPassword)
			self.config = config
			self.destination = destination

			targetView.actionRecorder = self.recorder.record
			
			RecordHandler.currentSession = self
		}

		/// Stops recording, tears the VM down, and returns the recorded session serialized as a
		/// `boot_command:` YAML document (see `ActionRecorder.finish()`). Safe to call more than
		/// once or from a signal handler — only the first call tears anything down; later calls
		/// just re-return the already-finished YAML.
		public func stop(completionHandler: @escaping(String) -> Void) {
			self.lock.lock()

			guard self.state != .stopped else {
				self.lock.unlock()
				return completionHandler(self.recorder.finish())
			}

			self.state = .stopped
			self.lock.unlock()

			self.targetView.actionRecorder = nil

			//MainActor.assumeIsolated {
			//	self.vm.disposeWindow()
			//}

			let yaml = self.recorder.finish()

			self.vm.stopVM { _ in
				return completionHandler(yaml)
			}
		}

		public func reset() {
			self.recorder.reset()
		}

		public func suspend() {
			self.lock.withLock {
				if self.state == .recording {
					self.targetView.actionRecorder = nil
					self.state = .suspended
				}
			}
		}

		public func resume() {
			self.lock.withLock {
				if self.state == .suspended {
					self.targetView.actionRecorder = self.recorder.record
					self.state = .recording
				}
			}
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
			runMode: .app)

		return (try handler.run { _, vm in
			// Mirrors ProvisionHandler's `display == .none` branch exactly: a plain local
			// NSWindow around the VM's own VNCVirtualMachineView, no VNC server involved.
			let targetView = vm.createVirtualMachineView()

			//vm.setupWindow(canHide: false)

			return Session(vm: vm, targetView: targetView, config: CakedConfiguration(config), destination: destination)
		}, handler)
	}
}
