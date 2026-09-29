//
//  ComposeHandler.swift
//  CakedLib
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import CakeAgentLib
import Foundation
import GRPCLib

public struct ComposeHandler {
	// "default" is deliberately not in this set — see `provisionNetworks` below, it now needs to
	// resolve/validate to caker's own default bridged interface rather than being skipped outright.
	private static let builtinNetworks: Set<String> = ["nat", "host", "none"]
	// MARK: - Up

	/// Provisions missing compose networks then starts or creates each service in depends_on order.
	/// `output` is called with each rendered result line as it is produced.
	///
	/// `changedServices` names services whose definition just changed but whose VM already exists: `up` only
	/// ever *starts* such a VM (its hardware, disk, network and cloud-init are fixed when it is built), so each
	/// gets a warning saying the edit did not take effect rather than silently doing nothing.
	public static func up(compose: inout ComposeFileDatabase.ComposeFileStatus, services: [String], waitIPTimeout: Int, changedServices: Set<String> = [], runMode: Utils.RunMode) async -> ComposeReplyUp {
		let appName = compose.composeFile.name
		let storage = StorageLocation(runMode: runMode)
		var warning: [String] = []

		do {
			try provisionNetworks(compose: compose.composeFile, runMode: runMode)

			let toStart = try compose.composeFile.startOrder(filter: services)

			for (serviceName, serviceSpec) in toStart {
				let vmName = "compose-\(appName)-\(serviceName)"

				// Check if already installed
				if let installed = compose.installed[serviceName] {
					// Find associated VM
					if let location = try? storage.find(vmName), let config = try? location.config() {

						// Check if owned by compose
						if installed.instanceIdentifier == config.instanceID {
							let reply = StartHandler.startVM(
								location: location,
								screenSize: nil,
								vncPassword: nil,
								vncPort: nil,
								waitIPTimeout: waitIPTimeout,
								startMode: .background,
								gcd: false,
								recoveryMode: false,
								runMode: runMode
							)
							
							if Logger.LoggingLevel() > .info {
								print(Format.text.render(reply))
							}
							
							if reply.started == false {
								return ComposeReplyUp(name: appName, success: false, reason: String(format: String(localized: "Compose failed to start %@, %@"), serviceName, reply.reason))
							}

							if changedServices.contains(serviceName) {
								warning.append(String(format: String(localized: "Service %@ changed in the compose file, but its VM %@ already exists: it was only started, not rebuilt. Remove it (compose rm) and run compose up again to apply the change."), serviceName, vmName))
							}
						} else {
							warning.append(String(format: String(localized: "VM %@ not matched in compose name %@"), vmName, appName))
						}

						continue
					}
				}

				var buildOpts = try serviceSpec.toBuildOptions(name: vmName, composeNetworks: compose.composeFile.networks)

				// Registered before `validate(remote:)` can throw: `toBuildOptions` has already written the
				// cloud-init user-data file by now (which can carry `environment:` secrets), and a `defer`
				// placed after the throwing call would leak it in the temporary directory on that path.
				defer {
					buildOpts.cleanup.forEach {
						try? $0.delete()
					}
				}

				try buildOpts.options.validate(remote: false)

				let vmExistedBeforeBuild = storage.exists(vmName)
				let reply = await LaunchHandler.buildAndLaunchVM(
					runMode: runMode,
					options: buildOpts.options,
					waitIPTimeout: waitIPTimeout,
					startMode: .background,
					gcd: false,
					recoveryMode: false,
					progressHandler: ProgressObserver.progressHandler
				)

				if Logger.LoggingLevel() > .info {
					print(Format.text.render(reply))
				}

				if reply.launched == false {
					// `buildAndLaunchVM` reports `launched: false` both when the build failed and when the VM
					// was built fine but could not be *started* (e.g. no IP within `waitIPTimeout`). In the
					// second case the VM now exists on disk: if it isn't recorded as this project's, the next
					// `up` skips the "already installed" branch, tries to build the same name again and fails
					// with "VM already exists" forever, while `down`/`rm` (which only act on recorded VMs)
					// can't clean it up either. Only adopt a VM this call created — never one that was
					// already there (a name clash with someone else's VM makes the same call fail too).
					if vmExistedBeforeBuild == false, let location = try? storage.find(vmName), let config = try? location.config() {
						compose.installed[serviceName] = ComposeFileDatabase.ServiceStatus(createdAt: Date(), instanceIdentifier: config.instanceID)
					}

					return ComposeReplyUp(name: appName, success: false, reason: reply.reason)
				} else {
					let location = try storage.find(vmName)
					let config = try location.config()
					
					compose.installed[serviceName] = ComposeFileDatabase.ServiceStatus(createdAt: Date(), instanceIdentifier: config.instanceID)
				}
			}

			return ComposeReplyUp(name: appName, success: true, reason: String(warning.joined(by: "\n")))
		} catch {
			return ComposeReplyUp(name: appName, success: false, reason: error.reason)
		}
	}

