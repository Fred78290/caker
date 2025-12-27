import GRPCLib
//
//  IPSWInstaller.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/07/2025.
//
import Virtualization

#if arch(arm64)
	public class IPSWInstaller: @unchecked Sendable {
		private let virtualMachine: VZVirtualMachine
		private let config: CakeConfig
		private let location: VMLocation
		private let queue: DispatchQueue!
		private let logger = Logger("IPSWInstaller")
		private var installer: VZMacOSInstaller!

		public init(location: VMLocation, config: CakeConfig, runMode: Utils.RunMode, queue: DispatchQueue? = nil) throws {
			let virtualMachine: VZVirtualMachine
			let suspendable = config.suspendable
			let networks: [any NetworkAttachement] = try config.collectNetworks(runMode: runMode)
			let configuration = VZVirtualMachineConfiguration()
			let plateform = try config.platform(nvramURL: location.nvramURL, needsNestedVirtualization: config.nested)
			let soundDeviceConfiguration = VZVirtioSoundDeviceConfiguration()
			let memoryBallons = VZVirtioTraditionalMemoryBalloonDeviceConfiguration()

			var devices: [VZStorageDeviceConfiguration] = [
				VZVirtioBlockDeviceConfiguration(
					attachment: try VZDiskImageStorageDeviceAttachment(
						url: location.diskURL,
						readOnly: false,
						cachingMode: config.os == .linux ? .cached : .automatic,
						synchronizationMode: .full
					))
			]

			let networkDevices = try networks.map {
				let vio = VZVirtioNetworkDeviceConfiguration()

				(vio.macAddress, vio.attachment) = try $0.attachment(location: location, runMode: runMode)

				return vio
			}

			soundDeviceConfiguration.streams = [VZVirtioSoundDeviceOutputStreamConfiguration()]

			configuration.bootLoader = try plateform.bootLoader()
			configuration.cpuCount = config.cpuCount
			configuration.memorySize = config.memorySize
			configuration.platform = try plateform.platform()
			configuration.graphicsDevices = [plateform.graphicsDevice(screenSize: config.display.cgSize)]
			configuration.audioDevices = [soundDeviceConfiguration]
			configuration.keyboards = plateform.keyboards(suspendable)
			configuration.pointingDevices = plateform.pointingDevices(suspendable)
			configuration.networkDevices = networkDevices
			configuration.storageDevices = devices
			configuration.serialPorts = []
			configuration.memoryBalloonDevices = [memoryBallons]

			let spiceAgentConsoleDevice = VZVirtioConsoleDeviceConfiguration()
			let spiceAgentPort = VZVirtioConsolePortConfiguration()
			let spiceAgentPortAttachment = VZSpiceAgentPortAttachment()

			spiceAgentPortAttachment.sharesClipboard = true

			spiceAgentPort.name = VZSpiceAgentPortAttachment.spiceAgentPortName
			spiceAgentPort.attachment = spiceAgentPortAttachment
			spiceAgentConsoleDevice.ports[0] = spiceAgentPort
			configuration.consoleDevices.append(spiceAgentConsoleDevice)

			if config.os == .linux {
				let cdromURL = URL(fileURLWithPath: cloudInitIso, relativeTo: location.diskURL).absoluteURL

				if FileManager.default.fileExists(atPath: cdromURL.path) {
					devices.append(try VirtualMachineEnvironment.createCloudInitDrive(cdromURL: cdromURL))
				}
			}

			try configuration.validate()

			if let queue = queue {
				virtualMachine = VZVirtualMachine(configuration: configuration, queue: queue)
			} else {
				virtualMachine = VZVirtualMachine(configuration: configuration)
			}

			self.config = config
			self.location = location
			self.virtualMachine = virtualMachine
			self.queue = queue
		}

		private func installIPSW(url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler, continuation: CheckedContinuation<Void, any Error>) {
			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] start ipsw install")
			#endif

			self.installer = VZMacOSInstaller(virtualMachine: self.virtualMachine, restoringFromImageAt: url)

			let context = ProgressObserver.ProgressHandlerContext()
			let progressObserver = self.installer.progress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { progress, change in
				if progress.fractionCompleted != context.oldFractionCompleted {
					#if DEBUG
						self.logger.trace("[\(Thread.currentThread.description)] ipsw install progress \(progress.fractionCompleted)")
					#endif

					progressHandler(.progress(context, progress.fractionCompleted))

					#if DEBUG
						self.logger.trace("[\(Thread.currentThread.description)] ipsw leave progress \(progress.fractionCompleted)")
					#endif

					context.oldFractionCompleted = progress.fractionCompleted
				}
			}

			self.installer.install { result in
				#if DEBUG
					self.logger.trace("[\(Thread.currentThread.description)] ipsw install terminated")
				#endif
				self.installer = nil

				continuation.resume(with: result)
				progressObserver.invalidate()
			}

			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] leaving ipsw install")
			#endif
		}

		@MainActor
		private func installIPSWSync(_ url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			try await withTaskCancellationHandler(
				operation: {
					try await withCheckedThrowingContinuation { continuation in
						self.installIPSW(url: url, progressHandler: progressHandler, continuation: continuation)
					}
				},
				onCancel: {
					self.installer.progress.cancel()
				})
		}

		private func installIPSWAsync(_ url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] entering installIPSWAsync")
			#endif

			try await withTaskCancellationHandler(
				operation: {
					#if DEBUG
						self.logger.trace("[\(Thread.currentThread.description)] entering withTaskCancellationHandler")
					#endif

					try await withCheckedThrowingContinuation { continuation in
						#if DEBUG
							self.logger.trace("[\(Thread.currentThread.description)] entering withCheckedThrowingContinuation")
						#endif
						queue.async {
							self.installIPSW(url: url, progressHandler: progressHandler, continuation: continuation)
						}
						self.logger.trace("[\(Thread.currentThread.description)] exiting withCheckedThrowingContinuation")
					}

					#if DEBUG
						self.logger.trace("[\(Thread.currentThread.description)] exiting withTaskCancellationHandler")
					#endif
				},
				onCancel: {
					#if DEBUG
						self.logger.trace("[\(Thread.currentThread.description)] cancel withTaskCancellationHandler")
					#endif
					self.installer.progress.cancel()
				})

			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] exiting installIPSWAsync")
			#endif
		}

		public func installIPSW(_ url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] entering installIPSW")
			#endif

			progressHandler(.step("Installing MacOS from IPSW..."))
			if self.queue == nil {
				try await self.installIPSWSync(url, progressHandler: progressHandler)
			} else {
				try await self.installIPSWAsync(url, progressHandler: progressHandler)
			}

			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] exiting installIPSW")
			#endif

			progressHandler(.step("Install MacOS from IPSW done..."))
		}
	}
#endif
