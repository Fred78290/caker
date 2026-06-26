//
//  Compose.swift
//  caked
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib

// MARK: - Parent command

struct Compose: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "compose",
		abstract: String(localized: "Manage VMs from a compose.yml file"),
		discussion: String(localized: "Reads compose.yml (or docker-compose.yml) and manages VMs as services."),
		subcommands: [ComposeUp.self, ComposeDown.self, ComposePs.self, ComposeRm.self, ComposeInit.self]
	)
}

// MARK: - Up
struct ComposeUp: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "up",
		abstract: String(localized: "Create and start services"),
		discussion: String(localized: "Starts services defined in compose.yml in depends_on order. Creates VMs that do not yet exist.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Option(
		help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout: Int = 180

	@Argument(help: ArgumentHelp(String(localized: "Services to start (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() async throws {
		let compose = try loadCompose()
		let toStart = try compose.startOrder(filter: services)

		// Provision missing networks before starting services
		if let composeNetworks = compose.networks {
			let home = try Home(runMode: common.runMode)
			let existingNetworks = try home.sharedNetworks()
			let builtins: Set<String> = ["nat", "default", "host", "none"]

			for (networkName, networkConfig) in composeNetworks.sorted(by: { $0.key < $1.key }) {
				guard let networkConfig else { continue }
				guard networkConfig.external != true else { continue }
				guard !CakedLib.NetworksHandler.isPhysicalInterface(name: networkName) else { continue }

				guard networkConfig.driver == .bridge else { throw ServiceError(String(localized: "Only bridge driver is supported")) }
				guard !builtins.contains(networkName) else { continue }
				guard existingNetworks.sharedNetworks[networkName] == nil else { continue }

				let network = networkConfig.composeNetworkSubnet(name: networkName)
				
				try network.validate(runMode: common.runMode)

				let result = CakedLib.NetworksHandler.create(networkName: networkName, network: network, runMode: common.runMode)

				Logger.appendNewLine(common.format.render(result))
			}
		}

		for (serviceName, serviceSpec) in toStart {
			var buildOpts = try serviceSpec.toBuildOptions(name: serviceName)
			try buildOpts.validate(remote: false)

			let storage = StorageLocation(runMode: common.runMode)

			if storage.exists(serviceName) {
				let location = try storage.find(serviceName)
				let reply = CakedLib.StartHandler.startVM(
					location: location,
					screenSize: nil,
					vncPassword: nil,
					vncPort: nil,
					waitIPTimeout: waitIPTimeout,
					startMode: .background,
					gcd: false,
					recoveryMode: false,
					runMode: common.runMode
				)
				Logger.appendNewLine(common.format.render(reply))
			} else {
				let reply = await CakedLib.LaunchHandler.buildAndLaunchVM(
					runMode: common.runMode,
					options: buildOpts,
					waitIPTimeout: waitIPTimeout,
					startMode: .background,
					gcd: false,
					recoveryMode: false,
					progressHandler: ProgressObserver.progressHandler
				)
				Logger.appendNewLine(common.format.render(reply))
			}
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Down

struct ComposeDown: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "down",
		abstract: String(localized: "Stop services"),
		discussion: String(localized: "Stops services in reverse depends_on order.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Force stop without graceful shutdown")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Services to stop (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let compose = try loadCompose()
		let toStop = try compose.downOrder(filter: services)

		for (serviceName, _) in toStop {
			let reply = CakedLib.StopHandler.stopVM(name: serviceName, force: force, runMode: common.runMode)
			Logger.appendNewLine(common.format.render([reply]))
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Ps

struct ComposePs: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "ps",
		abstract: String(localized: "List service status"),
		discussion: String(localized: "Shows which services defined in compose.yml are provisioned on this host.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Services to show (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let compose = try loadCompose()
		let resolved = compose.resolvedServices(filter: services)
		let storage = StorageLocation(runMode: common.runMode)

		for (serviceName, svc) in resolved {
			let exists = storage.exists(serviceName)
			let image = svc.image ?? "-"
			let status = exists ? "provisioned" : "not found"
			Logger.appendNewLine("\(serviceName)\t\(status)\t\(image)")
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Rm

struct ComposeRm: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "rm",
		abstract: String(localized: "Remove stopped services"),
		discussion: String(localized: "Deletes VMs for services defined in compose.yml, in reverse depends_on order. Use --stop to stop running services first.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	var file: String? = nil

	@Flag(
		name: [.customShort("s"), .customLong("stop")],
		help: ArgumentHelp(String(localized: "Stop running services before removing")))
	var stop: Bool = false

	@Flag(
		name: [.customLong("force")],
		help: ArgumentHelp(String(localized: "Do not error if a service VM is not found")))
	var force: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Services to remove (default: all)")))
	var services: [String] = []

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let compose = try loadCompose()
		let toRemove = try compose.downOrder(filter: services)

		for (serviceName, _) in toRemove {
			if stop {
				_ = CakedLib.StopHandler.stopVM(name: serviceName, force: true, runMode: common.runMode)
			}

			let result = CakedLib.DeleteHandler.delete(all: false, names: [serviceName], runMode: common.runMode)

			if result.success {
				Logger.appendNewLine(common.format.render(result.objects))
			} else if !force {
				Logger.appendNewLine(common.format.render(result.reason))
			}
		}
	}

	private func loadCompose() throws -> ComposeFile {
		if let path = file { return try ComposeFile.load(fromFile: path) }
		return try ComposeFile.load()
	}
}

// MARK: - Init

struct ComposeInit: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "init",
		abstract: String(localized: "Create a compose.yml template"),
		discussion: String(localized: "Writes a commented compose.yml with example services. Edit it then run `caked compose up`.")
	)

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Flag(
		name: [.customLong("force"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Overwrite an existing compose.yml")))
	var force: Bool = false

	mutating func validate() throws {
		Logger.setLevel(common.logLevel)
	}

	func run() throws {
		let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		let dest = cwd.appendingPathComponent(ComposeFile.filename)

		if FileManager.default.fileExists(atPath: dest.path) && !force {
			throw ValidationError(String(localized: "\(ComposeFile.filename) already exists — use --force to overwrite."))
		}

		try ComposeFile.template.write(to: dest, atomically: true, encoding: .utf8)
		Logger.appendNewLine(String(localized: "Created \(dest.path)"))
		Logger.appendNewLine(String(localized: "Edit compose.yml then run `caked compose up` to start your services."))
	}
}