	/// `up` against the project registry: picks the entry to run against (`statusForUp`), runs it, and
	/// persists whatever was launched — even on partial failure, so the next `up` doesn't try to re-create
	/// VMs that now exist. The single implementation behind `caked compose up`, the daemon's `Up` RPC and
	/// the app's local mode, which used to each carry their own copy of this sequence.
	///
	/// `replaceDefinition` is `true` for a definition the user authored (a compose file, the editor's
	/// "Save & Start") and `false` for the lossy reconstruction behind the app's "Start" action — see
	/// `statusForUp`. Replacing it is what lets `up` *build* a service added since the project was first
	/// registered; before, the registered definition was kept unconditionally, so it never knew about it.
	public static func up(database: ComposeFileDatabase, compose: ComposeFile, replaceDefinition: Bool, services: [String], waitIPTimeout: Int, runMode: Utils.RunMode) async throws -> ComposeReplyUp {
		let previous = replaceDefinition ? database.get(compose.name) : nil
		var status = statusForUp(database: database, compose: compose, replaceDefinition: replaceDefinition)
		let storage = StorageLocation(runMode: runMode)

		var notes: [String] = []
		var changed: Set<String> = []

		if let previous {
			changed = changedServices(previous: previous.composeFile, current: status.composeFile, installed: status.installed)

			// A service dropped from the file keeps its VM and its record, but `down`/`rm`/`ps` only walk the
			// current definition, so from now on they can't reach it: say so, once, instead of leaving it
			// running unmentioned.
			for serviceName in status.installed.keys.sorted() where status.composeFile.services[serviceName] == nil {
				let vmName = "compose-\(compose.name)-\(serviceName)"

				if storage.exists(vmName) {
					notes.append(String(format: String(localized: "Service %@ is no longer defined in the compose file: its VM %@ was left untouched."), serviceName, vmName))
				}
			}
		}

		var reply = await self.up(compose: &status, services: services, waitIPTimeout: waitIPTimeout, changedServices: changed, runMode: runMode)

		if reply.success || status.installed.isEmpty == false {
			try database.upsert(compose.name, status)
		}

		if notes.isEmpty == false {
			reply.reason = ([reply.reason] + notes).filter { $0.isEmpty == false }.joined(separator: "\n")
		}

		return reply
	}

	/// Services already built (`installed`) that `current` still defines but whose definition differs from
	/// `previous`. Compared through sorted-key JSON: `ComposeService` isn't `Equatable`, and its
	/// dictionary-valued fields (`environment`, `networks`…) don't encode in a stable order otherwise.
	static func changedServices(previous: ComposeFile, current: ComposeFile, installed: [String: ComposeFileDatabase.ServiceStatus]) -> Set<String> {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]

