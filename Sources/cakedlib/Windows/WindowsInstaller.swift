//
//  WindowsInstaller.swift
//  Caker
//
//  Installs Windows 11 for ARM from a Microsoft ISO, unattended, in two VM runs:
//
//   1. The VM boots the installation media (see WindowsInstallationMedia) into WinPE, whose shell runs the
//      install script: it partitions the empty system disk, applies the Windows image and the virtio drivers,
//      and powers the VM off. The script's outcome is read back from the media.
//   2. The VM boots the installed Windows, which sets itself up (specialize and out-of-box passes, each of which
//      may restart the guest: Virtualization.framework stops a VM whose guest reboots, so the VM is started
//      again until setup leaves its "done" marker on the EFI system partition) and powers off.
//
//  Nothing can be shown while WinPE runs (see WindowsInstallResources), so the VM has no display here.
//

import AppKit
import CakeAgentLib
import Foundation
import GRPCLib

public enum WindowsInstaller {
	private static let logger = Logger("WindowsInstaller")

	/// Name of the installation media image inside the VM's folder.
	static let mediaFileName = "install.\(DiskAttachement.windowsMediaExtension)"

	/// How long each VM run may take: applying the image and Windows' own first-boot setup are both slow.
	private static let installTimeout: TimeInterval = 90 * 60
	private static let firstBootTimeout: TimeInterval = 45 * 60

	/// Windows restarts itself a few times while it sets up.
	private static let maxFirstBootRuns = 8

	public static func install(location: VMLocation, config: CakeConfig, windowsISO: URL, username: String, password: String, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
		// The installer drives hdiutil, diskutil and wimlib, which a sandboxed app can't launch
		guard Bundle.isApplicationSandboxed == false else {
			throw ServiceError(String(localized: "Windows installation is not available in the App Store build"))
		}

		let virtioWinISO = try await CloudImageConverter.downloadISO(remoteURL: WindowsInstallationMedia.virtioWinURL, runMode: runMode, progressHandler: progressHandler)
		let mediaURL = location.rootURL.appendingPathComponent(mediaFileName)
		let options = WindowsInstallationMedia.Options(username: username, password: password, computerName: computerName(for: location.name))

		progressHandler(.step(String(localized: "Preparing the Windows installation media")))

		let media = try await Task.detached {
			try WindowsInstallationMedia.create(at: mediaURL, windowsISO: windowsISO, virtioWinISO: virtioWinISO, options: options) { step in
				progressHandler(.substep(step))
			}
		}.value

		defer { try? FileManager.default.removeItem(at: mediaURL) }

		// The media is a second disk for the installer run only
		config.attachedDisks = [DiskAttachement(diskPath: mediaURL, readOnly: false)]
		try config.save()

		progressHandler(.step(String(localized: "Installing Windows")))

		try await run(location: location, config: config, runMode: runMode, timeout: installTimeout)

		let result = try media.installResult()

		config.attachedDisks = []
		try config.save()

		guard result.succeeded else {
			let tail = result.log.split(whereSeparator: \.isNewline).suffix(20).joined(separator: "\n")

			throw ServiceError(String(format: String(localized: "Windows installation failed:\n%@"), tail))
		}

		progressHandler(.step(String(localized: "Starting Windows for the first time")))

		for attempt in 1...maxFirstBootRuns {
			logger.info("Windows first boot, run \(attempt) of \(maxFirstBootRuns)")

			try await run(location: location, config: config, runMode: runMode, timeout: firstBootTimeout)

			if try firstBootCompleted(location: location) {
				config.provisioned = true
				try config.save()

				return
			}
		}

		throw ServiceError(String(localized: "Windows did not finish setting itself up"))
	}

	/// Windows computer names are at most 15 characters from `A-Z a-z 0-9 -`, and may not be all digits.
	static func computerName(for vmName: String) -> String {
		let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-")
		var name = String(vmName.map { allowed.contains($0) ? $0 : "-" }.prefix(15)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))

		if name.isEmpty || name.allSatisfy(\.isNumber) {
			name = "CAKER-WIN"
		}

		return name
	}

	/// Whether Windows' setup left its marker on the EFI system partition (the first partition the install script creates).
	static func firstBootCompleted(location: VMLocation) throws -> Bool {
		let device = try WindowsInstallationMedia.Disk.attach(location.diskURL, readOnly: true)

		defer { WindowsInstallationMedia.Disk.detach(device) }

		let volume = try WindowsInstallationMedia.Disk.mount("\(device)s1", readOnly: true)

		return FileManager.default.fileExists(atPath: volume.appendingPathComponent("EFI/caker/installed").path)
	}

	/// Runs the VM until it stops, however it stops, or stops it and throws once `timeout` has passed.
	@MainActor
	private static func run(location: VMLocation, config: CakeConfig, runMode: Utils.RunMode, timeout: TimeInterval) async throws {
		let virtualMachine = try VirtualMachine(location: location, config: config, display: .none, screenSize: config.display.cgSize, mode: .provisioning, runMode: runMode, queue: nil)
		let waiter = StopWaiter(virtualMachine)

		virtualMachine.delegate = waiter

		try await virtualMachine.startVM()

		let stopped = await waiter.waitUntilStopped(timeout: timeout)

		if stopped == false {
			try? await virtualMachine.stopVM()

			throw ServiceError(String(localized: "Windows installation timed out"))
		}
	}
}

/// Tells when a VM has stopped, whether the guest powered it off, restarted it or it crashed.
@MainActor
private final class StopWaiter: VirtualMachineDelegate {
	private let virtualMachine: VirtualMachine
	private var continuation: CheckedContinuation<Void, Never>?

	init(_ virtualMachine: VirtualMachine) {
		self.virtualMachine = virtualMachine
	}

	nonisolated func didChangedState(_ vm: VirtualMachine) {
		Task { @MainActor in
			self.resumeIfStopped()
		}
	}

	nonisolated func didScreenshot(_ vm: VirtualMachine, screenshot: NSImage) {}

	private var isStopped: Bool {
		switch virtualMachine.virtualMachine.state {
		case .stopped, .error: return true
		default: return false
		}
	}

	private func resumeIfStopped() {
		if isStopped, let continuation {
			self.continuation = nil
			continuation.resume()
		}
	}

	/// Returns `true` once the VM stopped, `false` if `timeout` seconds passed first.
	func waitUntilStopped(timeout: TimeInterval) async -> Bool {
		let deadline = Date().addingTimeInterval(timeout)

		while isStopped == false {
			if Date() > deadline {
				return false
			}

			await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
				self.continuation = continuation

				// Wake up now and then so the deadline is honored even if no state change arrives
				Task { @MainActor in
					try? await Task.sleep(nanoseconds: 5_000_000_000)
					self.resumeIfStopped()
					if let pending = self.continuation {
						self.continuation = nil
						pending.resume()
					}
				}
			}
		}

		return true
	}
}
