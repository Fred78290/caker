//
//  ProvisionHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/08/2026.
//

import CakeAgentLib
import Combine
import Foundation
import GRPCLib
import NIO
import Virtualization

public struct ProvisionHandler {
	public struct ProvisionInfo: Sendable {
		public let vncURL: URL
		public let screenSize: ViewSize
		public let config: CakeConfig

		public var caked: Caked_ProvisionStreamReply.ProvisionInfo {
			.with {
				$0.vncURL = vncURL.absoluteString
				$0.config = config.caked
				$0.screenSize = .with {
					$0.width = Int32(screenSize.width)
					$0.height = Int32(screenSize.height)
				}
			}
		}
	}

	public enum ProgressValue: Sendable {
		case progress(ProgressObserver.ProgressHandlerContext, Double)
		case step(String)
		case substep(String)
		case infos(ProvisionInfo)
		case provisioned(ProvisionedReply)

		public var progressValue: ProgressObserver.ProgressValue {
			switch self {
			case .progress(let context, let value):
				return .progress(context, value)
			case .step(let value):
				return .step(value)
			case .substep(let value):
				return .substep(value)
			case .infos(let value):
				return .substep(String(localized: "VNC started on \(value.vncURL.absoluteString)"))
			case .provisioned(let provisioned):
				if provisioned.provisioned {
					return .terminated(.success(provisioned), nil)
				} else {
					return .terminated(.failure(ServiceError(provisioned.reason)), nil)
				}
			}
		}
	}

	public typealias ProvisionProgressHandler = (ProvisionHandler.ProgressValue) -> Void

	private final class ProvisionTask: Cancellable, VirtualMachineDelegate, @unchecked Sendable {
		private var task: Task<Void, Error>? = nil
		private var lastStatus: VMLocation.Status
		private let handler: (_ runningIP: String) async -> Void

		private weak var chained: VirtualMachineDelegate?
		private weak var vm :VirtualMachine!
		
		deinit {
			self.vm.delegate = self.chained
		}

		init(vm: VirtualMachine, _ handler: @escaping (_ runningIP: String) async -> Void) {
			self.chained = vm.delegate
			self.handler = handler
			self.lastStatus = vm.status
			self.vm = vm

			vm.delegate = self
		}

		func start(runningIP: String) {
			self.task = Task.detached {
				await self.handler(runningIP)

				self.vm.delegate = self.chained
				self.task = nil
			}
		}

		func cancel() {
			task?.cancel()
			task = nil
		}

		func didChangedState(_ vm: VirtualMachine) {
			self.chained?.didChangedState(vm)

			let newStatus = vm.status

			if let task = self.task, newStatus.isRunning == false && newStatus != self.lastStatus {
				self.lastStatus = newStatus
				task.cancel()
			}
		}
		
		func didScreenshot(_ vm: VirtualMachine, screenshot: NSImage) {
			self.chained?.didScreenshot(vm, screenshot: screenshot)
		}
		
	}

