//
//  ComposeHandler.swift
//  CakedLib
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import Foundation
import GRPCLib

public struct ComposeHandler {
	private static let builtinNetworks: Set<String> = ["nat", "default", "host", "none"]

	// MARK: - Up

	/// Provisions missing compose networks then starts or creates each service in depends_on order.
	/// `output` is called with each rendered result line as it is produced.
	public static func up(
		compose: ComposeFile,
		services: [String],
		waitIPTimeout: Int,
		format: Format,
		runMode: Utils.RunMode,
		output: @escaping (String) -> Void
	) async throws {
		try provisionNetworks(compose: compose, format: format, runMode: runMode, output: output)

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
				output(format.render(reply))
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
				output(format.render(reply))
			}
		}
	}

	// MARK: - Down

	/// Stops services in reverse depends_on order.
	public static func down(
		compose: ComposeFile,
		services: [String],
		force: Bool,
		format: Format,
		runMode: Utils.RunMode,
		output: (String) -> Void
	) throws {
		let toStop = try compose.downOrder(filter: services)
		for (serviceName, _) in toStop {
			let reply = StopHandler.stopVM(name: serviceName, force: force, runMode: runMode)
			output(format.render([reply]))
		}
	}

	// MARK: - Ps

	/// Lists provisioned status of each service (tab-separated: name, status, image).
	public static func ps(
		compose: ComposeFile,
		services: [String],
		runMode: Utils.RunMode,
		output: (String) -> Void
	) throws {
		let resolved = compose.resolvedServices(filter: services)
		let storage = StorageLocation(runMode: runMode)
		for (serviceName, svc) in resolved {
			let status = storage.exists(serviceName) ? "provisioned" : "not found"
			let image = svc.image ?? "-"
			output("\(serviceName)\t\(status)\t\(image)")
		}
	}

	// MARK: - Rm

	/// Removes services in reverse depends_on order, optionally stopping them first.
	public static func rm(
		compose: ComposeFile,
		services: [String],
		stop: Bool,
		force: Bool,
		format: Format,
		runMode: Utils.RunMode,
		output: (String) -> Void
	) throws {
		let toRemove = try compose.downOrder(filter: services)
		for (serviceName, _) in toRemove {
			if stop {
				_ = StopHandler.stopVM(name: serviceName, force: true, runMode: runMode)
			}
			let result = DeleteHandler.delete(all: false, names: [serviceName], runMode: runMode)
			if result.success {
				output(format.render(result.objects))
			} else if !force {
				output(format.render(result.reason))
			}
		}
	}

	// MARK: - Private

	private static func provisionNetworks(
		compose: ComposeFile,
		format: Format,
		runMode: Utils.RunMode,
		output: (String) -> Void
	) throws {
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
			output(format.render(result))
		}
	}
}
