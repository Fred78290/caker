import ArgumentParser
import Combine
import CakedLib
import CakeAgentLib
import Foundation
import GRPCLib
import AppKit

/// Drives an already-installed macOS VM's Setup Assistant unattended via PackerLite — the same
/// engine `caked build`/`create` run automatically for `.ipsw` sources with `--autoinstall`, exposed
/// here as a standalone step for VMs that skipped it at build time (or need it re-run). Run directly
/// against `caked` on the host where the VM lives — not currently wired through gRPC/cakectl.
struct Provision: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "provision",
													abstract: String(localized: "Drive a macOS or Linux VM's Setup Assistant unattended via PackerLite"),
													discussion: String(localized: "Re-runs the same unattended Setup Assistant automation that `build`/`create` drive automatically for .ipsw or .iso sources with --autoinstall — for a VM that skipped it at build time. Uses the VM's stored macOS version and account credentials; fails if the VM is currently running, or has already been provisioned."))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(help: ArgumentHelp(String(localized: "Provisioning template (YAML) to use, overriding the VM's default built-in template (by stored macOS version or Linux platform); required if the VM's platform has no built-in template"), valueName: "path"))
	var template: String?

	@Option(name: [.customLong("macos-version")], help: ArgumentHelp(String(localized: "macOS version to use for picking the built-in template, overriding the VM's stored osName"), valueName: "version"))
	var macosVersion: GRPCLib.MacOSVersion?

	@Option(name: [.customLong("var")], help: ArgumentHelp(String(localized: "Set a provisioning template variable (key=value), may be repeated"), valueName: "key=value"))
	var vars: [String] = []

	@Argument(help: ArgumentHelp(String(localized: "Path to the VM disk.img or its name")))
	var path: String

	var locations: (StorageLocation, VMLocation) {
		if StorageLocation(runMode: self.common.runMode).exists(path) {
			let storageLocation = StorageLocation(runMode: self.common.runMode)
			let vm = try! storageLocation.find(path)

			return (storageLocation, vm)
		} else {
			let u: URL = URL(fileURLWithPath: path)
			let parent = u.deletingLastPathComponent()
			let storage = parent.deletingLastPathComponent()
			let storageLocation = StorageLocation(runMode: self.common.runMode, name: storage.lastPathComponent)
			let vm = VMLocation(rootURL: parent, template: storageLocation.template)

			return (storageLocation, vm)
		}
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let (_, location) = self.locations

		if location.inited == false {
			throw ValidationError(String(localized: "VM at \(path) does not exist"))
		}

		if case .running = location.status {
			throw ValidationError(String(localized: "VM at \(path) is running — stop it first"))
		}

		let config = try location.config()

		if config.os != .darwin {
			if let template = self.template {
				if FileManager.default.fileExists(atPath: template.expandingTildeInPath) == false {
					throw ValidationError(String(localized: "Provisioning template file does not exist: \(template)"))
				}
			} else if PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for: config.configuredPlatform) == false {
				throw ValidationError(String(localized: "No built-in provisioning template for \(config.configuredPlatform.rawValue) — provide one with --template"))
			}
		}

		if config.provisioned {
			throw ValidationError(String(localized: "VM at \(path) is already provisioned — Setup Assistant only runs on first boot, so running PackerLite again would just hang"))
		}
	}

	@MainActor
	func run() async throws {
		let (storageLocation, location) = self.locations
		let config = try location.config()
		let displaySize = config.display.cgSize

		if case .running = location.status {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		let runMode = self.common.runMode
		let handler = CakedLib.VMRunHandler(
			mode: .grpc,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: .ui,
			config: config,
			screenSize: displaySize,
			vncPassword: "",
			vncPort: 0,
			recoveryMode: false,
			runMode: runMode)

		struct DoProvision: Cancellable {
			let task: Task<Void, Error>

			func cancel() {
				task.cancel()
			}
		}

		try handler.run { address, vm in
			let logger = Logger(self)

			address.whenSuccess { ip in
				if let ip {
					logger.info("VM Machine \(location.name) is now available at \(ip)")
				}
				
				MainApp.cancellation = DoProvision(task: Task {
					defer {
						vm.stopVM { _ in
							DispatchQueue.main.async {
								NSApp.terminate(self)
							}
						}
					}

					do {
						try await provision(vm, runningIP: ip)
					} catch {
						logger.error("Provisioning failed for VM \(location.name): \(error)")
					}					
				})
			}

			vm.createVirtualMachineView()

			MainApp.runUI(vm, params: handler, cancellation: nil)
		}
	}

	private func provision(_ vm: VirtualMachine, runningIP: String?) async throws {
		let location = vm.location
		let config = vm.config
		let content: String

		if config.os == .darwin {
			// Prefer an explicit --macos-version override; otherwise fall back to whatever `build`
			// already detected and stored in config.osName (see VMBuilder.swift).
			let explicitMacOSVersion: CakedLib.MacOSVersion? =
				self.macosVersion.flatMap { CakedLib.MacOSVersion(rawValue: $0.rawValue) } ?? config.osName.flatMap { CakedLib.MacOSVersion(rawValue: $0) }

			// No real IPSW file at hand for an already-installed VM — filename-based detection is a
			// no-op here, so this resolves purely from --template / the version determined above.
			content = try PackerLiteTemplateResolver.resolve(
				explicitPath: self.template,
				explicitVersion: explicitMacOSVersion,
				ipswURL: URL(fileURLWithPath: "\(location.name).ipsw"))
		} else {
			// Falls back to a built-in template for the VM's stored platform (e.g. fedora, centos,
			// redhat, openSUSE, debian) when --template isn't given — validate() already refused to
			// get here for a platform with neither an explicit --template nor a built-in default.
			guard let resolved = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: self.template, platform: config.configuredPlatform) else {
				throw ServiceError(String(localized: "No built-in provisioning template for \(config.configuredPlatform.rawValue) — provide one with --template"))
			}

			content = resolved
		}

		// The VM's account is already fully determined by its stored configuredUser/configuredPassword
		// — reuse it here instead of letting the template declare its own, so there's exactly one
		// source of truth, same as the automatic build-time path.
		var variables = Dictionary(uniqueKeysWithValues: self.vars.compactMap { entry -> (String, String)? in
			guard let separatorIndex = entry.firstIndex(of: "=") else { return nil }

			let key = String(entry[..<separatorIndex])
			let value = String(entry[entry.index(after: separatorIndex)...])

			return (key, value)
		})

		variables["username"] = config.configuredUser
		variables["password"] = config.configuredPassword ?? "admin"

		let parsedTemplate = try PackerLiteTemplate.load(from: content, variables: variables)

		try await PackerLiteEngine.provision(vm: vm, template: parsedTemplate, runningIP: runningIP, runMode: self.common.runMode, progressHandler: ProgressObserver.progressHandler)
	}
}
