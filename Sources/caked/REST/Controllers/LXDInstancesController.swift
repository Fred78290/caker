//
//  LXDInstancesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Vapor
import Synchronization

/// Handles /1.0/instances routes
struct LXDInstancesController: RouteCollection {
	let logger = Logger("LXDInstancesController")
	let group: EventLoopGroup
	let runMode: Utils.RunMode
	
	func boot(routes: any RoutesBuilder) throws {
		let instances = routes.grouped("1.0", "instances")
		
		instances.get(use: listInstances)
		instances.post(use: createInstance)
		
		let named = instances.grouped(":name")
		named.get(use: getInstance)
		named.patch(use: patchInstance)
		named.delete(use: deleteInstance)
		let logs = named.grouped("logs")
		logs.get(use: getLogs)
		logs.grouped(":filename").get(use: getLogFile)
		
		let state = named.grouped("state")
		state.get(use: getState)
		state.put(use: changeState)
		
		named.grouped("exec").post(use: execInstance)
		named.grouped("console").post(use: consoleInstance)
	}
	
	func createCakeAgentHelper(vmName: String, connectionTimeout: Int64 = 5, retries: ConnectionBackoff.Retries = .upTo(1)) throws -> CakeAgentHelper {
		return try CakeAgentHelper.createCakeAgentHelper(name: vmName, connectionTimeout: connectionTimeout, retries: retries, runMode: self.runMode)
	}
	
	func vmInfos(_ location: VMLocation) throws -> VMInformations {
		let result = try CakedLib.InfosHandler.infos(name: location.name, runMode: runMode, client: try self.createCakeAgentHelper(vmName: location.name), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
		
		return result.infos
	}
	
	// Helper: Convert IPv4 CIDR prefix length (e.g. 24) to dotted decimal netmask
	private func dottedNetmask(fromPrefix prefix: Int) -> String {
		guard (0...32).contains(prefix) else { return "" }
		let mask: UInt32 = prefix == 0 ? 0 : ~UInt32(0) << (32 - UInt32(prefix))
		let b1 = (mask >> 24) & 0xFF
		let b2 = (mask >> 16) & 0xFF
		let b3 = (mask >> 8) & 0xFF
		let b4 = mask & 0xFF
		return "\(b1).\(b2).\(b3).\(b4)"
	}
	
	// Helper: Split address and optional CIDR suffix, returns (addr, cidrPrefix)
	private func splitAddressAndCIDR(_ address: String) -> (addr: String, cidr: Int?) {
		if let slashIndex = address.lastIndex(of: "/") {
			let addrPart = String(address[..<slashIndex])
			let cidrPart = String(address[address.index(after: slashIndex)...])
			if let prefix = Int(cidrPart) { return (addrPart, prefix) }
			return (addrPart, nil)
		}
		return (address, nil)
	}
	
	// GET /1.0/instances[?recursion=1] → list of instance URLs
	@Sendable
	func listInstances(req: Request) async throws -> Response {
		let recursion = (req.query[Int.self, at: "recursion"] ?? 0) != 0
		let reply = CakedLib.ListHandler.list(vmonly: true, includeConfig: false, runMode: runMode)
		
		guard reply.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: reply.reason)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		if recursion {
			return try await LXDResponse<[LXDInstance]>.syncList(reply.infos).encodeResponse(for: req)
		}
		
		let urls = reply.infos.map { "/1.0/instances/\($0.name)" }
		let response = LXDResponse<LXDStringListMetadata>.syncList(urls)
		
		return try await response.encodeResponse(for: req)
	}
	
