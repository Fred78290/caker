import CakeAgentLib
import Dispatch
import Foundation
import GRPCLib
import NIOCore
import SwiftUI
import Synchronization
import Virtualization

extension BuildOptions {
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
