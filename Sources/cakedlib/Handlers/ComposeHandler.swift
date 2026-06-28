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
	private static let builtinNetworks: Set<String> = ["nat", "default", "host", "none"]
	// MARK: - Up

	/// Provisions missing compose networks then starts or creates each service in depends_on order.
	/// `output` is called with each rendered result line as it is produced.
	public static func up(compose: inout ComposeFileDatabase.ComposeFileStatus, services: [String], waitIPTimeout: Int, runMode: Utils.RunMode) async -> ComposeReplyUp {
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
								return ComposeReplyUp(name: appName, success: false, reason: String(localized: "Compose failed to start \(serviceName), \(reply.reason)"))
							}
						} else {
							warning.append("VM \(vmName) not matched in compose name \(appName)")
						}
						
						continue
					}
				}

				var buildOpts = try serviceSpec.toBuildOptions(name: vmName)
				try buildOpts.options.validate(remote: false)

				defer {
					buildOpts.cleanup.forEach {
						try? $0.delete()
					}
				}

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
						warning.append("VM \(vmName) not matched in compose name \(appName)")
					}
				} else {
					warning.append("VM \(vmName) not found in compose name \(appName)")
				}
			}

			if vmToStop.isEmpty == false {
				let result = StopHandler.stopVMs(all: false, names: vmToStop, force: force, runMode: runMode)

				if Logger.LoggingLevel() > .info {
					print(Format.text.render(result.objects))
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

				if let location = try? storage.find(vmName), let config = try? location.config() {
					if compose.installed[serviceName]?.instanceIdentifier == config.instanceID {
						vmToDelete[vmName] = serviceName
					} else {
						warning.append("VM \(vmName) not matched in compose name \(appName)")
					}
				} else {
					warning.append("VM \(vmName) not found in compose name \(appName)")
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

	// MARK: - Private

	private static func provisionNetworks(compose: ComposeFile, runMode: Utils.RunMode) throws {
		guard let composeNetworks = compose.networks else { return }

		let home = try Home(runMode: runMode)
		let existingNetworks = try home.sharedNetworks()

		for (networkName, networkConfig) in composeNetworks.sorted(by: { $0.key < $1.key }) {
			guard let networkConfig else {
				continue
			}
			
			guard (networkConfig.external ?? false) == false else {
				continue
			}
			
			guard NetworksHandler.isPhysicalInterface(name: networkName) == false else {
				continue
			}
			
			guard networkConfig.driver == .bridge else {
				throw ServiceError(String(localized: "Only bridge driver is supported for network '\(networkName)'"))
			}
			
			guard builtinNetworks.contains(networkName) == false else {
				continue
			}

			guard existingNetworks.sharedNetworks[networkName] == nil else {
				continue
			}

			let network = networkConfig.composeNetworkSubnet(name: networkName)
			try network.validate(runMode: runMode)
			let result = NetworksHandler.create(networkName: networkName, network: network, runMode: runMode)

			if result.created == false {
				throw ServiceError(result.reason)
			}
		}
	}
}