	// POST /1.0/instances → create and build a new Linux VM asynchronously
	@Sendable
	func createInstance(req: Request) async throws -> Response {
		let body = try req.content.decode(LXDCreateInstanceRequest.self)
		
		var userDataPath: String? = nil
		var networkConfigPath: String? = nil
		var sshAuthorizedKeyPath: String? = nil
		
		if let raw = body.userData, raw.isEmpty == false {
			userDataPath = try Utils.saveToTempFile(Data(raw.utf8))
		}
		
		if let raw = body.effectiveNetworkConfig, raw.isEmpty == false {
			networkConfigPath = try Utils.saveToTempFile(Data(raw.utf8))
		}

		if let raw = body.effectiveSSHAuthorizedKey, raw.isEmpty == false {
			sshAuthorizedKeyPath = try Utils.saveToTempFile(Data(raw.utf8))
		}

		if userDataPath == nil, let raw = body.effectiveUserData, raw.isEmpty == false {
			userDataPath = try Utils.saveToTempFile(Data(raw.utf8))
		}
		
		var buildOptions = BuildOptions(name: body.name,
										cpu: body.cpuCount,
										memory: body.memoryMB,
										diskSize: body.diskGB,
										diskFormat: SupportedDiskFormat.defaultSupportedFormat,
										user: body.user,
										password: body.password,
										mainGroup: body.mainGroup,
										otherGroups: body.otherGroups,
										clearPassword: body.clearPassword,
										autostart: body.effectiveAutostart,
										nested: body.nested,
										netIfnames: body.netIfnames,
										image: body.imageURL,
										sshAuthorizedKey: sshAuthorizedKeyPath,
										userData: userDataPath,
										networkConfig: networkConfigPath,
										forwardedPorts: body.forwardedPortAttachments,
										networks: body.networkAttachments,
										consoleURL: body.consoleAttachment,
										autoinstall: body.autoinstall,
										bridgedNetwork: body.bridgedNetwork,
										dynamicPortForwarding: body.dynamicPortForwarding)

		try buildOptions.validateImageSource(remote: true)

		let operation = await LXDOperationStore.shared.create(
			description: "Creating instance \(body.name)",
			resources: ["instances": ["/1.0/instances/\(body.name)"]]
		)
		
		let opID = operation.id
		let rm = runMode
		
		Task.detached {
			var currentMessage: String? = "Start building"
			
			let result = await CakedLib.BuildHandler.build(options: buildOptions, runMode: rm) { progress in
				currentMessage = self.progressOperation(opID, progress: progress, currentMessage: currentMessage)
			}

			// Clean up temp files regardless of outcome
			[userDataPath, networkConfigPath, sshAuthorizedKeyPath].compactMap { $0 }.forEach {
				try? FileManager.default.removeItem(atPath: $0)
			}

			await LXDOperationStore.shared.complete(id: opID, success: result.builded, error: result.reason)
		}
		
		return try await LXDAsyncResponse.make(operation: operation).encodeResponse(status: .accepted, for: req)
	}
	
	// GET /1.0/instances/:name
	@Sendable
	func getInstance(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let location = try? StorageLocation(runMode: runMode).find(name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}
		
		let reply = CakedLib.ListHandler.list(vmonly: true, includeConfig: false, runMode: runMode)
		
		guard let info = reply.infos.first(where: { $0.name == name }) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}
		
		var instance = LXDInstance.from(info)

		if let config = try? location.config() {
			let memoryMB = max(1, config.memorySize / MoB)
			let diskGB = max(1, config.diskSize / GiB)

			var lxdConfig = instance.config
			lxdConfig["limits.cpu"] = String(config.cpuCount)
			lxdConfig["limits.memory"] = "\(memoryMB)MB"
			lxdConfig["limits.disk"] = "\(diskGB)GB"
			lxdConfig["boot.autostart"] = String(config.autostart)
			lxdConfig["security.nesting"] = String(config.nested)
			lxdConfig["user.caker.suspendable"] = String(config.suspendable)
			lxdConfig["user.caker.dynamic_port_forwarding"] = String(config.dynamicPortForwarding)

			if let console = config.console, console.isEmpty == false {
				lxdConfig["user.caker.enable_console"] = "true"
			}

			var devices: [String: [String: String]] = [:]
			for (index, network) in config.networks.enumerated() {
				var nic: [String: String] = [
					"type": "nic",
					"name": "eth\(index)",
					"network": network.network,
				]

				if let mode = network.mode {
					nic["mode"] = mode.description
				}

				if let macAddress = network.macAddress, macAddress.isEmpty == false {
					nic["mac"] = macAddress
				}

				devices["eth\(index)"] = nic
			}

			devices["root"] = [
				"type": "disk",
				"path": "/",
				"size": "\(diskGB)GB",
			]

			instance.config = lxdConfig
			instance.expandedConfig = lxdConfig
			instance.expandedDevices = devices
		}
		
