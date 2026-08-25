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
		targetView: NSView,
		commands: BootCommandSteps,
		resolvedBootTimeout: TimeInterval,
		progressHandler: @escaping ProvisionHandler.ProvisionProgressHandler
	) async throws {
		let logger = Logger("PackerLiteEngine")
		let driver = await PackerLiteDriver(targetView: targetView)

		try await withThrowingTaskGroup(of: Void.self) { group in
			let context = ProgressObserver.ProgressHandlerContext()

			group.addTask {
				progressHandler(.progress(context, 0))
				for (index, command) in commands.enumerated() {
					progressHandler(.substep(command.title))
					logger.info("Execute provionning command: \(command.title)")
					try await driver.run(command: command)
					progressHandler(.progress(context, Double(index + 1) / Double(commands.count)))
					try Task.checkCancellation()
				}
			}

			group.addTask {
				try await Task.sleep(nanoseconds: UInt64(resolvedBootTimeout * 1_000_000_000))
				throw ServiceError(String(localized: "Provisioning timed out after \(Int(resolvedBootTimeout))s"))
			}

			do {
				// Wait for the first task to complete (either work or timeout).
				try await group.next()
			} catch {
				// Cancel remaining tasks on error (timeout or command failure).
				group.cancelAll()
				throw error
			}

			group.cancelAll()
		}
	}

	public static func provision(
		vm: VirtualMachine,
		template: ParsedPackerLiteTemplate,
		runningIP: String?,
		runMode: Utils.RunMode,
		progressHandler: @escaping ProvisionHandler.ProvisionProgressHandler
	) async throws {
		let location = vm.location
		let config = vm.config
		let logger = Logger("PackerLiteEngine")
		let commands = template.bootCommand
		var runningIP = runningIP

		progressHandler(.step(String(localized: "Provisioning macOS Setup Assistant…")))

		guard let view = vm.vzMachineView else {
			throw ServiceError(String(localized: "Failed to create VM view for provisioning"))
		}

		logger.info("VM \(location.name) started for provisioning")

		try await Self.provision(
			targetView: view,
			commands: commands,
			resolvedBootTimeout: template.bootTimeout,
			progressHandler: progressHandler)

		if runningIP == nil {
			runningIP = try location.waitIPWithLease(config: config, wait: 180, runMode: runMode)
		}

		if let runningIP, runningIP.isEmpty == false {
			progressHandler(.step(String(localized: "Install agent…")))

			_ = try await location.installAgent(updateAgent: true, config: config, runningIP: runningIP, timeout: 30, runMode: runMode)
			config.agent = true
		}

		progressHandler(.step(String(localized: "Provisioning done")))

		config.provisioned = true
		try config.save()
	}

	public static func provision(
		id: UUID,
		location: VMLocation,
		config: CakeConfig,
		template: ParsedPackerLiteTemplate,
		runMode: Utils.RunMode,
		progressHandler: @escaping ProvisionHandler.ProvisionProgressHandler
	) async throws {
		let runInCaker = Bundle.runInCaker
		let logger = Logger(self)

		progressHandler(.step(String(localized: "Provisioning macOS Setup Assistant…")))

		let vm = try await MainActor.run { () -> VirtualMachine in
			let vncPassword = config.vncPassword ?? UUID().uuidString
			let vm = try VirtualMachine(
				location: location,
				config: config,
				display: runInCaker ? .ui : .vnc,
				screenSize: config.display.cgSize,
				recoveryMode: false,
				provisioning: true,
				runMode: runMode)

			if runInCaker {
				vm.createVirtualMachineView()
				progressHandler(.infos(nil))
			} else {
				let vncURL = try vm.startVncServer(vncPassword: vncPassword, port: 0)

				logger.info("VNC server started for provisioning VM \(location.name) at \(vncURL.map(\.absoluteString).joined(separator: ", "))")

				guard let vzMachineView = vm.vzMachineView else {
					throw ServiceError(String(localized: "Unable to get VZMachineView for VM \(location.name)"))
				}

				guard let vncURL = vncURL.first else {
					throw ServiceError(String(localized: "Unable to get VNC URL for VM \(location.name)"))
				}

				progressHandler(.infos(.init(vncURL: vncURL, screenSize: .init(vzMachineView.bounds.size), config: CakedConfiguration(config))))
			}

			return vm
		}

		if runInCaker {
			Self.provisioned[id] = vm

			await MainActor.run {
				NotificationCenter.default.post(name: self.provisionedStartNotification, object: vm, userInfo: ["wizardID": id])
			}
		}

		try await vm.startVM()

		try location.writePID()

		FileManager.default.createFile(atPath: location.provisionningURL.path(percentEncoded: false), contents: nil)

		guard let view = vm.vzMachineView else {
			throw ServiceError(String(localized: "Failed to create VM view for provisioning"))
		}

		func destroyVM(_ error: Error?) async {
			if let error {
				logger.error("Provisioning failed for VM \(location.name), error: \(error.localizedDescription)")
			} else {
				logger.debug("Provisioning success for VM \(location.name)")
			}

			vm.stopVncServer()

			await MainActor.run {
				vm.disposeWindow()
			}

			await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
				vm.stopVM { _ in
					location.removePID()

					if let error {
						progressHandler(.provisioned(ProvisionedReply(name: location.name, provisioned: false, reason: String(localized: "Provisioning failed for VM \(location.name), error: \(error.reason)"))))
					} else {
						progressHandler(.provisioned(ProvisionedReply(name: location.name, provisioned: true, reason: String(localized: "Provisioning success for VM \(location.name)"))))
					}
					
					continuation.resume()
				}
			}

			if runInCaker {
				if Self.provisioned.removeValue(forKey: id) != nil {
					DispatchQueue.main.async {
						NotificationCenter.default.post(name: self.provisionedTerminatedNotification, object: vm, userInfo: ["wizardID": id])
					}
				}
			}
		}

		do {
			// Preboot for linux
			if template.preBootCommand.isEmpty == false {
				try await Self.provision(
					targetView: view,
					commands: template.preBootCommand,
					resolvedBootTimeout: template.bootTimeout,
					progressHandler: progressHandler)
			}

			let runningIP = try location.waitIPWithLease(config: config, wait: 180, runMode: runMode)

			try await Self.provision(vm: vm, template: template, runningIP: runningIP, runMode: runMode, progressHandler: progressHandler)
			await destroyVM(nil)
		} catch {
			await destroyVM(error)
			throw error
		}
	}
}