	@MainActor
	public static func provision(
		location: VMLocation,
		storageLocation: StorageLocation,
		display: VMRunHandler.DisplayMode,
		templatePath: URL?,
		macosVersion: MacOSVersion?,
		variables: [String],
		runMode: Utils.RunMode,
		queue: DispatchQueue?,
		promise: EventLoopPromise<Void>?,
		progressHandler: @escaping ProvisionProgressHandler
	) async throws -> (VMRunHandler, VirtualMachine, Cancellable) {
		let config = try location.config()
		let displaySize = config.display.cgSize
		let vncPassword = config.vncPassword ?? UUID().uuidString

		if location.status.isRunning {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		guard config.source == .ipsw || config.source == .iso else {
			throw ServiceError(String(localized: "Provisioning is only supported for macOS VMs or Linux VMs from iso"))
		}

		guard config.provisioned == false else {
			throw ServiceError(String(localized: "The VM is already provisioned"))
		}

		// Load earlier to avoid starting the VM if the template is invalid
		let template = try Self.loadTemplate(location, template: templatePath?.path(percentEncoded: false), macosVersion: macosVersion, variables: variables)

		let handler = VMRunHandler(
			mode: .default,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: display,
			config: config,
			screenSize: displaySize,
			vncPassword: vncPassword,
			vncPort: 0,
			recoveryMode: false,
			provisioning: true,
			runMode: .app)

		return try handler.run { address, vm in
			let logger = Logger(ProvisionHandler.self)

			let targetView: NSView

			// Start VNC server as soon as the VM is up
			if display == .none {
				targetView = vm.createVirtualMachineView()
				vm.setupWindow()
			} else {
				let vncURL = try vm.startVncServer(vncPassword: vncPassword, port: 0)
				logger.info("VNC server started for provisioning VM \(location.name) at \(vncURL.map(\.absoluteString).joined(separator: ", "))")

				guard let vzMachineView = vm.vzMachineView else {
					throw ServiceError(String(localized: "Unable to get VZMachineView for VM \(location.name)"))
				}

				guard let vncURL = vncURL.first else {
					throw ServiceError(String(localized: "Unable to get VNC URL for VM \(location.name)"))
				}

				targetView = vzMachineView

				progressHandler(.infos(.init(vncURL: vncURL, screenSize: .init(vzMachineView.bounds.size), config: config)))
			}

			// Preboot command execution (if any) before starting the provisioning task
			if template.preBootCommand.isEmpty == false {
				DispatchQueue.main.async {
					Task.detached {
						try await PackerLiteEngine.provision(
							vm: vm,
							targetView: targetView,
							commands: template.preBootCommand,
							resolvedBootTimeout: template.bootTimeout,
							progressHandler: progressHandler)
					}
				}
			}

			func destroyVM(_ error: Error?) {
				if display == .all || display == .vnc {
					vm.stopVncServer()
				}

				// Don't rely on didChangedState(true) -> stopGrandCentralUpdate() firing here: that
				// chain only runs from inside _stopVM's completion handler, itself gated on
				// virtualMachine.state == .running at the exact moment terminateVM's cancellation
				// unwinds -- a real timing window (e.g. cancellation racing VM startup) where it's
				// skipped entirely, leaking the VirtualMachine <-> GrandCentralUpdater cycle same as
				// before that fix. Call it directly here, same as stopVncServer() above, so teardown
				// doesn't depend on internal VM-state timing.
				vm.stopGrandCentralUpdate()

				MainActor.assumeIsolated {
					vm.disposeWindow()
				}

				vm.terminateVM { _ in
					if let error {
						progressHandler(.provisioned(ProvisionedReply(name: location.name, provisioned: false, reason: String(localized: "Provisioning failed for VM \(location.name), error: \(error.reason)"))))
					} else {
						progressHandler(.provisioned(ProvisionedReply(name: location.name, provisioned: true, reason: String(localized: "Provisioning success for VM \(location.name)"))))
					}

					if let promise {
						if let error {
							promise.fail(error)
						} else {
							promise.succeed()
						}
					}
				}
			}

			let task = ProvisionTask(vm: vm) { runningIP in
				var catchableError: Error? = nil

				defer {
					destroyVM(catchableError)
				}

				do {
					try await PackerLiteEngine.provision(
						vm: vm,
						template: template,
						runningIP: runningIP,
						runMode: runMode,
						progressHandler: progressHandler
					)
				} catch {
					catchableError = error
					logger.error("Provisioning failed for VM \(location.name): \(error)")
				}
			}

			// Start provisioning when we have an address (if any)
			address.whenSuccess { ip in
				if let ip {
					logger.info("VM Machine \(location.name) is now available at \(ip)")

					task.start(runningIP: ip)
				} else {
					destroyVM(ServiceError(String(localized: "Unable to obtain an IP address for VM \(location.name)")))
				}
			}

			address.whenFailure { error in
				destroyVM(error)
			}

			return (handler, vm, task)
		}
	}

	public static func provision(
		location: VMLocation,
		storageLocation: StorageLocation,
		display: VMRunHandler.DisplayMode,
		templateName: String?,
		templateContent: String?,
		macosVersion: MacOSVersion?,
		variables: [String],
		runMode: Utils.RunMode,
		queue: DispatchQueue?,
		promise: EventLoopPromise<Void>?,
		progressHandler: @escaping ProvisionProgressHandler
	) async throws -> (VMRunHandler, VirtualMachine, Cancellable) {
		var templatePath: URL? = nil

		defer {
			try? templatePath?.delete()
		}

		if let templateContent, let templateName {
			// Write the provided template content to a file in the user's temporary directory
			let tempDir = NSTemporaryDirectory()
			let fullPath = URL(fileURLWithPath: (tempDir as NSString).appendingPathComponent(templateName))

			try templateContent.write(to: fullPath, atomically: true, encoding: .utf8)

			templatePath = fullPath
		}

		return try await self.provision(
			location: location,
			storageLocation: storageLocation,
			display: display,
			templatePath: templatePath,
			macosVersion: macosVersion,
			variables: variables,
			runMode: runMode,
			queue: queue,
			promise: promise,
			progressHandler: progressHandler
		)
	}

	public static func provision(
		name: String,
		display: VMRunHandler.DisplayMode,
		templateName: String,
		templateContent: String?,
		macosVersion: MacOSVersion?,
		variables: [String],
		runMode: Utils.RunMode,
		queue: DispatchQueue?,
		promise: EventLoopPromise<Void>?,
		progressHandler: @escaping ProvisionProgressHandler
	) async throws -> (VMRunHandler, VirtualMachine, Cancellable) {

		let storageLocation = StorageLocation(runMode: runMode)
		let location = try storageLocation.find(name)

		return try await self.provision(
			location: location,
			storageLocation: storageLocation,
			display: display,
			templateName: templateName,
			templateContent: templateContent,
			macosVersion: macosVersion,
			variables: variables,
			runMode: runMode,
			queue: queue,
			promise: promise,
			progressHandler: progressHandler)
	}

	private static func provision(_ vm: VirtualMachine, runningIP: String?, template: String?, macosVersion: MacOSVersion?, runMode: Utils.RunMode, variables: [String] = [], progressHandler: @escaping ProvisionProgressHandler)
		async throws
	{
		let parsedTemplate = try await Self.loadTemplate(vm.location, template: template, macosVersion: macosVersion, variables: variables)

		try await PackerLiteEngine.provision(vm: vm, template: parsedTemplate, runningIP: runningIP, runMode: runMode, progressHandler: progressHandler)
	}

	@MainActor
	public static func loadTemplate(_ location: VMLocation, template: String?, macosVersion: MacOSVersion?, variables: [String]) throws -> ParsedPackerLiteTemplate {
		let config = try location.config()
		let content: String

		if config.os == .darwin {
			// Prefer an explicit --macos-version override; otherwise fall back to whatever `build`
			// already detected and stored in config.osName (see VMBuilder.swift).
			let explicitMacOSVersion: MacOSVersion? =
				macosVersion.flatMap { MacOSVersion(rawValue: $0.rawValue) } ?? config.osName.flatMap { MacOSVersion(rawValue: $0) }

			// No real IPSW file at hand for an already-installed VM — filename-based detection is a
			// no-op here, so this resolves purely from --template / the version determined above.
			content = try PackerLiteTemplateResolver.resolve(
				explicitPath: template,
				explicitVersion: explicitMacOSVersion,
				ipswURL: URL(fileURLWithPath: "\(location.name).ipsw"))
		} else {
			// Falls back to a built-in template for the VM's stored platform (e.g. fedora, centos,
			// redhat, openSUSE, debian) when --template isn't given — validate() already refused to
			// get here for a platform with neither an explicit --template nor a built-in default.
			guard let resolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: template, platform: config.configuredPlatform, desktop: config.osDesktop) else {
				throw ServiceError(String(localized: "No built-in provisioning template for \(config.configuredPlatform.rawValue) — provide one with --template"))
			}

			content = resolved
		}

		// The VM's account is already fully determined by its stored configuredUser/configuredPassword
		// — reuse it here instead of letting the template declare its own, so there's exactly one
		// source of truth, same as the automatic build-time path.
		var varsDict = Dictionary(
			uniqueKeysWithValues: variables.compactMap { entry -> (String, String)? in
				guard let separatorIndex = entry.firstIndex(of: "=") else { return nil }

				let key = String(entry[..<separatorIndex])
				let value = String(entry[entry.index(after: separatorIndex)...])

				return (key, value)
			})

		varsDict["username"] = config.configuredUser
		varsDict["password"] = config.configuredPassword ?? "admin"

		return try PackerLiteTemplate.load(from: content, variables: varsDict)
	}
}