		return try await LXDResponse<LXDInstance>.sync(instance).encodeResponse(for: req)
	}

	// PATCH /1.0/instances/:name
	@Sendable
	func patchInstance(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard (try? StorageLocation(runMode: runMode).find(name)) != nil else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		let body = try req.content.decode(LXDPatchInstanceRequest.self)
		guard body.hasSupportedUpdates else {
			return try await LXDResponse<LXDEmptyMetadata>.error(
				message: "Unsupported or empty PATCH payload. Supported fields: config(limits.*, boot.autostart, security.nesting, user.caker.*), devices (nic + root disk size).",
				code: 400
			).encodeResponse(status: .badRequest, for: req)
		}

		var options = ConfigureOptions(name: name)

		if let cpu = body.cpuCount {
			options.cpu = cpu
		}

		if let memory = body.memoryMB {
			options.memory = max(256, memory)
		}

		if let disk = body.diskGB {
			options.diskSize = max(1, disk)
		}

		if let autostart = body.autostart {
			options.autostart = autostart
		}

		if let nested = body.nested {
			options.nested = nested
		}

		if let suspendable = body.suspendable {
			options.suspendable = suspendable
		}

		if let dynamicPortForwarding = body.dynamicPortForwarding {
			options.dynamicPortForwarding = dynamicPortForwarding
		}

		if body.hasNICDevicesUpdate {
			options.setNetwork(value: body.networkAttachments.map(\.description))
		}

		let operation = await LXDOperationStore.shared.create(
			description: "Patching instance \(name)",
			resources: ["instances": ["/1.0/instances/\(name)"]]
		)

		let opID = operation.id
		let rm = runMode

		Task.detached {
			let result = CakedLib.ConfigureHandler.configure(name: name, options: options, runMode: rm)
			await LXDOperationStore.shared.complete(id: opID, success: result.configured, error: result.reason)
		}

		return try await LXDAsyncResponse.make(operation: operation).encodeResponse(status: .accepted, for: req)
	}
	
	// DELETE /1.0/instances/:name
	@Sendable
	func deleteInstance(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		let operation = await LXDOperationStore.shared.create(
			description: "Deleting instance",
			resources: ["instances": ["/1.0/instances/\(name)"]]
		)
		
		let opID = operation.id
		let rm = runMode
		
		Task.detached {
			do {
				let deleted = try CakedLib.DeleteHandler.delete(names: [name], runMode: rm)
				let success = deleted.first?.deleted ?? false
				let reason = deleted.first?.reason ?? "Unknown error"
				
				await LXDOperationStore.shared.complete(id: opID, success: success, error: success ? "" : reason)
			} catch {
				await LXDOperationStore.shared.complete(id: opID, success: false, error: error.localizedDescription)
			}
		}
		
		return try await LXDAsyncResponse.make(operation: operation).encodeResponse(status: .accepted, for: req)
	}
	
	// GET /1.0/instances/:name/state
	@Sendable
	func getState(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		guard let location = try? StorageLocation(runMode: self.runMode).find(name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}
		
		guard let info = try? self.vmInfos(location) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not reachable", code: 405)
				.encodeResponse(status: .notFound, for: req)
		}
		
		let (lxdStatus, lxdStatusCode) = lxdStatusFrom(state: info.status)
		
		var networkState: [String: LXDNetworkState]? = nil
		
		if let attachedNetworks = info.attachedNetworks {
			networkState = attachedNetworks.reduce(into: [String: LXDNetworkState]()) { result, network in
				let addr: [LXDNetworkAddress] =
				network.ipAddresses?.map { raw in
					let parts = splitAddressAndCIDR(raw)
					let address = parts.addr
					let isIPv6 = address.contains(":")
					let family = isIPv6 ? "inet6" : "inet"
					let netmask: String
					
					if isIPv6 {
						// We don't provide dotted netmask for IPv6; CIDR may be present but leave netmask empty
						netmask = ""
					} else if let cidr = parts.cidr {
						netmask = dottedNetmask(fromPrefix: cidr)
					} else {
						// Fallback placeholder when no CIDR available
						netmask = "255.255.255.0"
					}
					
					return LXDNetworkAddress(address: address, family: family, netmask: netmask, scope: "global")
				} ?? []
				
				result[network.network] = LXDNetworkState(
					addresses: addr,
					counters: LXDNetworkCounters(bytesReceived: Int(network.bytesReceived), bytesSent: Int(network.bytesSent), packetsReceived: Int(network.packetsReceived), packetsSent: Int(network.packetsSent)),
					hwaddr: network.macAddress ?? "",
					mtu: Int(network.mtu ?? 1500),
					state: "up",
					type: "broadcast"
				)
			}
		}
		let disks = info.diskInfos.reduce(into: [String: LXDDiskState]()) { result, disk in
			result[disk.device] = LXDDiskState(usage: Int(disk.used), total: Int(disk.total))
		}
		
		let memInfos = Caked.MemoryInfo.with {
			if let mem = info.memory {
				$0.total = mem.total ?? 0
				$0.used = mem.used ?? 0
				$0.swapTotal = mem.swapTotal ?? 0
				$0.swapUsed = mem.swapUsed ?? 0
				$0.swapFree = mem.swapFree ?? 0
			}
		}
		
		let state = LXDInstanceState(
			cpu: LXDCPUState(usage: Int(info.cpuInfos?.totalUsagePercent ?? 0)),
			disk: disks,
			memory: LXDMemoryState(
				swapUsage: Int(memInfos.swapUsed),
				swapUsagePeak: Int(memInfos.swapUsed),
				total: Int(memInfos.total),
				usage: Int(memInfos.used),
				usagePeak: Int(memInfos.used)
			),
			network: networkState,
			pid: Int(location.readPID() ?? 0),
			processes: Int(info.numOfProcesses),
			status: lxdStatus,
			statusCode: lxdStatusCode
		)
		
		return try await LXDResponse<LXDInstanceState>.sync(state).encodeResponse(for: req)
	}
	
	@Sendable
	func getLogs(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let location = try? StorageLocation(runMode: runMode).find(name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		let logs: [String] = ["console.log", "output.log"].compactMap { logName in
			if let logURL = location.logURL(named: logName), FileManager.default.fileExists(atPath: logURL.path(percentEncoded: false)) {
				return "/1.0/instances/\(name)/logs/\(logName)"
			}

			return nil
		}

		return try await LXDResponse<LXDStringListMetadata>.syncList(logs).encodeResponse(for: req)
	}

	// GET /1.0/instances/:name/logs/:filename
	@Sendable
	func getLogFile(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		guard let filename = req.parameters.get("filename"), filename.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing log filename", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}

		// Allowlist: only known log filenames may be served.  logURL(named:) guards
		// against path traversal but resolves into the VM root, not a logs/ subdir,
		// so without an allowlist any file in the VM bundle would be readable.
		let allowedLogFiles: Set<String> = ["console.log", "output.log"]
		guard allowedLogFiles.contains(filename) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Log file '\(filename)' not found for instance '\(name)'", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		guard let location = try? StorageLocation(runMode: runMode).find(name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		guard let logURL = location.logURL(named: filename), FileManager.default.fileExists(atPath: logURL.path(percentEncoded: false)) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Log file '\(filename)' not found for instance '\(name)'", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		return try await req.fileio.asyncStreamFile(at: logURL.path(percentEncoded: false))
	}

	// PUT /1.0/instances/:name/state
	@Sendable
	func changeState(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		let stateReq = try req.content.decode(LXDStateChangeRequest.self)
		let force = stateReq.force ?? false
		let timeout = stateReq.timeout ?? 120
		
		let operation = await LXDOperationStore.shared.create(
			description: "Changing instance state to \(stateReq.action)",
			resources: ["instances": ["/1.0/instances/\(name)"]]
		)
		
		let opID = operation.id
		let action = stateReq.action.lowercased()
		let rm = runMode
		
		Task.detached {
			switch action {
			case "start", "unfreeze":
				let result =
				(try? CakedLib.StartHandler.startVM(
					name: name,
					screenSize: nil,
					vncPassword: nil,
					vncPort: nil,
					waitIPTimeout: timeout,
					startMode: CakedLib.StartHandler.StartMode.service,
					gcd: false,
					recoveryMode: false,
					runMode: rm
				)) ?? GRPCLib.StartedReply(name: name, ip: "", started: false, reason: "Failed to start")
				await LXDOperationStore.shared.complete(id: opID, success: result.started, error: result.reason)
				
			case "stop":
				let result = CakedLib.StopHandler.stopVM(name: name, force: force, runMode: rm)
				await LXDOperationStore.shared.complete(id: opID, success: result.stopped, error: result.reason)
				
			case "restart":
				let result = CakedLib.RestartHandler.restart(
					name: name, startMode: .service, gcd: false, force: force,
					waitIPTimeout: timeout, runMode: rm
				)
				
				await LXDOperationStore.shared.complete(id: opID, success: result.restarted, error: result.reason)
				
			case "freeze":
				do {
					let result = try CakedLib.SuspendHandler.suspendVM(name: name, runMode: rm)
					await LXDOperationStore.shared.complete(id: opID, success: result.suspended, error: result.reason)
				} catch {
					await LXDOperationStore.shared.complete(id: opID, success: false, error: error.localizedDescription)
				}
				
			default:
				await LXDOperationStore.shared.complete(id: opID, success: false, error: "Unknown action: \(action)")
			}
		}
		
		return try await LXDAsyncResponse.make(operation: operation).encodeResponse(status: .accepted, for: req)
	}
	
	// POST /1.0/instances/:name/exec
	@Sendable
	func execInstance(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		let execReq = try req.content.decode(LXDExecRequest.self)
		
		guard execReq.command.isEmpty == false else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Command must not be empty", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		// Verify instance exists
		guard let location = try? StorageLocation(runMode: runMode).find(name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}
		
		let mode: LXDExecContext.ExecMode = (execReq.interactive ?? false) ? .interactive : .nonInteractive
		
		// Generate per-fd WebSocket secrets
		var metadatas: [String: String] = [
			"0": UUID().uuidString.lowercased(),
			"control": UUID().uuidString.lowercased(),
		]
		
		if mode == .nonInteractive {
			metadatas["1"] = UUID().uuidString.lowercased()
			metadatas["2"] = UUID().uuidString.lowercased()
		}
		
		let (response, operationId) = LXDExecAsyncResponse.make(instanceName: name, metadatas: metadatas)
		
		// Build exec context and register in session store (for WebSocket connections)
		let context = LXDExecContext(
			instanceName: name,
			command: execReq.command,
			environment: execReq.environment ?? [:],
			mode: mode,
			height: execReq.height ?? 24,
			width: execReq.width ?? 80,
			runMode: runMode,
			fds: metadatas
		)
		
		await LXDExecSessionStore.shared.register(operationId: operationId, context: context)
		let runner: LXDRunnable
		
		if context.mode == .interactive {
			runner = try LXDConsoleTextRunner(location, operationId: operationId, context: context)
		} else {
			runner = LXDExecRunner(location, operationId: operationId, context: context)
		}

		// Register first so complete() always finds an existing entry, even if the
		// runner errors out before the detached task has a chance to be referenced.
		let taskRef: Mutex<Task<Void, Never>?> = .init(nil)
		await LXDOperationStore.shared.registerExec(id: operationId, instanceName: name) {
			taskRef.withLock { $0 }?.cancel()
		}

		// Start background exec task (waits for WebSocket connections, then runs)
		let task = Task.detached {
			await runner.run()
		}
		taskRef.withLock { $0 = task }
		
		return try await response.encodeResponse(status: .accepted, for: req)
	}
	
	private func createConsoleRunner(_ location: VMLocation, consoleType: String, operationId: String, context: LXDExecContext) throws -> LXDRunnable {
		if consoleType == "vga" {
			// VGA console: bridge the VNC WebSocket to the VM's raw VNC TCP socket.
			LXDConsoleVGARunner(location, operationId: operationId, context: context)
		} else {
			// Text (PTY) console: reuse exec infrastructure via ShellHandler.
			try LXDConsoleTextRunner(location, operationId: operationId, context: context)
		}
	}
	
	// POST /1.0/instances/:name/console
	@Sendable
	func consoleInstance(req: Request) async throws -> Response {
		guard let name = req.parameters.get("name") else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Missing instance name", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		let consoleReq = (try? req.content.decode(LXDConsoleRequest.self)) ?? LXDConsoleRequest()
		let consoleType = consoleReq.type ?? "console"
		
		guard consoleType == "console" || consoleType == "vga" else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Unsupported console type '\(consoleType)'", code: 400)
				.encodeResponse(status: .badRequest, for: req)
		}
		
		// Verify instance exists.
		guard let location = try? StorageLocation(runMode: runMode).find(name) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}
		
		// Both console types use two fds: "0" (pty / VNC data) and "control".
		var mode: LXDExecContext.ExecMode = .interactive
		let metadatas: [String: String] = [
			"0": UUID().uuidString.lowercased(),
			"control": UUID().uuidString.lowercased()
		]
		
		// For VGA consoles, return the VNC password so the browser-side noVNC client
		// can authenticate.  Keep it out of `metadatas` (the WebSocket fd secrets)
		// so it is not stored in LXDExecSessionStore alongside the real secrets.
		var responseMetadatas = metadatas
		if consoleType == "vga" {
			mode = .vga

			guard let vncInfos = try? CakedLib.VNCInfosHandler.vncInfos(name: name, runMode: runMode) else {
				return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' doesn't have a VGA console", code: 405)
					.encodeResponse(status: .notFound, for: req)
			}

			if let vncURLStr = vncInfos.urls.first, let components = URLComponents(string: vncURLStr), let vncPassword = components.password, vncPassword.isEmpty == false {
				// vnc-password goes only into the HTTP response, not into the session store.
				responseMetadatas["vnc-password"] = vncPassword
			}
		}

		let (response, operationId) = LXDExecAsyncResponse.make(instanceName: name, metadatas: responseMetadatas)
		let context = LXDExecContext(
			instanceName: name,
			command: [],
			environment: [:],
			mode: mode,
			height: consoleReq.height ?? 24,
			width: consoleReq.width ?? 80,
			runMode: runMode,
			fds: metadatas  // fd secrets only — no vnc-password
		)

		let runner = try self.createConsoleRunner(location, consoleType: consoleType, operationId: operationId, context: context)

		await LXDExecSessionStore.shared.register(operationId: operationId, context: context)

		// Register before starting the task so complete() always finds an existing entry.
		let consoleTaskRef: Mutex<Task<Void, Never>?> = .init(nil)
		await LXDOperationStore.shared.registerConsole(id: operationId, instanceName: name) {
			consoleTaskRef.withLock { $0 }?.cancel()
		}

		let task = Task.detached {
			await runner.run()
		}
		consoleTaskRef.withLock { $0 = task }
		
		return try await response.encodeResponse(status: .accepted, for: req)
	}
	
	// MARK: - Helpers
	
	private func lxdStatusFrom(state: Status) -> (String, Int) {
		switch state {
		case .running: return ("Running", 103)
		case .stopped: return ("Stopped", 102)
		default: return ("Frozen", 110)
		}
	}
	
	private func lxdStatusFrom(state: String) -> (String, Int) {
		switch state.lowercased() {
		case "running": return ("Running", 103)
		case "paused": return ("Frozen", 110)
		default: return ("Stopped", 102)
		}
	}
	
	private func progressOperation(_ opID: String, progress: ProgressObserver.ProgressValue, currentMessage: String?) -> String? {
		// Store updates are dispatched as fire-and-forget Tasks to avoid blocking the
		// cooperative thread with .wait().  Only .step returns a new currentMessage
		// synchronously; the other cases just need a best-effort async store write.
		switch progress {
		case .step(let message):
			return message

		case .progress(_, let fractionCompleted):
			Task {
				if let currentMessage {
					await LXDOperationStore.shared.update(id: opID, description: "\(currentMessage): (\(Int(fractionCompleted * 100))%)")
				} else {
					await LXDOperationStore.shared.update(id: opID, description: "(\(Int(fractionCompleted * 100))%)")
				}
			}

		case .terminated(let result, let message):
			Task {
				if case .failure(let error) = result {
					let errStr = message ?? error.reason
					let description = "Operation failed: \(errStr)"
					await LXDOperationStore.shared.complete(id: opID, success: false, description: description, error: errStr)
				} else {
					let description = message.map { "Operation succeeded: \($0)" } ?? "Operation succeeded"
					await LXDOperationStore.shared.complete(id: opID, success: true, description: description)
				}
			}
		}

		return currentMessage
	}
}
