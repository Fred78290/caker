//
//  PackerLiteEngine.swift
//  CakedLib
//
//  Boots a freshly IPSW-installed macOS VM headlessly, drives its Setup Assistant
//  through a parsed PackerLiteTemplate boot_command, then shuts the VM back down —
//  the built-in equivalent of running `packer build` with packer-plugin-tart against
//  a freshly restored VM, minus the external binary/plugin.
//

#if arch(arm64)
	import CakeAgentLib
	import Foundation
	import GRPCLib
	import Virtualization
	import SwiftUI

	public enum PackerLiteEngine {
		#if DEBUG
			public static var provisioned: [UUID: VirtualMachine] = [:]
			public static let provisionedTerminatedNotification = NSNotification.Name("ProvisionedTerminatedNotification")
		#endif

		@MainActor
		private static func setupKeyMapper() throws {
			try newKeyMapper().setupKeyMapper()
		}

		public static func provision(
			vm: VirtualMachine,
			template: PackerLiteTemplate,
			runningIP: String?,
			runMode: Utils.RunMode,
			progressHandler: @escaping ProgressObserver.BuildProgressHandler
		) async throws {
			let location = vm.location
			let config = vm.config
			let logger = Logger("PackerLiteEngine")
			let steps = try template.parsedBootCommand()

			try await setupKeyMapper()

			progressHandler(.step(String(localized: "Provisioning macOS Setup Assistant…")))

			guard let view = vm.vzMachineView else {
				throw ServiceError(String(localized: "Failed to create VM view for provisioning"))
			}

			logger.info("VM \(location.name) started for provisioning")

			let driver = PackerLiteDriver(targetView: view)

			try await withThrowingTaskGroup(of: Void.self) { group in
				let grp = group
				let onCancel = {
					grp.cancelAll()
				}

				try await withTaskCancellationHandler(
					operation: {
						group.addTask {
							let context = ProgressObserver.ProgressHandlerContext()
							var count = 0

							progressHandler(.progress(context, 0))

							for stepList in steps {
								count += 1

								try await driver.run(steps: stepList)

								progressHandler(.progress(context, Double(count) / Double(steps.count)))
							}

							if let runningIP, runningIP.isEmpty == false {
								progressHandler(.step(String(localized: "Install agent…")))

								_ = try await location.installAgent(updateAgent: true, config: config, runningIP: runningIP, runMode: runMode)
							}
						}

						group.addTask {
							try await Task.sleep(nanoseconds: UInt64(template.resolvedBootTimeout * 1_000_000_000))

							throw ServiceError(String(localized: "Provisioning timed out after \(Int(template.resolvedBootTimeout))s"))
						}

						try await group.next()
						group.cancelAll()
					},
					onCancel: {
						onCancel()
					})
			}

			progressHandler(.step(String(localized: "Provisioning done")))

			config.provisioned = true
			try config.save()
		}

		public static func provision(
			location: VMLocation,
			config: CakeConfig,
			template: PackerLiteTemplate,
			runMode: Utils.RunMode,
			progressHandler: @escaping ProgressObserver.BuildProgressHandler
		) async throws {
			try await setupKeyMapper()

			progressHandler(.step(String(localized: "Provisioning macOS Setup Assistant…")))

			let vm = try await MainActor.run { () -> VirtualMachine in
				let vm = try VirtualMachine(location: location, config: config, display: .none, screenSize: config.display.cgSize, recoveryMode: false, runMode: runMode)

				vm.createVirtualMachineView()

				return vm
			}

			#if DEBUG
				let id = UUID()
				Self.provisioned[id] = vm

				defer {
					Self.provisioned.removeValue(forKey: id)
					NotificationCenter.default.post(name: self.provisionedTerminatedNotification, object: vm)
				}

				await MainActor.run {
					EnvironmentValues().openWindow(id: "Debug PackerLite", value: id)
				}
			#endif

			let runningIP = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
				vm.startVM { result in
					switch result {
					case .success:
						do {
							let runningIP = try location.waitIP(wait: 120, runMode: runMode)

							continuation.resume(returning: runningIP)
						} catch {
							continuation.resume(throwing: error)
						}
					case .failure(let error):
						continuation.resume(throwing: error)
					}
				}
			}

			do {
				try await Self.provision(vm: vm, template: template, runningIP: runningIP, runMode: runMode, progressHandler: progressHandler)
				await shutdown(vm)
			} catch {
				await shutdown(vm)
				throw error
			}
		}

		private static func shutdown(_ vm: VirtualMachine) async {
			await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
				vm.stopVM { _ in
					continuation.resume()
				}
			}
		}
	}
#endif
