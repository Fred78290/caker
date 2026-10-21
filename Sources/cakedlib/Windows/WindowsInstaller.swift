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
import CryptoKit
import Foundation
import GRPCLib
import Synchronization

public class WindowsInstaller: @unchecked Sendable {
	private let logger = Logger("WindowsInstaller")

	/// Name of the installation media image inside the VM's folder.
	private let mediaFileName = "install.\(DiskAttachement.windowsMediaExtension)"

	/// How long each VM run may take: applying the image and Windows' own first-boot setup are both slow.
	private let installTimeout: TimeInterval = 90 * 60
	private let firstBootTimeout: TimeInterval = 45 * 60

	/// Windows restarts itself a few times while it sets up.
	private let maxFirstBootRuns = 8

	private let location: VMLocation
	private let config: CakeConfig
	private let windowsISO: URL
	private let username: String
	private let password: String
	private let runMode: Utils.RunMode
	private let wizardID: UUID
	private let queue: DispatchQueue
	private var vmStateObservation: NSKeyValueObservation? = nil
	private let canceled: Mutex<Bool> = .init(false)
	public var virtualMachine: VirtualMachine?

	public init(location: VMLocation, config: CakeConfig, windowsISO: URL, username: String, password: String, wizardID: UUID, queue: DispatchQueue?, runMode: Utils.RunMode) {
		self.location = location
		self.config = config
		self.windowsISO = windowsISO
		self.username = username
		self.password = password
		self.runMode = runMode
		self.wizardID = wizardID
		self.queue = queue ?? DispatchQueue.main
	}

	public func cancel() {
		self.canceled.withLock {
			$0 = true

			self.virtualMachine?.stopServiceForProvisionning()
			self.virtualMachine?.stopGrandCentralUpdate()
			self.virtualMachine?.stopVM()
		}
	}

	public func install(progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
		// The installer drives hdiutil, diskutil and rsync, which a sandboxed app can't launch
		guard Bundle.isApplicationSandboxed == false else {
			throw ServiceError(String(localized: "Windows installation is not available in the App Store build"))
		}

		defer {
			if let virtualMachine = self.virtualMachine {
				DispatchQueue.main.async {
					NotificationCenter.default.post(name: VMBuilder.WinPETerminatedNotification, object: virtualMachine, userInfo: ["wizardID": self.wizardID])
				}
			}
		}

		try await withTaskCancellationHandler(
			operation: {
				try await self.doInstall(progressHandler: progressHandler)
			},
			onCancel: {
				self.cancel()
			})
	}

