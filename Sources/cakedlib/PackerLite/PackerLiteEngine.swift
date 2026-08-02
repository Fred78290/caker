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

	public enum PackerLiteEngine {
		public static func provision(
			location: VMLocation,
			config: CakeConfig,
			template: PackerLiteTemplate,
			runMode: Utils.RunMode,
			queue: DispatchQueue? = nil,
			progressHandler: @escaping ProgressObserver.BuildProgressHandler
		) async throws {
			let logger = Logger("PackerLiteEngine")
			let steps = try template.parsedBootCommand()

			progressHandler(.step(String(localized: "Provisioning macOS Setup Assistant…")))

			let vm = try await MainActor.run { () -> VirtualMachine in
				let vm = try VirtualMachine(location: location, config: config, display: .none, screenSize: config.display.cgSize, recoveryMode: false, runMode: runMode, queue: queue)

				vm.createVirtualMachineView()

				return vm
			}

			guard let view = vm.vzMachineView else {
				throw ServiceError(String(localized: "Failed to create VM view for provisioning"))
			}

			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				vm.startVM { result in
					switch result {
						case .success: continuation.resume()
						case .failure(let error): continuation.resume(throwing: error)
					}
				}
			}

			logger.info("VM \(location.name) started for provisioning, waiting \(template.resolvedCreateGraceTime)s before driving boot_command")

			try await Task.sleep(nanoseconds: UInt64(max(template.resolvedCreateGraceTime, 0) * 1_000_000_000))

			let driver = PackerLiteDriver(targetView: view)

			do {
				try await withThrowingTaskGroup(of: Void.self) { group in
					group.addTask {
						let context = ProgressObserver.ProgressHandlerContext()
						var count = 0

						progressHandler(.progress(context, 0))

						for stepList in steps {
							count += 1

							try await driver.run(steps: stepList)

							progressHandler(.progress(context, Double(count / steps.count)))
						}
					}

					group.addTask {
						try await Task.sleep(nanoseconds: UInt64(template.resolvedBootTimeout * 1_000_000_000))

						throw ServiceError(String(localized: "Provisioning timed out after \(Int(template.resolvedBootTimeout))s"))
					}

					try await group.next()
					group.cancelAll()
				}
			} catch {
				logger.error("Provisioning failed for VM \(location.name): \(error)")

				await shutdown(vm)

				throw error
			}

			progressHandler(.step(String(localized: "Provisioning finished, shutting down…")))

			await shutdown(vm)

			progressHandler(.step(String(localized: "Provisioning done")))
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
