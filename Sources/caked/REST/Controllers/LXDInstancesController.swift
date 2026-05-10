//
//  LXDInstancesController.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//


import CakedLib
import Foundation
import GRPCLib
import Vapor

/// Handles /1.0/instances routes
struct LXDInstancesController: RouteCollection {
	let runMode: Utils.RunMode

	func boot(routes: any RoutesBuilder) throws {
		let instances = routes.grouped("1.0", "instances")

		instances.get(use: listInstances)
		instances.post(use: createInstance)

		let named = instances.grouped(":name")
		named.get(use: getInstance)
		named.delete(use: deleteInstance)

		let state = named.grouped("state")
		state.get(use: getState)
		state.put(use: changeState)

		named.grouped("exec").post(use: execInstance)
		named.grouped("console").post(use: consoleInstance)
	}

	// GET /1.0/instances → list of instance URLs
	@Sendable
	func listInstances(req: Request) async throws -> Response {
		let reply = CakedLib.ListHandler.list(vmonly: true, includeConfig: false, runMode: runMode)
		
		guard reply.success else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: reply.reason)
				.encodeResponse(status: .badRequest, for: req)
		}

		if req.query["recursion"] == "1" {
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

		if let raw = body.userData, raw.isEmpty == false {
			userDataPath = try Utils.saveToTempFile(Data(raw.utf8))
		}
		if let raw = body.networkConfig, raw.isEmpty == false {
			networkConfigPath = try Utils.saveToTempFile(Data(raw.utf8))
		}

		let buildOptions = BuildOptions(
			name: body.name,
			cpu: body.cpuCount,
			memory: body.memoryMB,
			diskSize: body.diskGB,
			image: body.imageURL,
			userData: userDataPath,
			networkConfig: networkConfigPath
		)

		let operation = await LXDOperationStore.shared.create(
			description: "Creating instance \(body.name)",
			resources: ["instances": ["/1.0/instances/\(body.name)"]]
		)

		let opID = operation.id
		let rm = runMode

		Task.detached {
			let result = await CakedLib.BuildHandler.build(options: buildOptions, runMode: rm) { _ in }
			// Clean up temp files regardless of outcome
			[userDataPath, networkConfigPath].compactMap { $0 }.forEach {
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

		let reply = CakedLib.ListHandler.list(vmonly: true, includeConfig: false, runMode: runMode)

		guard let info = reply.infos.first(where: { $0.name == name }) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		let instance = LXDInstance.from(info)
		return try await LXDResponse<LXDInstance>.sync(instance).encodeResponse(for: req)
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

		let reply = CakedLib.ListHandler.list(vmonly: true, includeConfig: false, runMode: runMode)

		guard let info = reply.infos.first(where: { $0.name == name }) else {
			return try await LXDResponse<LXDEmptyMetadata>.error(message: "Instance '\(name)' not found", code: 404)
				.encodeResponse(status: .notFound, for: req)
		}

		let (lxdStatus, lxdStatusCode) = lxdStatusFrom(state: info.state)

		var networkState: [String: LXDNetworkState]? = nil
		if let ip = info.ip, ip.isEmpty == false {
			let addr = LXDNetworkAddress(address: ip, family: "inet", netmask: "255.255.255.0", scope: "global")
			networkState = [
				"eth0": LXDNetworkState(
					addresses: [addr],
					counters: LXDNetworkCounters(bytesReceived: 0, bytesSent: 0, packetsReceived: 0, packetsSent: 0),
					hwaddr: "",
					mtu: 1500,
					state: "up",
					type: "broadcast"
				)
			]
		}

		let state = LXDInstanceState(
			cpu: LXDCPUState(usage: 0),
			disk: ["root": LXDDiskState(usage: Int(info.sizeOnDisk), total: Int(info.diskSize))],
			memory: LXDMemoryState(swapUsage: 0, swapUsagePeak: 0, total: 0, usage: 0, usagePeak: 0),
			network: networkState,
			pid: 0,
			processes: 0,
			status: lxdStatus,
			statusCode: lxdStatusCode
		)

		return try await LXDResponse<LXDInstanceState>.sync(state).encodeResponse(for: req)
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
				let result = (try? CakedLib.StartHandler.startVM(
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

		let interactive = execReq.interactive ?? false

		// Generate per-fd WebSocket secrets
		var secrets: [String: String] = [
			"0": UUID().uuidString.lowercased(),
			"control": UUID().uuidString.lowercased()
		]
		if !interactive {
			secrets["1"] = UUID().uuidString.lowercased()
			secrets["2"] = UUID().uuidString.lowercased()
		}

		let (response, operationId) = LXDExecAsyncResponse.make(instanceName: name, fds: secrets)

		// Build exec context and register in session store (for WebSocket connections)
		let context = LXDExecContext(
			instanceName: name,
			command: execReq.command,
			environment: execReq.environment ?? [:],
			interactive: interactive,
			height: execReq.height ?? 24,
			width: execReq.width ?? 80,
			runMode: runMode,
			secrets: secrets
		)
		await LXDExecSessionStore.shared.register(operationId: operationId, context: context)
		let runner = LXDExecRunner(location, operationId: operationId, context: context)

		// Start background exec task (waits for WebSocket connections, then runs)
		let task = Task.detached {
			await runner.run()
		}

		// Register in operation store (for GET /1.0/operations/:id)
		await LXDOperationStore.shared.registerExec(id: operationId, instanceName: name) {
			task.cancel()
		}

		return try await response.encodeResponse(status: .accepted, for: req)
	}

	private func createConsoleRunner(_ location: VMLocation, consoleType: String, operationId: String, context: LXDExecContext) -> LXDRunnable {
		if consoleType == "vga" {
			// VGA console: bridge the VNC WebSocket to the VM's raw VNC TCP socket.
			LXDConsoleVGARunner(location, operationId: operationId, context: context)
		} else {
			// Text (PTY) console: reuse exec infrastructure via ShellHandler.
			LXDExecRunner(location, operationId: operationId, context: context)
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
		var secrets: [String: String] = [
			"0": UUID().uuidString.lowercased(),
			"control": UUID().uuidString.lowercased()
		]

		// For VGA consoles, also expose the VNC password so the browser-side noVNC
		// client can authenticate against the VM's VNC server.  The "vnc-password"
		// key is not a WebSocket fd secret; it is metadata that is safe to return
		// because the endpoint is already authenticated.
		if consoleType == "vga" {
			if let vncInfos = try? CakedLib.VNCInfosHandler.vncInfos(name: name, runMode: runMode),
			   let vncURLStr = vncInfos.urls.first,
			   let components = URLComponents(string: vncURLStr) {
				secrets["vnc-password"] = components.password ?? ""
			}
		}

		let (response, operationId) = LXDExecAsyncResponse.make(instanceName: name, fds: secrets)
		let context = LXDExecContext(
			instanceName: name,
			command: [],
			environment: [:],
			interactive: true,
			height: consoleReq.height ?? 24,
			width: consoleReq.width ?? 80,
			runMode: runMode,
			secrets: secrets
		)
		let runner = self.createConsoleRunner(location, consoleType: consoleType, operationId: operationId, context: context)
		await LXDExecSessionStore.shared.register(operationId: operationId, context: context)

		let task = Task.detached {
			await runner.run()
		}

		await LXDOperationStore.shared.registerConsole(id: operationId, instanceName: name) {
			task.cancel()
		}

		return try await response.encodeResponse(status: .accepted, for: req)
	}

	// MARK: - Helpers

	private func lxdStatusFrom(state: String) -> (String, Int) {
		switch state.lowercased() {
		case "running": return ("Running", 103)
		case "paused": return ("Frozen", 110)
		default: return ("Stopped", 102)
		}
	}
}