	public func doInstall(progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
		let virtioWinISO = try await CloudImageConverter.downloadISO(remoteURL: WindowsInstallationMedia.virtioWinURL, runMode: runMode, progressHandler: progressHandler)
		let winFspMSI = try await downloadWinFsp(progressHandler: progressHandler)
		let mediaURL = location.rootURL.appendingPathComponent(mediaFileName)
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let agent = try await Utilities.cakeagentWindowsBinary(runMode: runMode)
		let openSSH = try await downloadOpenSSH(progressHandler: progressHandler)
		let authorizedKeys = (try? CloudInit.sshAuthorizedKeys(sshAuthorizedKeyPath: config.sshAuthorizedKey, runMode: runMode)) ?? []
		let options = WindowsInstallationMedia.Options(
			username: username, password: password, computerName: Self.computerName(for: location.name),
			cakeAgent: .init(executable: agent, caCert: certificates.caCertURL, serverCert: certificates.serverCertURL, serverKey: certificates.serverKeyURL),
			openSSH: .init(archive: openSSH, authorizedKeys: authorizedKeys))
		let windowsISO = self.windowsISO

		self.logger.debug("Preparing the Windows installation media")

		progressHandler(.step(String(localized: "Preparing the Windows installation media")))

		let media = try await Task.detached {
			try WindowsInstallationMedia.create(at: mediaURL, windowsISO: windowsISO, virtioWinISO: virtioWinISO, winFspMSI: winFspMSI, options: options) { step in
				progressHandler(.substep(step))
			}
		}.value

		defer { try? FileManager.default.removeItem(at: mediaURL) }

		// The media is a second disk for the installer run only
		config.attachedDisks = [DiskAttachement(diskPath: mediaURL, readOnly: false)]
		try config.save()

		progressHandler(.step(String(localized: "Installing Windows")))

		let virtualMachine = try await createVirtualMachine(progressHandler)

		self.virtualMachine = virtualMachine

		defer {
			virtualMachine.stopServiceForProvisionning()
			virtualMachine.stopGrandCentralUpdate()
		}

		self.logger.info("Boot the Windows installation media")

		progressHandler(.substep(String(localized: "Booting the Windows installation media")))

		try await run(timeout: installTimeout, progressHandler)

		let result = try media.installResult()

		config.attachedDisks = []
		try config.save()

		guard result.succeeded else {
			let tail = result.log.split(whereSeparator: \.isNewline).suffix(20).joined(separator: "\n")

			progressHandler(.substep(String(localized: "Windows installation failed")))

			self.logger.error("Windows installation failed \(tail)")

			throw ServiceError(String(format: String(localized: "Windows installation failed:\n%@"), tail))
		}

		progressHandler(.substep(String(localized: "Windows installation finished")))

		progressHandler(.step(String(localized: "Finish windows setup")))

		for attempt in 1...maxFirstBootRuns {
			if canceled.withLock({ $0 }) {
				throw CancellationError()
			}

			self.logger.info("Windows first boot, run \(attempt) of \(maxFirstBootRuns)")

			try await run(timeout: firstBootTimeout, progressHandler)

			if let marker = try firstBootMarker(location: location) {
				let agentInstalled = Self.agentIsRunning(marker: marker)

				self.logger.info("Windows first boot completed: \(marker.replacingOccurrences(of: "\r\n", with: " "))")

				if agentInstalled == false {
					progressHandler(.substep(String(localized: "Windows setup finished, but the cakeagent service may not be running")))
					logger.warn("Windows setup finished, but the cakeagent service may not be running: \(marker.replacingOccurrences(of: "\r\n", with: " "))")
				}

				if marker.contains("gpudriver=none") == false && marker.contains("gpudriver=0") == false {
					progressHandler(.substep(String(localized: "Windows setup finished, but the GPU driver may not load")))
					logger.warn("Windows setup finished, but the GPU driver may not load: \(marker.replacingOccurrences(of: "\r\n", with: " "))")
				}

				if marker.contains("display=none") == false && marker.contains("display=0") == false {
					progressHandler(.substep(String(localized: "Windows setup finished, but resizing the display may not work")))
					logger.warn("Windows setup finished, but resizing the display may not work: \(marker.replacingOccurrences(of: "\r\n", with: " "))")
				}

				if marker.contains("ssh=0-running") == false {
					progressHandler(.substep(String(localized: "Windows setup finished, but the OpenSSH server may not be running")))
					logger.warn("Windows setup finished, but the OpenSSH server may not be running: \(marker.replacingOccurrences(of: "\r\n", with: " "))")
				}

				if marker.contains("winfsp=0") == false || marker.contains("service=0") == false {
					progressHandler(.substep(String(localized: "Windows setup finished, but directory sharing may not work")))
					logger.warn("Windows setup finished, but directory sharing may not work: \(marker.replacingOccurrences(of: "\r\n", with: " "))")
				}

				// "agent=<install exit code>-running": the service is up, so the host can talk to it
				config.agent = agentInstalled
				config.provisioned = true
				try config.save()

				progressHandler(.provisioned(.success(.init(name: location.name, provisioned: true, reason: String(localized: "Windows setup finished successfully")))))
				return
			}

			progressHandler(.substep(String(localized: "Windows try new setup \(attempt) of \(maxFirstBootRuns)")))
		}

		throw ServiceError(String(localized: "Windows did not finish setting itself up"))
	}

