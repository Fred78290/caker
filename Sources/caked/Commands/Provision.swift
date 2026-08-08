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
/// against `caked` on the host where the VM lives.
struct Provision: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "provision",
													abstract: String(localized: "Drive a macOS or Linux VM's Setup Assistant unattended via PackerLite"),
													discussion: String(localized: "Re-runs the same unattended Setup Assistant automation that `build`/`create` drive automatically for .ipsw or .iso sources with --autoinstall — for a VM that skipped it at build time. Uses the VM's stored macOS version and account credentials; fails if the VM is currently running, or has already been provisioned."))

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(help: ArgumentHelp(String(localized: "Provisioning template (YAML) to use, overriding the VM's default built-in template (by stored macOS version or Linux platform); required if the VM's platform has no built-in template"), valueName: "path"))
	var template: String?

	@Option(name: [.customLong("macos-version")], help: ArgumentHelp(String(localized: "macOS version to use for picking the built-in template, overriding the VM's stored osName"), valueName: "version"))
	var macosVersion: MacOSVersion?

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
		var templatePath: URL? = nil

		if case .running = location.status {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		let promise = Utilities.group.next().makePromise(of: Void.self)

		promise.futureResult.whenComplete { _ in
			DispatchQueue.main.async {
				NSApp.terminate(self)
			}
		}

		if let template = self.template {
			templatePath = URL(fileURLWithPath: template.expandingTildeInPath)
		}

		let (handler, vm, cancellation) = try await CakedLib.ProvisionHandler.provision(location: location,
																						storageLocation: storageLocation,
																						display: .all,
																						templatePath: templatePath,
																						macosVersion: self.macosVersion,
																						variables: self.vars,
																						runMode: self.common.runMode,
																						queue: ProvisionHandler.provisionQueue,
																						promise: promise,
																						progressHandler: ProgressObserver.progressHandler)

		MainApp.runUI(vm, params: handler, cancellation: cancellation)
	}
}
