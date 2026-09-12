//
//  IPSWInstaller.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/07/2025.
//
#if arch(arm64)
	import CakeAgentLib
	import GRPCLib
	import Synchronization
	import Virtualization

	#if USE_VIRTUAL_INSTALL_BACKEND
		import VirtualInstallSPI
	#endif

	#if USE_VIRTUAL_INSTALL_BACKEND
		private final class OutcomeBox: @unchecked Sendable {
			var outcome: DeviceRestoreOutcome? = nil
		}
	#endif

	public class IPSWInstaller: @unchecked Sendable {
		private let config: CakeConfig
		private let location: VMLocation
		private let queue: DispatchQueue!
		private let logger = Logger("IPSWInstaller")
		private let runMode: Utils.RunMode
		private let wizardID: UUID
		public var virtualMachine: VirtualMachine?

		final class SendableVZMacOSInstaller: @unchecked Sendable {
			let canceled: Mutex<Bool> = .init(false)
			var installer: VZMacOSInstaller?
			let virtualMachine: VirtualMachine
			let restoringFromImageAt: URL

			init(_ virtualMachine: VirtualMachine, restoringFromImageAt: URL) {
				self.virtualMachine = virtualMachine
				self.restoringFromImageAt = restoringFromImageAt
			}

			func install(progressHandler: @escaping ProgressObserver.BuildProgressHandler, continuation: CheckedContinuation<Void, any Error>) {
				#if DEBUG
					let logger = Logger("IPSWInstaller")
				#endif

				#if DEBUG
					logger.trace("[\(Thread.currentThread.description)] start ipsw install")
				#endif

				let installer = VZMacOSInstaller(virtualMachine: virtualMachine.virtualMachine, restoringFromImageAt: restoringFromImageAt)
				let isCanceled = self.canceled.withLock { canceled in
					if canceled {
						return true
					}

					self.installer = installer

					return false
				}

				if isCanceled {
					continuation.resume(throwing: CancellationError())
					return
				}

				let context = ProgressObserver.ProgressHandlerContext()
				let progressObserver = installer.progress.observe(\.fractionCompleted, options: [.initial, .old, .new]) { progress, change in
					if progress.fractionCompleted != context.oldFractionCompleted {
						#if DEBUG
							logger.trace("[\(Thread.currentThread.description)] ipsw install progress \(progress.fractionCompleted)")
						#endif

						progressHandler(.progress(context, progress.fractionCompleted))

						#if DEBUG
							logger.trace("[\(Thread.currentThread.description)] ipsw leave progress \(progress.fractionCompleted)")
						#endif

						context.oldFractionCompleted = progress.fractionCompleted
					}
				}

				installer.install { result in
					#if DEBUG
						logger.trace("[\(Thread.currentThread.description)] ipsw install terminated")
					#endif

					self.canceled.withLock { _ in
						self.installer = nil
					}

					continuation.resume(with: result)
					progressObserver.invalidate()
				}

				#if DEBUG
					logger.trace("[\(Thread.currentThread.description)] leaving ipsw install")
				#endif
			}

			func cancel() {
				self.canceled.withLock {
					$0 = true

					// Progress.cancel() is thread-safe per Apple SDK contract.
					self.installer?.progress.cancel()
				}
			}
		}

		public init(location: VMLocation, config: CakeConfig, wizardID: UUID, runMode: Utils.RunMode, queue: DispatchQueue? = nil) throws {
			self.config = config
			self.location = location
			self.queue = queue
			self.runMode = runMode
			self.wizardID = wizardID
		}

		@MainActor
		private func createVirtualMachine(_ progressHandler: @escaping ProgressObserver.BuildProgressHandler) throws -> VirtualMachine {
			let virtualMachine = try VirtualMachine(location: self.location, config: self.config, display: Bundle.runInCaker ? .ui : .vnc, screenSize: self.config.display.cgSize, mode: .provisioning, runMode: self.runMode, queue: self.queue)

			self.virtualMachine = virtualMachine

			if Bundle.runInCaker {
				virtualMachine.createVirtualMachineView()
			} else {
				let vncPassword = config.vncPassword ?? UUID().uuidString
				let vncURL = try virtualMachine.startVncServer(vncPassword: vncPassword, port: 0)

				logger.info("VNC server started at \(vncURL.map(\.absoluteString).joined(separator: ", "))")

				guard let vncURL = vncURL.first else {
					throw ServiceError(String(localized: "Unable to get VNC URL for VM \(location.name)"))
				}

				progressHandler(.provision(.init(vncURL: vncURL, screenSize: .init(virtualMachine.vzMachineView!.bounds.size), config: CakedConfiguration(config))))
			}

			NotificationCenter.default.post(name: VMBuilder.IPSWStartNotification, object: virtualMachine, userInfo: ["wizardID": wizardID])

			return virtualMachine
		}

		// MARK: - VZMacOSInstaller path (default)

		@MainActor
		private func installIPSWSync(_ url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			let virtualMachine = try self.createVirtualMachine(progressHandler)
			let installer = SendableVZMacOSInstaller(virtualMachine, restoringFromImageAt: url)

			self.logger.debug("Install IPSW via VZMacOSInstaller")

			defer {
				NotificationCenter.default.post(name: VMBuilder.IPSWTerminatedNotification, object: virtualMachine, userInfo: ["wizardID": wizardID])
			}

			try await withTaskCancellationHandler(
				operation: {
					try await withCheckedThrowingContinuation { continuation in
						installer.install(progressHandler: progressHandler, continuation: continuation)
					}
				},
				onCancel: {
					installer.cancel()
				})
		}

		private func installIPSWAsync(_ url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			let virtualMachine = try await self.createVirtualMachine(progressHandler)
			let installer = SendableVZMacOSInstaller(virtualMachine, restoringFromImageAt: url)

			self.logger.debug("Install IPSW via VZMacOSInstaller")

			defer {
				DispatchQueue.main.async {
					NotificationCenter.default.post(name: VMBuilder.IPSWTerminatedNotification, object: virtualMachine, userInfo: ["wizardID": self.wizardID])
				}
			}

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
							installer.install(progressHandler: progressHandler, continuation: continuation)
						}
						#if DEBUG
							self.logger.trace("[\(Thread.currentThread.description)] exiting withCheckedThrowingContinuation")
						#endif
					}

					#if DEBUG
						self.logger.trace("[\(Thread.currentThread.description)] exiting withTaskCancellationHandler")
					#endif
				},
				onCancel: {
					#if DEBUG
						self.logger.trace("[\(Thread.currentThread.description)] cancel withTaskCancellationHandler")
					#endif
					installer.cancel()
				})

			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] exiting installIPSWAsync")
			#endif
		}

		// MARK: - AMRestore path (macOS 27+ guests)

		#if USE_VIRTUAL_INSTALL_BACKEND
			/// Returns true when the AMRestore backend should be used instead of
			/// `VZMacOSInstaller`. Decision mirrors the UTM/VirtualBuddy logic:
			/// forced via UserDefaults OR conditional restore image targets macOS 27+.
			@available(macOS 26.0, *)
			private func shouldUseVirtualInstallBackend(url: URL) async -> Bool {
				if UserDefaults.standard.bool(forKey: "CakerForceVirtualInstallBackend") {
					return true
				}

				#if FORCE_USE_VIRTUAL_INSTALL_BACKEND
					guard
						let image = try? await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<VZMacOSRestoreImage, Error>) in
							VZMacOSRestoreImage.load(from: url) { result in
								continuation.resume(with: result)
							}
						})
					else { return false }

					return image.operatingSystemVersion.majorVersion >= 27
				#else
					return false
				#endif
			}

			/// Boots the VM into DFU mode so the AMRestore framework can see it as a
			/// restorable device.
			@available(macOS 26.0, *)
			private func startInDFUMode(_ virtualMachine: VirtualMachine) async throws {
				let startOptions = VZMacOSVirtualMachineStartOptions()
				startOptions._forceDFU = true

				try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
					let doStart = {
						virtualMachine.virtualMachine.start(options: startOptions) { error in
							if let error {
								continuation.resume(throwing: error)
							} else {
								continuation.resume()
							}
						}
					}

					if let queue {
						queue.async { doStart() }
					} else {
						DispatchQueue.main.async { doStart() }
					}
				}
			}

			/// Installs macOS by booting the VM in DFU mode and driving the restore via
			/// the private `AMRestorableDeviceRestore` SPI (AMRestore framework). This
			/// works around the `VZMacOSInstaller` bug that prevents installing macOS 27
			/// guests on macOS 26 hosts (utmapp/UTM#7746).
			@available(macOS 26.0, *)
			private func installViaAMRestore(url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
				guard let ecidData = config.ecid, let ecid = cakerECID(fromMachineIdentifierData: ecidData) else {
					throw ServiceError(String(localized: "Cannot determine device ECID from VM configuration"))
				}

				self.logger.debug("Install IPSW via AMRestore")

				progressHandler(.step(String(localized: "Starting VM in DFU mode for macOS 27 install...")))

				let virtualMachine = try await self.createVirtualMachine(progressHandler)

				defer {
					DispatchQueue.main.async {
						NotificationCenter.default.post(name: VMBuilder.IPSWTerminatedNotification, object: virtualMachine, userInfo: ["wizardID": self.wizardID])
					}
				}

				try await startInDFUMode(virtualMachine)

				// Bail early if cancelled while the VM was starting.
				try Task.checkCancellation()

				progressHandler(.step(String(localized: "Installing macOS from IPSW…")))

				let backend = AppleMobileDeviceRestoreBackend()
				let driver = try DeviceRestoreDriver(ecid: ecid, bundleURL: url, backend: backend, runMode: self.runMode)
				let context = ProgressObserver.ProgressHandlerContext()

				// VIMDDeviceRestore is a blocking C call with no abort API that can
				// run for many minutes. A dedicated thread avoids tying up a thread
				// from GCD's global pool for the entire restore duration.
				// Stopping the VM removes the DFU device from AMRestore's view,
				// which causes the blocking call to return with an error.
				do {
					try await withTaskCancellationHandler(
						operation: {
							try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
								let thread = Thread {
									let didResume: Mutex<Bool> = .init(false)

									@Sendable func resumeOnce(_ result: Result<Void, Error>) {
										let shouldResume = didResume.withLock { resumed -> Bool in
											guard !resumed else { return false }
											resumed = true
											return true
										}

										if shouldResume {
											continuation.resume(with: result)
										}
									}

									do {
										try driver.start { state in
											let fraction = state.overallProgress ?? state.progress

											progressHandler(.progress(context, fraction))

											switch state.outcome {
											case .success:
												resumeOnce(.success(()))
											case .failure(let error):
												resumeOnce(.failure(error ?? ServiceError(String(localized: "Failed to install IPSW"))))
											case .none:
												break
											}
										}
									} catch {
										resumeOnce(.failure(error))
									}
								}

								thread.name = "com.aldunelabs.caker.amrestore"
								thread.qualityOfService = .userInitiated
								thread.start()
							}
						},
						onCancel: {
							virtualMachine.virtualMachine.stop { _ in }
						}
					)
				} catch {
					if Task.isCancelled {
						throw CancellationError()
					}
					throw error
				}
			}
		#endif

		// MARK: - Public entry point

		public func installIPSW(_ url: URL, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] entering installIPSW")
			#endif

			progressHandler(.step(String(localized: "Installing macOS from IPSW…")))

			#if USE_VIRTUAL_INSTALL_BACKEND
				if #available(macOS 26.0, *), await shouldUseVirtualInstallBackend(url: url) {
					try await self.installViaAMRestore(url: url, progressHandler: progressHandler)
				} else if self.queue == nil {
					try await self.installIPSWSync(url, progressHandler: progressHandler)
				} else {
					try await self.installIPSWAsync(url, progressHandler: progressHandler)
				}
			#else
				if self.queue == nil {
					try await self.installIPSWSync(url, progressHandler: progressHandler)
				} else {
					try await self.installIPSWAsync(url, progressHandler: progressHandler)
				}
			#endif

			#if DEBUG
				self.logger.trace("[\(Thread.currentThread.description)] exiting installIPSW")
			#endif

			progressHandler(.step(String(localized: "Install macOS from IPSW done...")))
		}
	}
#endif
