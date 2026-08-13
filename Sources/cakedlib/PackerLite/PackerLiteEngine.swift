//
//  PackerLiteEngine.swift
//  CakedLib
//
//  Boots a freshly IPSW-installed macOS VM headlessly, drives its Setup Assistant
//  through a parsed PackerLiteTemplate boot_command, then shuts the VM back down —
//  the built-in equivalent of running `packer build` with packer-plugin-tart against
//  a freshly restored VM, minus the external binary/plugin.
//

import CakeAgentLib
import Foundation
import GRPCLib
import SwiftUI
import Virtualization

public enum PackerLiteEngine {
	public static var provisioned: [UUID: VirtualMachine] = [:]
	public static let provisionedStartNotification = NSNotification.Name("ProvisionedStartNotification")
	public static let provisionedTerminatedNotification = NSNotification.Name("ProvisionedTerminatedNotification")

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
		let commands = try await template.parsedBootCommand()

		progressHandler(.step(String(localized: "Provisioning macOS Setup Assistant…")))

		guard let view = vm.vzMachineView else {
			throw ServiceError(String(localized: "Failed to create VM view for provisioning"))
		}

		logger.info("VM \(location.name) started for provisioning")

		let driver = await PackerLiteDriver(targetView: view)

		try await withThrowingTaskGroup(of: Void.self) { group in
			let grp = group
			let onCancel = {
				grp.cancelAll()
			}

			try await withTaskCancellationHandler(
				operation: {
					group.addTask {
						let context = ProgressObserver.ProgressHandlerContext()

						progressHandler(.progress(context, 0))

						for (index, command) in commands.enumerated() {
							progressHandler(.substep(command.title))

							logger.info("Execute provionning command: \(command.title)")
							try await driver.run(command: command)

							progressHandler(.progress(context, Double(index) / Double(commands.count)))
						}

						if let runningIP, runningIP.isEmpty == false {
							progressHandler(.step(String(localized: "Install agent…")))

							_ = try await location.installAgent(updateAgent: true, config: config, runningIP: runningIP, runMode: runMode)
							config.agent = true
							try config.save()
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
		id: UUID,
		location: VMLocation,
		config: CakeConfig,
		template: PackerLiteTemplate,
		runMode: Utils.RunMode,
		progressHandler: @escaping ProgressObserver.BuildProgressHandler
	) async throws {
		let runInCaker = Bundle.runInCaker

		progressHandler(.step(String(localized: "Provisioning macOS Setup Assistant…")))

		let vm = try await MainActor.run { () -> VirtualMachine in
			let vm = try VirtualMachine(location: location, config: config, display: runInCaker ? .ui : .none, screenSize: config.display.cgSize, recoveryMode: false, runMode: runMode)

			vm.createVirtualMachineView()

			return vm
		}

		let runningIP = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
			vm.startVM { result in
				switch result {
				case .success:
					do {
						let runningIP = try location.waitIP(config: config, wait: 120, runMode: runMode)

						continuation.resume(returning: runningIP)
					} catch {
						continuation.resume(throwing: error)
					}
				case .failure(let error):
					continuation.resume(throwing: error)
				}
			}
		}

		if runInCaker {
			Self.provisioned[id] = vm

			await MainActor.run {
				NotificationCenter.default.post(name: self.provisionedStartNotification, object: vm, userInfo: ["wizardID": id])
			}
		}

		defer {
			if runInCaker {
				Self.provisioned.removeValue(forKey: id)

				DispatchQueue.main.async {
					NotificationCenter.default.post(name: self.provisionedTerminatedNotification, object: vm, userInfo: ["wizardID": id])
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
