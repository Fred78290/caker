import AppKit
import ArgumentParser
import CakeAgentLib
import CakedLib
import Combine
import Foundation
import GRPCLib

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

		try self.provision.mergeProvisionVars(provisionVars: ProvisionVariablesStore.load())

		if config.provisioned {
			throw ValidationError(String(localized: "VM at \(self.provision.name) is already provisioned — Setup Assistant only runs on first boot, so running PackerLite again would just hang"))
		}
	}

	@MainActor
	func run() async throws {
		let (storageLocation, location) = self.locations
		let logger = Logger(self)
		let config = try location.config()
		var templatePath: URL? = nil

		if location.status.isRunning {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		guard config.source == .ipsw || config.source == .iso else {
			throw ServiceError(String(localized: "Provisioning is only supported for macOS VMs or Linux VMs from iso"))
		}

		guard config.provisioned == false else {
			throw ServiceError(String(localized: "The VM is already provisioned"))
		}

		if let template = self.provision.template {
			templatePath = URL(fileURLWithPath: template.expandingTildeInPath)
		}

		// Load earlier to avoid starting the VM if the template is invalid
		let template = try CakedLib.ProvisionHandler.loadTemplate(
			location, template: templatePath?.path(percentEncoded: false),
			macosVersion: self.provision.macosVersion, variables: self.provision.vars, runMode: self.common.runMode)

		defer {
			location.removePID()
		}

		let promise = Utilities.group.next().makePromise(of: Void.self)

		do {
			FileManager.default.createFile(atPath: location.provisionningURL.path(percentEncoded: false), contents: nil)

			let (handler, vm, cancellation) = try await CakedLib.ProvisionHandler.provision(
				location: location,
				storageLocation: storageLocation,
				display: self.provision.foreground ? .all : .vnc,
				template: template,
				runMode: self.common.runMode,
				queue: ProvisionHandler.provisionQueue,
				promise: promise
			) {
				let progress = $0.progressValue

				switch progress {
				case .progress:
					// Silent
					break
				default:
					ProgressObserver.progressHandler($0.progressValue)
				}
			}

			// caked's default top-level SIGINT handler (Root.sigintSrc) just force-exits the process —
			// fine for most commands, but here Ctrl-C is the documented way to stop-and-save, so it
			// needs to run our own teardown first. Same cancel-then-install-our-own pattern Exec/Sh
			// already use for their own interactive needs (see Sources/caked/Commands/Exec.swift).
			Root.sigintSrc.cancel()
			signal(SIGINT, SIG_IGN)

			let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)

			sigintSrc.setEventHandler {
				cancellation.cancel()
			}

			sigintSrc.activate()

			// Check also manual launch
			var gcdTask: Task<Void, Never>? = nil

			if ServiceHandler.isAgentRunning.running {
				logger.info("Start GCD for VM: \(location.name)")

				gcdTask = Task {
					do {
						try await vm.startGrandCentralUpdate(frequency: 1, runMode: self.common.runMode)
					} catch is CancellationError {
						// Expected on teardown
					} catch {
						logger.error("Failed to start GCD for VM: \(location.name), error: \(error.localizedDescription)")
					}
				}
			}

			promise.futureResult.whenComplete { result in
				if let gcdTask {
					vm.stopGrandCentralUpdate()
					gcdTask.cancel()
				}

				if case .failure(let error) = result, error as? CancellationError == nil {
					logger.error("Provisioning failed: \(error.localizedDescription)")
				}

				location.removePID()

				DispatchQueue.main.async {
					NSApplication.shared.terminate(self)
				}
			}

			if self.provision.foreground {
				MainApp.runUI(vm, params: handler, cancellation: cancellation)
			} else {
				NSApplication.shared.setActivationPolicy(.prohibited)
				NSApplication.shared.run()
			}
		} catch {
			promise.fail(error)
			throw error
		}
	}
}
