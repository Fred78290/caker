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
	public static func up(compose: ComposeFile, services: [String], waitIPTimeout: Int, runMode: Utils.RunMode) async -> ComposeReplyUp {

		do {
			try provisionNetworks(compose: compose, runMode: runMode)

			let toStart = try compose.startOrder(filter: services)

			for (serviceName, serviceSpec) in toStart {
				var buildOpts = try serviceSpec.toBuildOptions(name: serviceName)
				try buildOpts.validate(remote: false)

				let storage = StorageLocation(runMode: runMode)

				if storage.exists(serviceName) {
					let location = try storage.find(serviceName)
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
						return ComposeReplyUp(name: serviceName, success: false, reason: reply.reason)
					}
				} else {
					let reply = await LaunchHandler.buildAndLaunchVM(
						runMode: runMode,
						options: buildOpts,
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
						return ComposeReplyUp(name: serviceName, success: false, reason: reply.reason)
					}
				}
			}
			return ComposeReplyUp(name: compose.name, success: true, reason: "")
		} catch {
			return ComposeReplyUp(name: compose.name, success: false, reason: error.reason)
		}
	}

	// MARK: - Down

	/// Stops services in reverse depends_on order.
	public static func down(compose: ComposeFile, services: [String], force: Bool, runMode: Utils.RunMode) -> ComposeReplyDown {
		do {
			let toStop = try compose.downOrder(filter: services)

			for (serviceName, _) in toStop {
				let reply = StopHandler.stopVM(name: serviceName, force: force, runMode: runMode)

				if Logger.LoggingLevel() > .info {
					print(Format.text.render(reply))
				}
			}

			return ComposeReplyDown(name: compose.name, success: true, reason: "")
		} catch {
			return ComposeReplyDown(name: compose.name, success: false, reason: error.reason)
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
				let image = svc.image ?? "-"

				if let location = try? storage.find(serviceName) {
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
	public static func rm(compose: ComposeFile, services: [String], stop: Bool, force: Bool, runMode: Utils.RunMode) -> ComposeReplyDelete {
		do {
			let toRemove = try compose.downOrder(filter: services)

			for (serviceName, _) in toRemove {
				if stop {
					_ = StopHandler.stopVM(name: serviceName, force: force, runMode: runMode)
				}
				let result = DeleteHandler.delete(all: false, names: [serviceName], runMode: runMode)

				if Logger.LoggingLevel() > .info {
					print(Format.text.render(result.objects))
				}

				if result.success == false {
					return ComposeReplyDelete(name: serviceName, success: false, reason: result.reason)
				}
			}
		} catch {
			return ComposeReplyDelete(name: compose.name, success: false, reason: error.reason)
		}

		return ComposeReplyDelete(name: compose.name, success: true, reason: "")
	}

	// MARK: - List
	public static func list(database: ComposeFileDatabase, runMode: Utils.RunMode) -> ComposeReplyList {
		let storage = StorageLocation(runMode: runMode)
		var composeFiles: [ComposeReplyList.ComposeInfo] = []

		// Assuming database.files is a dictionary-like collection: [String: ComposeFile]
		for (fileName, app) in database.files {
			var services: [ComposeServiceInfo] = []

			// Assuming app.services is a dictionary-like collection: [String: ComposeFile]
			for (serviceName, compose) in app.services {
				let image = compose.image ?? "-"

				if let location = try? storage.find(serviceName) {
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
			guard let networkConfig else { continue }
			guard !networkConfig.external else { continue }
			guard !NetworksHandler.isPhysicalInterface(name: networkName) else { continue }
			guard networkConfig.driver == .bridge else {
				throw ServiceError(String(localized: "Only bridge driver is supported for network '\(networkName)'"))
			}
			guard !builtinNetworks.contains(networkName) else { continue }
			guard existingNetworks.sharedNetworks[networkName] == nil else { continue }

			let network = networkConfig.composeNetworkSubnet(name: networkName)
			try network.validate(runMode: runMode)
			let result = NetworksHandler.create(networkName: networkName, network: network, runMode: runMode)

			if result.created == false {
				throw ServiceError(result.reason)
			}
		}
	}
}
