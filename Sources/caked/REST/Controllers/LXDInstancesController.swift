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

	// MARK: - Helpers

	private func lxdStatusFrom(state: String) -> (String, Int) {
		switch state.lowercased() {
		case "running": return ("Running", 103)
		case "paused": return ("Frozen", 110)
		default: return ("Stopped", 102)
		}
	}
}
