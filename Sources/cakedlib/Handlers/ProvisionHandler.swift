import CakeAgentLib
import Combine
//
//  ProvisionHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/08/2026.
//
import Foundation
import GRPCLib
import NIO
import Virtualization

public struct ProvisionHandler {
	private final class ProvisionTask: Cancellable, @unchecked Sendable {
		private var task: Task<Void, Error>? = nil
		private let handler: (_ runningIP: String) async -> Void

		init(_ handler: @escaping (_ runningIP: String) async -> Void) {
			self.handler = handler
		}

		func start(runningIP: String) {
			self.task = Task.detached {
				await self.handler(runningIP)
			}
		}

		func cancel() {
			task?.cancel()
			task = nil
		}
	}

	@MainActor
	public static func provision(
		location: VMLocation,
		storageLocation: StorageLocation,
		foreground: Bool,
		templatePath: URL?,
		macosVersion: MacOSVersion?,
		variables: [String],
		runMode: Utils.RunMode,
		queue: DispatchQueue?,
		promise: EventLoopPromise<Void>?,
		progressHandler: @escaping ProgressObserver.BuildProgressHandler
	) async throws -> (VMRunHandler, VirtualMachine, Cancellable) {
		let config = try location.config()
		let displaySize = config.display.cgSize
		let vncPassword = config.vncPassword ?? UUID().uuidString

		if case .running = location.status {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		let handler = VMRunHandler(
			mode: .grpc,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: foreground ? .all : .vnc,
			config: config,
			screenSize: displaySize,
			vncPassword: "",
			vncPort: 0,
			recoveryMode: false,
			runMode: runMode)

		return try handler.run { address, vm in
			let logger = Logger(ProvisionHandler.self)

			// Start VNC server as soon as the VM is up
			let vncURL = try vm.startVncServer(vncPassword: vncPassword, port: 0)
			logger.info("VNC server started at \(vncURL.map(\.absoluteString).joined(separator: ", "))")

			let task = ProvisionTask { runningIP in
				var catchableError: Error? = nil

				defer {
					vm.stopFromUI { _ in
						if let catchableError {
							progressHandler(.terminated(.failure(catchableError), String(localized: "Provisioning failed for VM \(location.name)")))
						} else {
							progressHandler(.terminated(.success(location.name), String(localized: "Provisioning success for VM \(location.name)")))
						}

						if let promise {
							if let catchableError {
								promise.fail(catchableError)
							} else {
								promise.succeed()
							}
						}
					}
				}

				do {
					defer {
						if let templatePath, templatePath.path(percentEncoded: false).starts(with: NSTemporaryDirectory()) {
							try? FileManager.default.removeItem(at: templatePath)
						}
					}

					try await Self.provision(
						vm,
						runningIP: runningIP,
						template: templatePath?.path(percentEncoded: false),
						macosVersion: macosVersion,
						runMode: runMode,
						variables: variables,
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
				}
			}


			return (handler, vm, task)
		}
	}

	public static func provision(
		location: VMLocation,
		storageLocation: StorageLocation,
		foreground: Bool,
		templateName: String?,
		templateContent: String?,
		macosVersion: MacOSVersion?,
		variables: [String],
		runMode: Utils.RunMode,
		queue: DispatchQueue?,
		promise: EventLoopPromise<Void>?,
		progressHandler: @escaping ProgressObserver.BuildProgressHandler
	) async throws -> (VMRunHandler, VirtualMachine, Cancellable) {
		var templatePath: URL? = nil

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
			foreground: foreground,
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
		foreground: Bool,
		templateName: String,
		templateContent: String?,
		macosVersion: MacOSVersion?,
		variables: [String],
		runMode: Utils.RunMode,
		queue: DispatchQueue?,
		promise: EventLoopPromise<Void>?,
		progressHandler: @escaping ProgressObserver.BuildProgressHandler
	) async throws -> (VMRunHandler, VirtualMachine, Cancellable) {

		let storageLocation = StorageLocation(runMode: runMode)
		let location = try storageLocation.find(name)

		return try await self.provision(
			location: location,
			storageLocation: storageLocation,
			foreground: foreground,
			templateName: templateName,
			templateContent: templateContent,
			macosVersion: macosVersion,
			variables: variables,
			runMode: runMode,
			queue: queue,
			promise: promise,
			progressHandler: progressHandler)
	}

	private static func provision(_ vm: VirtualMachine, runningIP: String?, template: String?, macosVersion: MacOSVersion?, runMode: Utils.RunMode, variables: [String] = [], progressHandler: @escaping ProgressObserver.BuildProgressHandler)
		async throws
	{
		let location = vm.location
		let config = vm.config
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

		let parsedTemplate = try PackerLiteTemplate.load(from: content, variables: varsDict)

		try await PackerLiteEngine.provision(vm: vm, template: parsedTemplate, runningIP: runningIP, runMode: runMode, progressHandler: progressHandler)
	}

}
