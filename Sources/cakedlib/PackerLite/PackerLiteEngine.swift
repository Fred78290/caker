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
		targetVirtualMachine: VirtualMachine,
		commands: BootCommandSteps,
		resolvedBootTimeout: TimeInterval,
		progressHandler: @escaping ProvisionHandler.ProvisionProgressHandler
	) async throws {
		let logger = Logger("PackerLiteEngine")
		let driver = await PackerLiteDriver(targetVirtualMachine: targetVirtualMachine)

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
		waitIPTimeout: Int = 180,
		progressHandler: @escaping ProvisionHandler.ProvisionProgressHandler
	) async throws {
		let location = vm.location
		let config = vm.config
		let logger = Logger("PackerLiteEngine")
		let commands = template.bootCommand
		var runningIP = runningIP

		progressHandler(.step(String(localized: "Provisioning Virtual Machine Setup Assistant…")))

		guard vm.vzMachineView != nil else {
			throw ServiceError(String(localized: "Failed to create VM view for provisioning"))
		}

		logger.info("VM \(location.name) started for provisioning")

		try await Self.provision(
			targetVirtualMachine: vm,
			commands: commands,
			resolvedBootTimeout: template.bootTimeout,
			progressHandler: progressHandler)

		if runningIP == nil {
			progressHandler(.step(String(localized: "Wait IP address…")))

			runningIP = try location.waitIPWithLease(config: config, wait: waitIPTimeout, runMode: runMode)
			
			if let ip = runningIP {
				logger.info("VM \(location.name) is now available at \(ip) after provisioning")
			} else {
				logger.error(String(localized: "Unable to obtain an IP address for VM \(location.name) after provisioning"))
			}
		}

		if let runningIP, runningIP.isEmpty == false, (template.installAgent ?? true) {
			progressHandler(.step(String(localized: "Install agent…")))

			_ = try await location.installAgent(updateAgent: true, config: config, runningIP: runningIP, timeout: 30, runMode: runMode)
			config.agent = true
		}

		if let runningIP, runningIP.isEmpty == false, let postBootCommand = template.postBootCommand, postBootCommand.commands.isEmpty == false {
			progressHandler(.step(String(localized: "Running post-boot commands…")))

			try await location.executePostBootCommand(postBootCommand, config: config, runningIP: runningIP, runMode: runMode)
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
		var activationPolicy : NSApplication.ActivationPolicy = .prohibited

		if runInCaker == false {
			let app = await NSApplication.shared
			
			activationPolicy = await app.activationPolicy()
			await app.setActivationPolicy(.prohibited)
		}

		progressHandler(.step(String(localized: "Provisioning Virtual Machine Setup Assistant…")))

		let vm = try await MainActor.run { () -> VirtualMachine in
			let vncPassword = config.vncPassword ?? UUID().uuidString
			let vm = try VirtualMachine(
				location: location,
				config: config,
				display: runInCaker ? .ui : .vnc,
				screenSize: config.display.cgSize,
				mode: .provisioning,
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

		guard vm.vzMachineView != nil else {
			throw ServiceError(String(localized: "Failed to create VM view for provisioning"))
		}

		func destroyVM(_ error: Error?) async {
			vm.stopVncServer()

			await MainActor.run {
				vm.disposeWindow()
			}

			await vm.finishProvisioningVideo(success: error == nil)

			await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
				vm.stopVM { _ in
					location.removePID()

					if let error {
						let reason: String

						if let videoURL = location.existingProvisioningVideoURL {
							reason = String(localized: "Provisioning failed for VM \(location.name), error: \(error.reason). Debug recording saved to \(videoURL.path)")
						} else {
							reason = String(localized: "Provisioning failed for VM \(location.name), error: \(error.reason)")
						}

						logger.error(reason)

						progressHandler(.provisioned(ProvisionedReply(name: location.name, provisioned: false, reason: reason)))
					} else {
						logger.info("Provisioning success for VM \(location.name)")

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
			} else {
				await NSApplication.shared.setActivationPolicy(activationPolicy)
			}
		}

		do {
			// Preboot for linux
			if template.preBootCommand.isEmpty == false {
				try await Self.provision(
					targetVirtualMachine: vm,
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
