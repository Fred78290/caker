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
			throw ServiceError(String(format: String(localized: "Unknown catalog image id '%@'. Run 'caked aliases' or 'cakectl aliases' to see the known ids, or pass an explicit image URL instead."), imageId))
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
		} else if options.image.contains("debian") && self.user == "admin" {
			throw ServiceError(String(localized: "Debian 12+ ISO images no longer allow the default user 'admin'. Please use '--user <username>' to specify a different username."))
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

			let imageSource = options.imageSource ?? .qcow2
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

			var cancelled = false

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
							// An explicit --template always wins; otherwise falls back to a built-in template for
							// the distro auto-detected from the ISO filename/URL (see PackerLiteTemplateResolver).
							// Resolves to nil, not an error, for platforms with no PackerLite template — Ubuntu
							// (its own cloud-init/subiquity autoinstall handles this instead) or an unrecognized
							// distro — in which case no provisioning runs unless --template was given.
							let config = try location.config()
							let imageURL = URL(spaced: result.image)!
							let explicitTemplate = (result.provisionTemplate?.isEmpty == false) ? result.provisionTemplate : nil

							if let content = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: explicitTemplate, imageURL: imageURL, desktop: config.osDesktop) {
								let template = try await PackerLiteTemplate.load(from: content, variables: result.setupVariables(config, runMode: runMode))

								try await Task.sleep(nanoseconds: 2 * 100_000_000)

								try await PackerLiteEngine.internalProvisionning(id: result.identifier, location: location, config: config, template: template, runMode: runMode) { progress in
									let progress = progress.progressValue

									if case .terminated(_, _) = progress {
										terminatedSent = true
									}

									progressHandler(progress)
								}
							} else {
								Logger(self).info("No PackerLite template found for \(imageURL.lastPathComponent), skipping provisioning")
							}
						}

						progressHandler(.terminated(.success(location.rootURL), "Build VM finished successfully"))
					} catch is CancellationError {
						doCancel()
						cancelled = true
						progressHandler(.terminated(.failure(CancellationError()), "Build VM cancelled"))
					} catch {
						doCancel()

						let nsError = error as NSError

						if nsError.domain == VZErrorDomain && nsError.code == VZError.operationCancelled.rawValue {
							cancelled = true
							progressHandler(.terminated(.failure(CancellationError()), "Build VM cancelled"))
						} else {
							if terminatedSent == false {
								progressHandler(.terminated(.failure(error), "Build VM failed"))
							}

							throw error
						}
					}
				},
				onCancel: {
					doCancel()
				})

			return BuildedReply(name: options.name, builded: cancelled == false, reason: cancelled ? String(localized: "Cancelled") : String(localized: "VM created"))
		} catch {
			return BuildedReply(name: options.name, builded: false, reason: error.reason)
		}
	}
}
