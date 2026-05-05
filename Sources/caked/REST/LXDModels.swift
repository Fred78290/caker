//
//  LXDModels.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/05/2026.
//

import CakedLib
import Foundation
import GRPCLib
import Vapor

// MARK: - LXD API Response Envelope

struct LXDResponse<T: Content>: Content {
	var type: String
	var status: String
	var statusCode: Int
	var operation: String
	var errorCode: Int
	var error: String
	var metadata: T?

	enum CodingKeys: String, CodingKey {
		case type
		case status
		case statusCode = "status_code"
		case operation
		case errorCode = "error_code"
		case error
		case metadata
	}

	static func sync(_ metadata: T, status: String = "Success", statusCode: Int = 200) -> LXDResponse<T> {
		LXDResponse(type: "sync", status: status, statusCode: statusCode, operation: "", errorCode: 0, error: "", metadata: metadata)
	}
}

struct LXDEmptyMetadata: Content {}

struct LXDStringListMetadata: Content {
	var value: [String]

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(value)
	}

	init(from decoder: Decoder) throws {
		value = try decoder.singleValueContainer().decode([String].self)
	}

	init(_ value: [String]) {
		self.value = value
	}
}

struct LXDErrorMetadata: Content {
	var value: String

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(value)
	}

	init(from decoder: Decoder) throws {
		value = try decoder.singleValueContainer().decode(String.self)
	}

	init(_ value: String) {
		self.value = value
	}
}

extension LXDResponse where T == LXDEmptyMetadata {
	static func error(message: String, code: Int = 500) -> LXDResponse<LXDEmptyMetadata> {
		LXDResponse(type: "error", status: "Failure", statusCode: code, operation: "", errorCode: code, error: message, metadata: nil)
	}
}

extension LXDResponse where T == LXDStringListMetadata {
	static func syncList(_ items: [String]) -> LXDResponse<LXDStringListMetadata> {
		LXDResponse(type: "sync", status: "Success", statusCode: 200, operation: "", errorCode: 0, error: "", metadata: LXDStringListMetadata(items))
	}
}

// MARK: - Async Operation

struct LXDOperationMetadata: Content {
	var id: String
	var type: String
	var description: String
	var createdAt: String
	var updatedAt: String
	var status: String
	var statusCode: Int
	var resources: [String: [String]]
	var metadata: [String: String]?
	var mayCancel: Bool
	var error: String

	enum CodingKeys: String, CodingKey {
		case id
		case type
		case description
		case createdAt = "created_at"
		case updatedAt = "updated_at"
		case status
		case statusCode = "status_code"
		case resources
		case metadata
		case mayCancel = "may_cancel"
		case error
	}
}

struct LXDAsyncResponse: Content {
	var type: String
	var status: String
	var statusCode: Int
	var operation: String
	var errorCode: Int
	var error: String
	var metadata: LXDOperationMetadata

	enum CodingKeys: String, CodingKey {
		case type
		case status
		case statusCode = "status_code"
		case operation
		case errorCode = "error_code"
		case error
		case metadata
	}

	static func make(operation: LXDOperationMetadata) -> LXDAsyncResponse {
		LXDAsyncResponse(
			type: "async",
			status: "Operation created",
			statusCode: 100,
			operation: "/1.0/operations/\(operation.id)",
			errorCode: 0,
			error: "",
			metadata: operation
		)
	}
}

// MARK: - Server Info

struct LXDServerInfo: Content {
	var apiExtensions: [String]
	var apiStatus: String
	var apiVersion: String
	var auth: String
	var config: [String: String]
	var environment: LXDEnvironment
	var `public`: Bool

	enum CodingKeys: String, CodingKey {
		case apiExtensions = "api_extensions"
		case apiStatus = "api_status"
		case apiVersion = "api_version"
		case auth
		case config
		case environment
		case `public` = "public"
	}
}

struct LXDEnvironment: Content {
	var architectures: [String]
	var certificate: String
	var certificateFingerprint: String
	var driver: String
	var driverVersion: String
	var firewall: String
	var kernel: String
	var kernelArchitecture: String
	var kernelVersion: String
	var ovmfPath: String
	var server: String
	var serverName: String
	var serverVersion: String
	var storage: String
	var storageVersion: String

	enum CodingKeys: String, CodingKey {
		case architectures
		case certificate
		case certificateFingerprint = "certificate_fingerprint"
		case driver
		case driverVersion = "driver_version"
		case firewall
		case kernel
		case kernelArchitecture = "kernel_architecture"
		case kernelVersion = "kernel_version"
		case ovmfPath = "ovmf_path"
		case server
		case serverName = "server_name"
		case serverVersion = "server_version"
		case storage
		case storageVersion = "storage_version"
	}
}

// MARK: - Instance Models

struct LXDInstance: Content {
	var architecture: String
	var config: [String: String]
	var createdAt: String
	var description: String
	var ephemeral: Bool
	var expandedConfig: [String: String]
	var expandedDevices: [String: [String: String]]
	var lastUsedAt: String
	var location: String
	var name: String
	var profiles: [String]
	var project: String
	var restore: String?
	var stateful: Bool
	var status: String
	var statusCode: Int
	var type: String

