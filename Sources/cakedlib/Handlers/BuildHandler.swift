import CakeAgentLib
import Dispatch
import Foundation
import GRPCLib
import NIOCore
import SwiftUI
import Synchronization
import Virtualization

public struct BuildHandler {
	private static func provision(_ options: BuildOptions, location: VMLocation, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws {
		let config = try location.config()
		let imageURL = URL(spaced: options.image)!

		if options.imageSource == .ipsw {
			// options.macosVersion is GRPCLib's MacOSVersion (kept separate so GRPCLib doesn't need to
			// depend on CakedLib) — bridge it to CakedLib's own MacOSVersion by raw value.
			let explicitMacOSVersion = options.macosVersion.flatMap { MacOSVersion(rawValue: $0.rawValue) }

			// wins, otherwise the resolved macOS version above picks a built-in template. Resolve
			// throws if neither works.
			let content = try PackerLiteTemplateResolver.resolve(explicitPath: options.provisionTemplate, explicitVersion: explicitMacOSVersion, ipswURL: imageURL)

			// The VM's account is already fully determined by --user/--password (see
			// `configuredUser`/`configuredPassword` above) — reuse it here instead of
			// letting the template declare its own, so there's exactly one source of truth.
			var variables = options.provisionVarsDict

			variables["username"] = config.configuredUser
			variables["password"] = config.configuredPassword ?? "admin"

			let template = try await PackerLiteTemplate.load(from: content, variables: variables)

			try await PackerLiteEngine.provision(id: options.identifier, location: location, config: config, template: template, runMode: runMode) { progress in
				// Don't produce a terminated message here, because the VM is still running after provisioning completes — the caller will produce a terminated message when the VM is stopped.
				if case .provisioned(_) = progress {
					return
				}

				progressHandler(progress.progressValue)
			}
		} else if options.imageSource == .iso {
			// An explicit --template always wins; otherwise falls back to a built-in template for
			// the distro auto-detected from the ISO filename/URL (see PackerLiteTemplateResolver).
			// Resolves to nil, not an error, for platforms with no PackerLite template — Ubuntu
			// (its own cloud-init/subiquity autoinstall handles this instead) or an unrecognized
			// distro — in which case no provisioning runs unless --template was given.
			let explicitTemplate = (options.provisionTemplate?.isEmpty == false) ? options.provisionTemplate : nil

			if let content = try PackerLiteTemplateResolver.resolveLinuxTemplate(explicitPath: explicitTemplate, imageURL: imageURL, desktop: config.osDesktop) {
				// The VM's account is already fully determined by --user/--password (see
				// `configuredUser`/`configuredPassword` above) — reuse it here instead of
				// letting the template declare its own, so there's exactly one source of truth.
				var variables = options.provisionVarsDict

				variables["username"] = config.configuredUser
				variables["password"] = config.configuredPassword ?? "admin"

				let template = try await PackerLiteTemplate.load(from: content, variables: variables)

				try await PackerLiteEngine.provision(id: options.identifier, location: location, config: config, template: template, runMode: runMode) { progress in
					// Don't produce a terminated message here, because the VM is still running after provisioning completes — the caller will produce a terminated message when the VM is stopped.
					if case .provisioned(_) = progress {
						return
					}

					progressHandler(progress.progressValue)
				}
			}
		}
	}

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

			let tempVMLocation: VMLocation = try VMLocation.tempDirectory(options.identifier, runMode: runMode)
			let location = storageLocation.location(options.name)

			// Lock the temporary VM directory to prevent it's garbage collection
			let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
			try tmpVMDirLock.lock()

			@Sendable func doCancel() {
				location.removePID()
				try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
			}

			try await withTaskCancellationHandler(
				operation: {
					do {
						let result = try await VMBuilder.buildVM(options.identifier, vmName: options.name, location: tempVMLocation, options: options, runMode: runMode, queue: queue, progressHandler: progressHandler)

						try storageLocation.relocate(options.name, from: tempVMLocation)

						if result.autoinstall && (result.imageSource == .ipsw || result.imageSource == .iso) {
							try await Task.sleep(nanoseconds: 2 * 100_000_000)

							try await provision(options, location: location, runMode: runMode, progressHandler: progressHandler)
						}

						progressHandler(.terminated(.success(location.rootURL), "Build VM finished successfully"))
					} catch {
						doCancel()

						progressHandler(.terminated(.failure(error), "Build VM failed"))

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
