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
	static let configuration = ProvisionOptions.configuration

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Provisioning options"))
	var provision: ProvisionOptions

	var locations: (StorageLocation, VMLocation) {
		let path = self.provision.name

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
			throw ValidationError(String(localized: "VM at \(self.provision.name) does not exist"))
		}

		if case .running = location.status {
			throw ValidationError(String(localized: "VM at \(self.provision.name) is running — stop it first"))
		}

		let config = try location.config()

		if config.os != .darwin {
			if let template = self.provision.template {
				if FileManager.default.fileExists(atPath: template.expandingTildeInPath) == false {
					throw ValidationError(String(localized: "Provisioning template file does not exist: \(template)"))
				}
			} else if PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for: config.configuredPlatform) == false {
				throw ValidationError(String(localized: "No built-in provisioning template for \(config.configuredPlatform.rawValue) — provide one with --template"))
			}
		}

		if config.provisioned {
			throw ValidationError(String(localized: "VM at \(self.provision.name) is already provisioned — Setup Assistant only runs on first boot, so running PackerLite again would just hang"))
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

		if let template = self.provision.template {
			templatePath = URL(fileURLWithPath: template.expandingTildeInPath)
		}

		defer {
			location.removePID()
		}

		let (handler, vm, cancellation) = try await CakedLib.ProvisionHandler.provision(location: location,
																						storageLocation: storageLocation,
																						foreground: self.provision.foreground,
																						templatePath: templatePath,
																						macosVersion: self.provision.macosVersion,
																						variables: self.provision.vars,
																						runMode: self.common.runMode,
																						queue: ProvisionHandler.provisionQueue,
																						promise: promise) {
			ProgressObserver.progressHandler($0.progressValue)
		}

		if self.provision.foreground {
			MainApp.runUI(vm, params: handler, cancellation: cancellation)
		} else {
			NSApplication.shared.setActivationPolicy(.prohibited)
			NSApplication.shared.run()
		}
	}
}