	enum CodingKeys: String, CodingKey {
		case architecture
		case config
		case createdAt = "created_at"
		case description
		case ephemeral
		case expandedConfig = "expanded_config"
		case expandedDevices = "expanded_devices"
		case lastUsedAt = "last_used_at"
		case location
		case name
		case profiles
		case project
		case restore
		case stateful
		case status
		case statusCode = "status_code"
		case type
	}
}

extension LXDInstance {
	static func from(_ info: VirtualMachineInfo) -> LXDInstance {
		let lxdStatus: String
		let lxdStatusCode: Int

		switch info.state.lowercased() {
		case "running":
			lxdStatus = "Running"
			lxdStatusCode = 103
		case "paused":
			lxdStatus = "Frozen"
			lxdStatusCode = 110
		default:
			lxdStatus = "Stopped"
			lxdStatusCode = 102
		}

		var config: [String: String] = [:]
		if let macAddress = info.config?.macAddress {
			config["volatile.eth0.hwaddr"] = macAddress
		}

		return LXDInstance(
			architecture: info.config?.arch.description ?? Architecture.current().description,
			config: config,
			createdAt: ISO8601DateFormatter().string(from: Date()),
			description: "",
			ephemeral: false,
			expandedConfig: config,
			expandedDevices: [:],
			lastUsedAt: ISO8601DateFormatter().string(from: Date()),
			location: "none",
			name: info.name,
			profiles: ["default"],
			project: "default",
			restore: nil,
			stateful: false,
			status: lxdStatus,
			statusCode: lxdStatusCode,
			type: "virtual-machine"
		)
	}
}

// MARK: - Instance State

struct LXDInstanceState: Content {
	var cpu: LXDCPUState
	var disk: [String: LXDDiskState]
	var memory: LXDMemoryState
	var network: [String: LXDNetworkState]?
	var pid: Int
	var processes: Int
	var status: String
	var statusCode: Int

	enum CodingKeys: String, CodingKey {
		case cpu, disk, memory, network, pid, processes, status
		case statusCode = "status_code"
	}
}

struct LXDCPUState: Content {
	var usage: Int
}

struct LXDDiskState: Content {
	var usage: Int
	var total: Int
}

struct LXDMemoryState: Content {
	var swapUsage: Int
	var swapUsagePeak: Int
	var total: Int
	var usage: Int
	var usagePeak: Int

	enum CodingKeys: String, CodingKey {
		case swapUsage = "swap_usage"
		case swapUsagePeak = "swap_usage_peak"
		case total
		case usage
		case usagePeak = "usage_peak"
	}
}

struct LXDNetworkState: Content {
	var addresses: [LXDNetworkAddress]
	var counters: LXDNetworkCounters
	var hwaddr: String
	var mtu: Int
	var state: String
	var type: String
}

struct LXDNetworkAddress: Content {
	var address: String
	var family: String
	var netmask: String
	var scope: String
}

struct LXDNetworkCounters: Content {
	var bytesReceived: Int
	var bytesSent: Int
	var packetsReceived: Int
	var packetsSent: Int

	enum CodingKeys: String, CodingKey {
		case bytesReceived = "bytes_received"
		case bytesSent = "bytes_sent"
		case packetsReceived = "packets_received"
		case packetsSent = "packets_sent"
	}
}

// MARK: - State Change Request

struct LXDStateChangeRequest: Content {
	var action: String
	var force: Bool?
	var stateful: Bool?
	var timeout: Int?
}

// MARK: - Network Models

struct LXDNetwork: Content {
	var config: [String: String]
	var description: String
	var locations: [String]
	var managed: Bool
	var name: String
	var status: String
	var type: String
	var usedBy: [String]

	enum CodingKeys: String, CodingKey {
		case config, description, locations, managed, name, status, type
		case usedBy = "used_by"
	}

	static func from(name: String, network: BridgedNetwork) -> LXDNetwork {
		var config: [String: String] = [:]
		if network.gateway.isEmpty == false {
			config["ipv4.address"] = network.gateway
			config["ipv4.dhcp"] = "true"
		}
		if network.dhcpEnd.isEmpty == false {
			config["ipv4.dhcp.ranges"] = "\(network.dhcpStart)-\(network.dhcpEnd)"
		}
		if network.dhcpLease.isEmpty == false {
			config["ipv4.dhcp.expiry"] = network.dhcpLease
		}

		return LXDNetwork(
			config: config,
			description: network.description,
			locations: ["none"],
			managed: true,
			name: name,
			status: network.endpoint.isEmpty ? "Unavailable" : "Created",
			type: network.mode.rawValue,
			usedBy: []
		)
	}
}

// MARK: - Image Models

struct LXDImage: Content {
	var aliases: [LXDImageAlias]
	var architecture: String
	var autoUpdate: Bool
	var cached: Bool
	var createdAt: String
	var expiresAt: String
	var filename: String
	var fingerprint: String
	var lastUsedAt: String
	var `public`: Bool
	var size: Int
	var type: String
	var uploadedAt: String

	enum CodingKeys: String, CodingKey {
		case aliases, architecture, cached, filename, fingerprint, size, type
		case autoUpdate = "auto_update"
		case createdAt = "created_at"
		case expiresAt = "expires_at"
		case lastUsedAt = "last_used_at"
		case `public` = "public"
		case uploadedAt = "uploaded_at"
	}
}

struct LXDImageAlias: Content {
	var description: String
	var name: String
}
