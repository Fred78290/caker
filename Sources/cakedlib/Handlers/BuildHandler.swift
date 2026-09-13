import CakeAgentLib
import Dispatch
import Foundation
import GRPCLib
import NIOCore
import SwiftUI
import Synchronization
import Virtualization

extension BuildOptions {
	/// Resolves `options.imageId` (set by `--alias <id>`, e.g. `--alias macos12`, or decoded off
	/// the wire for a `cakectl` build — see `BuildOptions.imageId`'s doc comment) into an actual
	/// `options.image` URL/`options.imageSource`, overriding whatever `--image` argument default
	/// was already there. Must run before `options.image`/`options.imageSource` are first used,
	/// i.e. before `cloneImage`. A no-op when `imageId` isn't set.
	public func resolveImageId() throws -> BuildOptions {
		guard let imageId = self.imageId else {
			return self
		}

		guard let resolution = VMImageCatalog.shared.resolveShorthand(imageId) else {
			// Shouldn't normally happen — `--alias`'s ids are meant to come from this same
			// catalog (see `caked aliases`/`cakectl aliases`) — but `imageId` could arrive over
			// gRPC from a newer cakectl than this caked's catalog knows about, or the caller
			// could have typed an id by hand.
			throw ServiceError(String(localized: "Unknown catalog image id '\(imageId)'. Run 'caked aliases' or 'cakectl aliases' to see the known ids, or pass an explicit image URL instead."))
		}

		var options = self

		options.imageId = nil
		options.image = resolution.url
		options.imageSource = resolution.imageSource

		// Bonus synergy: a macOS id (e.g. "macos12") already matches a MacOSVersion raw value —
		// auto-populate macosVersion from it when the caller didn't already pass --macos-version
		// explicitly, so PackerLite template selection doesn't have to re-derive it from the
		// (now catalog-resolved) IPSW filename.
		if options.macosVersion == nil, let macosVersion = resolution.macosVersion {
			options.macosVersion = macosVersion
		}

		// Also raise cpu/memory to the catalog entry's own minimum — the wizard and web
		// UI already do this when an entry is picked there (see `VMImageEntry
		// .applyMinimumResources` in `Sources/caker/Views/VirtualMachineWizard.swift` and the
		// equivalent logic in `webui/src/pages/CreateInstanceModal.tsx`), this brings `--alias`
		// in line with them; never lowers a value the caller already set higher via
		// `--cpus`/`--memory`.
		options.cpu = max(options.cpu, resolution.minCPU)
		options.memory = max(options.memory, resolution.minMemoryMiB)

		if options.imageSource == .ipsw {
			options.diskSize = max(options.diskSize, 40)
		}

		return options
	}

	// The VM's account is already fully determined by --user/--password (see
	// `configuredUser`/`configuredPassword` above) — reuse it here instead of
	// letting the template declare its own, so there's exactly one source of truth.
	public func setupVariables(_ config: VirtualMachineConfiguration, runMode: Utils.RunMode) -> [String: String] {
		var variables = self.provisionVarsDict

		variables["username"] = config.configuredUser
		variables["password"] = config.configuredPassword ?? "admin"
		
		if variables["hostname"] == nil {
			variables["hostname"] = self.name
		}

		if let keys = try? CloudInit.sshAuthorizedKeys(sshAuthorizedKeyPath: self.sshAuthorizedKey, runMode: runMode) {
			variables["ssh_authorized_key"] = keys.joined(separator: "\n")
		}

		return variables
	}
}

public struct BuildHandler {
	public static func build(options: BuildOptions, runMode: Utils.RunMode, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> BuildedReply {
		if options.name.count > URL.maxVirtualMachineNameLength {
			return BuildedReply(name: options.name, builded: false, reason: String(localized: "Virtual machine name \(options.name) is limited to \(URL.maxVirtualMachineNameLength) characters"))
		}

		do {
			let storageLocation = StorageLocation(runMode: runMode)

			if storageLocation.exists(options.name) {
				return BuildedReply(name: options.name, builded: false, reason: String(localized: "VM already exists"))
			}

			if options.bridgedNetwork {
				guard CakedKeyConfig.bridgedNetwork.string() != nil else {
					return BuildedReply(name: options.name, builded: false, reason: String(localized: "Any bridged network is not configured"))
				}
			}

			let imageSource = options.imageSource!
			let directLocation = imageSource == .ipsw && Bundle.runInCaker == false
			let location = storageLocation.location(options.name)
			let tempVMLocation = directLocation ? location : try VMLocation.tempDirectory(options.identifier, runMode: runMode)
			let tmpVMDirLock: FileLock?

			if directLocation {
				try FileManager.default.createDirectory(at: tempVMLocation.rootURL, withIntermediateDirectories: true)
				tmpVMDirLock = nil
			} else {
				tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
			}

			try tmpVMDirLock?.lock()

			@Sendable func doCancel() {
				location.removePID()
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			}

			try await withTaskCancellationHandler(
				operation: {
					var terminatedSent = false

					do {
						let result = try await VMBuilder.buildVM(options.identifier, vmName: options.name, location: tempVMLocation, options: options, runMode: runMode, queue: queue) { progress in
							if case .terminated(_, _) = progress {
								terminatedSent = true
							}

							progressHandler(progress)
						}

						if directLocation == false {
							try storageLocation.relocate(options.name, from: tempVMLocation)
						}

						if result.autoinstall && result.imageSource == .iso {
							try await Task.sleep(nanoseconds: 2 * 100_000_000)

							// An explicit --template always wins; otherwise falls back to a built-in template for
							// the distro auto-detected from the ISO filename/URL (see PackerLiteTemplateResolver).
							// Resolves to nil, not an error, for platforms with no PackerLite template — Ubuntu
							// (its own cloud-init/subiquity autoinstall handles this instead) or an unrecognized
							// distro — in which case no provisioning runs unless --template was given.
							let config = try location.config()
							let imageURL = URL(spaced: options.image)!
							let explicitTemplate = (options.provisionTemplate?.isEmpty == false) ? options.provisionTemplate : nil

							if let content = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: explicitTemplate, imageURL: imageURL, desktop: config.osDesktop) {
								let template = try await PackerLiteTemplate.load(from: content, variables: options.setupVariables(config, runMode: runMode))

								try await PackerLiteEngine.provision(id: options.identifier, location: location, config: config, template: template, runMode: runMode) { progress in
									let progress = progress.progressValue

									if case .terminated(_, _) = progress {
										terminatedSent = true
									}

									progressHandler(progress)
								}
							}
						}

						progressHandler(.terminated(.success(location.rootURL), "Build VM finished successfully"))
					} catch {
						doCancel()

						if terminatedSent == false {
							progressHandler(.terminated(.failure(error), "Build VM failed"))
						}

						throw error
					}
				},
				onCancel: {
					doCancel()
				})
			return BuildedReply(name: options.name, builded: true, reason: String(localized: "VM created"))
		} catch {
			return BuildedReply(name: options.name, builded: false, reason: error.reason)
		}
	}
}