	/// "agent=<install exit code>-running": the service was installed and is up, so the host can talk to it.
	static func agentIsRunning(marker: String) -> Bool {
		marker.contains("agent=0-running")
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

	/// WinFsp's installer, checked against its known hash before it goes on the media: it runs as SYSTEM.
	private func downloadWinFsp(progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> URL {
		let cache = try CommonCacheImageCache(scheme: "msi", location: "installers", name: WindowsInstallationMedia.winFspURL.host()!, ext: "msi", runMode: runMode)
		let msi = try await CloudImageConverter.downloadRemoteToCache(remoteURL: WindowsInstallationMedia.winFspURL, imageCache: cache, runMode: runMode, progressHandler: progressHandler)
		let hash = SHA256.hash(data: try Data(contentsOf: msi)).map { String(format: "%02x", $0) }.joined()

		guard hash == WindowsInstallationMedia.winFspSHA256 else {
			try? FileManager.default.removeItem(at: msi)

			throw ServiceError(String(format: String(localized: "The WinFsp installer doesn't match its expected checksum (%@)"), hash))
		}

		return msi
	}

	/// Win32-OpenSSH's archive for this Mac's architecture (a guest only runs on its host's), checked against its known hash.
	private func downloadOpenSSH(progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> URL {
		let release = WindowsInstallationMedia.openSSHArchive(for: .host)
		let cache = try CommonCacheImageCache(scheme: "zip", location: "installers", name: release.url.host()!, ext: "zip", runMode: runMode)
		let archive = try await CloudImageConverter.downloadRemoteToCache(remoteURL: release.url, imageCache: cache, runMode: runMode, progressHandler: progressHandler)
		let hash = SHA256.hash(data: try Data(contentsOf: archive)).map { String(format: "%02x", $0) }.joined()

		guard hash == release.sha256 else {
			try? FileManager.default.removeItem(at: archive)

			throw ServiceError(String(format: String(localized: "The OpenSSH archive doesn't match its expected checksum (%@)"), hash))
		}

		return archive
	}

	/// What Windows' setup left on the EFI system partition (the first partition the install script creates), or
	/// `nil` if it hasn't finished.
	private func firstBootMarker(location: VMLocation) throws -> String? {
		let device = try WindowsInstallationMedia.Disk.attach(location.diskURL, readOnly: true)

		defer { WindowsInstallationMedia.Disk.detach(device) }

		let volume = try WindowsInstallationMedia.Disk.mount("\(device)s1", readOnly: true)

		guard let marker = try? String(contentsOf: volume.appendingPathComponent("EFI/caker/installed"), encoding: .utf8) else {
			return nil
		}

		// Only there when the agent service wasn't running and setup ran it in front to see why
		if let agentLog = try? String(contentsOf: volume.appendingPathComponent("EFI/caker/agent.log"), encoding: .utf8), agentLog.isEmpty == false {
			logger.warn("cakeagent output: \(agentLog.replacingOccurrences(of: "\r\n", with: " | "))")
		}

		return marker
	}

	/// Runs the VM until it stops, however it stops, or stops it and throws once `timeout` has passed.
	private func run(timeout: TimeInterval, _ progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
		if let virtualMachine = self.virtualMachine {
			let waiter = await StopWaiter(virtualMachine)

			virtualMachine.delegate = waiter

			try await virtualMachine.startVM()

			let stopped = await waiter.waitUntilStopped(timeout: timeout)

			if stopped == false {
				try? await virtualMachine.stopVM()

				throw ServiceError(String(localized: "Windows installation timed out"))
			}
		}
	}

	@MainActor
	private func createVirtualMachine(_ progressHandler: @escaping ProgressObserver.BuildProgressHandler) throws -> VirtualMachine {
		let virtualMachine = try VirtualMachine(location: self.location, config: self.config, display: Bundle.runInCaker ? .ui : .vnc, screenSize: self.config.display.cgSize, mode: .provisioning, runMode: self.runMode, queue: self.queue)

		self.virtualMachine = virtualMachine

		try virtualMachine.location.writeProvisionning()
		try virtualMachine.startServiceForProvisionning()

		if Bundle.runInCaker {
			virtualMachine.createVirtualMachineView()
		} else {
			if ServiceHandler.isAgentRunning.running {
				logger.info("Start GCD for VM: \(location.name)")
				// Observe VM state to start GCD when it becomes running
				var didStart = false

				self.vmStateObservation = virtualMachine.virtualMachine.observe(\.state, options: [.initial, .new]) { [weak self] vm, change in
					guard let self = self else { return }

					// Start only once when running
					if didStart == false && vm.state == .running {
						didStart = true

						self.logger.info("Start GCD for VM when running: \(self.location.name)")

						Task {
							do {
								try await virtualMachine.startGrandCentralUpdate(frequency: 1, runMode: self.runMode)
							} catch is CancellationError {
								self.logger.debug("Cancelled GCD for VM: \(self.location.name)")
							} catch {
								self.logger.error("Failed to start GCD for VM: \(self.location.name), error: \(error.localizedDescription)")
							}
						}

						// Invalidate observation after starting
						self.vmStateObservation?.invalidate()
						self.vmStateObservation = nil
					}
				}
			}

			let vncPassword = config.vncPassword ?? UUID().uuidString
			let vncURL = try virtualMachine.startVncServer(vncPassword: vncPassword, port: 0)

			logger.info("VNC server started at \(vncURL.map(\.absoluteString).joined(separator: ", "))")

			guard let vncURL = vncURL.first else {
				throw ServiceError(String(localized: "Unable to get VNC URL for VM \(location.name)"))
			}

			progressHandler(.provision(.init(vncURL: vncURL, screenSize: .init(virtualMachine.vzMachineView!.bounds.size), config: CakedConfiguration(config))))
		}

		NotificationCenter.default.post(name: VMBuilder.WinPEStartNotification, object: virtualMachine, userInfo: ["wizardID": wizardID])

		return virtualMachine
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