		return Set(
			installed.keys.filter { name in
				guard let before = previous.services[name], let after = current.services[name] else {
					return false
				}

				guard let lhs = try? encoder.encode(before), let rhs = try? encoder.encode(after) else {
					return false
				}

				return lhs != rhs
			})
	}

	// MARK: - Down

	/// Stops services in reverse depends_on order.
	public static func down(compose: ComposeFileDatabase.ComposeFileStatus, services: [String], force: Bool, runMode: Utils.RunMode) -> ComposeReplyDown {
		let appName = compose.composeFile.name
		var warning: [String] = []

		do {
			let toStop = try compose.composeFile.downOrder(filter: services)
			let storage = StorageLocation(runMode: runMode)
			var vmToStop: [String] = []

			for (serviceName, _) in toStop {
				let vmName = "compose-\(appName)-\(serviceName)"

				if let location = try? storage.find(vmName), let config = try? location.config() {
					if compose.installed[serviceName]?.instanceIdentifier == config.instanceID {
						vmToStop.append(vmName)
					} else {
						warning.append(String(format: String(localized: "VM %@ not matched in compose name %@"), vmName, appName))
					}
				} else {
					warning.append(String(format: String(localized: "VM %@ not found in compose name %@"), vmName, appName))
				}
			}

			if vmToStop.isEmpty == false {
				let result = StopHandler.stopVMs(all: false, names: vmToStop, force: force, runMode: runMode)

				if Logger.LoggingLevel() > .info {
					print(Format.text.render(result.objects))
				}

				if result.success == false {
					return ComposeReplyDown(name: appName, success: false, reason: result.reason)
				}

				// `stopVMs` succeeds as a call even when an individual VM refused to stop (still
				// provisioning, owned by the Caker app, `stopVirtualMachine` throwing…): that is only
				// visible in its per-VM results, so `down` used to report success — and the GUI "Stop"
				// action a clean stop — while services were still running.
				let failures = Self.stopFailures(in: result.objects) { name in
					(try? storage.find(name))?.status.isRunning ?? false
				}

				if failures.isEmpty == false {
					let reasons = failures.map { String(format: String(localized: "Failed to stop VM %@, %@"), $0.name, $0.reason) }

					return ComposeReplyDown(name: appName, success: false, reason: reasons.joined(separator: "\n"))
				}
			}

			return ComposeReplyDown(name: appName, success: true, reason: String(warning.joined(by: "\n")))
		} catch {
			return ComposeReplyDown(name: appName, success: false, reason: error.reason)
		}
	}

	// MARK: - Ps

	/// Lists provisioned status of each service (tab-separated: name, status, image).
	public static func ps(compose: ComposeFile, services: [String], runMode: Utils.RunMode) -> ComposeReplyPs {
		do {
			let resolved = try compose.resolvedServices(filter: services)
			let storage = StorageLocation(runMode: runMode)
			var serviceInfos: [ComposeServiceInfo] = []

			for (serviceName, svc) in resolved {
				let vmName = "compose-\(compose.name)-\(serviceName)"
				let image = svc.image ?? "-"

				if let location = try? storage.find(vmName) {
					serviceInfos.append(ComposeServiceInfo(name: serviceName, image: image, status: "provisioned", running: location.status.isRunning))
				} else {
					serviceInfos.append(ComposeServiceInfo(name: serviceName, image: image, status: "not found", running: false))
				}
			}

			return ComposeReplyPs(name: compose.name, services: serviceInfos, success: true, reason: "")
		} catch {
			return ComposeReplyPs(name: compose.name, services: [], success: false, reason: error.reason)
		}
	}

	// MARK: - Rm

	/// Removes services in reverse depends_on order, optionally stopping them first.
	public static func rm(compose: inout ComposeFileDatabase.ComposeFileStatus, services: [String], stop: Bool, force: Bool, runMode: Utils.RunMode) -> ComposeReplyDelete {
		let appName = compose.composeFile.name
		var warning: [String] = []

		do {
			let toRemove = try compose.composeFile.downOrder(filter: services)
			let storage = StorageLocation(runMode: runMode)
			var vmToDelete: [String:String] = [:]

			for (serviceName, _) in toRemove {
				let vmName = "compose-\(appName)-\(serviceName)"

				// A record whose VM no longer exists (deleted by hand, or replaced by a different VM that
				// now holds the name) is stale: pruned here, because `installed` only ever shrinks when a
				// delete succeeds — a project with one such leftover would never become empty, so `rm`
				// could never unregister it and it would stay listed forever.
				guard let location = try? storage.find(vmName) else {
					warning.append(String(format: String(localized: "VM %@ not found in compose name %@"), vmName, appName))
					compose.installed[serviceName] = nil
					continue
				}

				// Config unreadable: can't tell whose VM this is, so the record is kept.
				guard let config = try? location.config() else {
					warning.append(String(format: String(localized: "VM %@ not matched in compose name %@"), vmName, appName))
					continue
				}

				if compose.installed[serviceName]?.instanceIdentifier == config.instanceID {
					vmToDelete[vmName] = serviceName
				} else {
					warning.append(String(format: String(localized: "VM %@ not matched in compose name %@"), vmName, appName))
					compose.installed[serviceName] = nil
				}
			}
			
			if vmToDelete.isEmpty == false {
				if stop {
					let result = StopHandler.stopVMs(all: false, names: vmToDelete.map { $0.key }, force: force, runMode: runMode)

					if Logger.LoggingLevel() > .info {
						print(Format.text.render(result.objects))
					}
				}

				let result = DeleteHandler.delete(all: false, names: vmToDelete.map { $0.key }, runMode: runMode)

				result.objects.forEach {
					if $0.deleted, let serviceName = vmToDelete[$0.name] {
						compose.installed[serviceName] = nil
					}
				}

				if Logger.LoggingLevel() > .info {
					print(Format.text.render(result.objects))
				}

				if result.success == false {
					return ComposeReplyDelete(name: appName, success: false, reason: result.reason)
				}

				// `delete(all:names:)` succeeds as a call even when a VM was left in place — a running
				// one without `--stop` reports `deleted: false, "VM is running"` — which is only visible
				// per object: without this `rm` claimed success while deleting nothing.
				let notDeleted = result.objects.filter { $0.deleted == false }

				if notDeleted.isEmpty == false {
					let reasons = notDeleted.map { String(format: String(localized: "Failed to delete VM %@, %@"), $0.name, $0.reason) }

					return ComposeReplyDelete(name: appName, success: false, reason: reasons.joined(separator: "\n"))
				}
			}
		} catch {
			return ComposeReplyDelete(name: appName, success: false, reason: error.reason)
		}

		return ComposeReplyDelete(name: appName, success: true, reason: String(warning.joined(by: "\n")))
	}

	// MARK: - List
	public static func list(database: ComposeFileDatabase, runMode: Utils.RunMode) -> ComposeReplyList {
		let storage = StorageLocation(runMode: runMode)
		var composeFiles: [ComposeReplyList.ComposeInfo] = []

		// Assuming database.files is a dictionary-like collection: [String: ComposeFile]
		for (fileName, app) in database.applications {
			var services: [ComposeServiceInfo] = []
			let appName = app.composeFile.name

			// Assuming app.services is a dictionary-like collection: [String: ComposeFile]
			for (serviceName, compose) in app.composeFile.services {
				let image = compose.image ?? "-"
				let vmName = "compose-\(appName)-\(serviceName)"

				if let location = try? storage.find(vmName) {
					services.append(ComposeServiceInfo(name: serviceName, image: image, status: "provisioned", running: location.status.isRunning))
				} else {
					services.append(ComposeServiceInfo(name: serviceName, image: image, status: "not found", running: false))
				}
			}

			composeFiles.append(ComposeReplyList.ComposeInfo(name: fileName, services: services))
		}

		return ComposeReplyList(composeFiles: composeFiles, success: true, reason: "")
	}

	// MARK: - Helpers

	/// The registry entry `up` should run against for `compose`: a fresh one for an unregistered
	/// project, otherwise the registered one — keeping its `installed` bookkeeping either way.
	///
	/// `replaceDefinition` decides whether a registered project also takes on `compose`'s definition.
	/// It must be `false` for a caller whose `compose` is only the *lossy* reconstruction the registry
	/// can offer (`ComposeReplyList.ComposeInfo.reconstructedComposeFile()`: names and images, nothing
	/// else) — the GUI's "Start" action — because replacing the stored definition with it would
	/// permanently drop every service's `depends_on`, ports, volumes, environment, packages… (and the
	/// next `up` would then build any missing service from that image-only stub, in alphabetical
	/// rather than dependency order).
	public static func statusForUp(database: ComposeFileDatabase, compose: ComposeFile, replaceDefinition: Bool) -> ComposeFileDatabase.ComposeFileStatus {
		guard var status = database.get(compose.name) else {
			return ComposeFileDatabase.ComposeFileStatus(composeFile: compose)
		}

		if replaceDefinition {
			status.composeFile = compose
		}

		return status
	}

	/// The VMs `StopHandler.stopVMs` could not stop: reported as not stopped **and** still running
	/// afterwards (`isRunning` looks that up by VM name). A VM that merely wasn't running — reported
	/// as not stopped too — is not a failure.
	static func stopFailures(in objects: [StoppedObject], isRunning: (String) -> Bool) -> [StoppedObject] {
		objects.filter { $0.stopped == false && isRunning($0.name) }
	}

	// MARK: - Private

	/// Validates that every declared compose network actually resolves to something a VM can
	/// attach to. `driver: bridge` here always means a real bridged/physical network attachment
	/// (Apple's Virtualization.framework sense of "bridged"), never a caker-managed shared/hosted
	/// vmnet network — there is nothing to *create*: a physical interface, or caker's configured
	/// default bridged interface, either already exists on the host or it doesn't. Failing fast
	/// here, before any VM is built, replaces what used to be a silent no-op for the reserved
	/// `"default"` network name (and, for a non-builtin name, fabricating an unrelated caker
	/// "shared" vmnet network under that name instead) — either way the VM previously came up with
	/// no working network device for it at all, since nothing at attach time
	/// (`CakeConfig.collectNetworks`) ever resolves a bare compose network name to caker's default
	/// bridged interface; it only logs a warning and drops the device.
	private static func provisionNetworks(compose: ComposeFile, runMode: Utils.RunMode) throws {
		guard let composeNetworks = compose.networks else { return }

		for (networkName, networkConfig) in composeNetworks.sorted(by: { $0.key < $1.key }) {
			guard let networkConfig else {
				continue
			}

			guard (networkConfig.external ?? false) == false else {
				continue
			}

			guard builtinNetworks.contains(networkName) == false else {
				continue
			}

			guard networkConfig.driver == .bridge else {
				throw ServiceError(String(format: String(localized: "Only bridge driver is supported for network '%@'"), networkName))
			}

			let attachmentName = networkConfig.bridgedAttachmentName(networkKey: networkName)

			if attachmentName == "bridged" {
				guard CakedKeyConfig.bridgedNetwork.string() != nil else {
					throw ServiceError(String(format: String(localized: "Network '%@' resolves to the default bridged interface, but any bridged network is not configured"), networkName))
				}
			} else {
				guard NetworksHandler.isPhysicalInterface(name: attachmentName) else {
					throw ServiceError(String(format: String(localized: "Network '%@' must be bridged or a physical interface name (resolved to '%@', which was not found)"), networkName, attachmentName))
				}
			}
		}
	}
}
