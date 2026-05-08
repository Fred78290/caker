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

extension LXDResponse where T == [LXDNetwork] {
	static func syncList(_ items: [BridgedNetwork]) -> LXDResponse<[LXDNetwork]> {
		LXDResponse(type: "sync", status: "Success", statusCode: 200, operation: "", errorCode: 0, error: "", metadata: items.map {LXDNetwork.from(name: $0.name, network: $0, referencedNetworks: LXDNetwork.referencedNetworks) })
	}
}

extension LXDResponse where T == [LXDInstance] {
	static func syncList(_ items: [VirtualMachineInfo]) -> LXDResponse<[LXDInstance]> {
		LXDResponse(type: "sync", status: "Success", statusCode: 200, operation: "", errorCode: 0, error: "", metadata: items.map {LXDInstance.from($0) })
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

// MARK: - Create Instance Request

/// Source descriptor for a new LXD instance.
struct LXDInstanceSource: Content {
	/// "image" (LXD alias / fingerprint), "url" (direct cloud-image URL), or "none".
	var type: String
	/// LXD image alias, e.g. "ubuntu:noble" (used when type == "image").
	var alias: String?
	/// Direct cloud-image download URL (used when type == "url").
	var url: String?
	/// Image fingerprint (used when type == "image").
	var fingerprint: String?
}

/// Body for POST /1.0/instances (subset of the LXD API).
struct LXDCreateInstanceRequest: Content {
	var name: String
	var source: LXDInstanceSource
	/// Supported keys: limits.cpu, limits.memory (e.g. "2048MB"), limits.disk (e.g. "20GB").
	var config: [String: String]?
	var description: String?
	/// Must be "virtual-machine" (the only type Caker supports).
	var type: String?
	var profiles: [String]?
	/// Inline cloud-init user-data content (passed verbatim to cloud-init).
	var userData: String?
	/// Inline cloud-init network-config content (passed verbatim to cloud-init).
	var networkConfig: String?

	enum CodingKeys: String, CodingKey {
		case name, source, config, description, type, profiles
		case userData = "user_data"
		case networkConfig = "network_config"
	}

	// MARK: Derived helpers

	/// Number of vCPUs, defaults to 1.
	var cpuCount: UInt16 {
		guard let raw = config?["limits.cpu"], let n = UInt16(raw) else { return 1 }
		return max(1, n)
	}

	/// Memory in MiB, defaults to 512. Parses "NGB", "NMB", or plain integer.
	var memoryMB: UInt64 {
		guard let raw = config?["limits.memory"] else { return 512 }
		if raw.hasSuffix("GiB") || raw.hasSuffix("GB") {
			let digits = raw.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
			return (UInt64(digits) ?? 1) * 1024
		} else if raw.hasSuffix("MiB") || raw.hasSuffix("MB") {
			let digits = raw.prefix(while: { $0.isNumber || $0 == "-" })
			return UInt64(digits) ?? 512
		}
		return UInt64(raw) ?? 512
	}

	/// Disk size in GiB, defaults to 10.
	var diskGB: UInt64 {
		guard let raw = config?["limits.disk"] else { return 10 }
		if raw.hasSuffix("GiB") || raw.hasSuffix("GB") {
			let digits = raw.prefix(while: { $0.isNumber })
			return UInt64(digits) ?? 10
		}
		return UInt64(raw) ?? 10
	}

	/// Resolves the cloud-image URL or LXD image alias to pass to BuildOptions.
	var imageURL: String {
		switch source.type {
		case "url":
			return source.url?.isEmpty == false ? source.url! : defaultUbuntuImage
		case "image":
			if let alias = source.alias, alias.isEmpty == false { return alias }
			if let fp = source.fingerprint, fp.isEmpty == false { return fp }
			return defaultUbuntuImage
		default:
			return defaultUbuntuImage
		}
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

	typealias ReferencedNetworks = [String: [String]]

	static var referencedNetworks: ReferencedNetworks {
		var usedNetworks: ReferencedNetworks = ReferencedNetworks()

		guard let list = try? StorageLocation(runMode: LXDRESTServer.runMode).list() else {
			return usedNetworks
		}

		list.values.forEach { location in
			if let config = try? location.config() {
				config.qualifiedNetworks.forEach { network in
					let name = network.network
					if var vms = usedNetworks[name] {
						vms.append(location.name)
						usedNetworks[name] = vms
					} else {
						usedNetworks[name] = [location.name]
					}
				}
			}
		}

		return usedNetworks
	}

	static func from(name: String, network: BridgedNetwork, referencedNetworks: ReferencedNetworks) -> LXDNetwork {
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
			usedBy: referencedNetworks[name] ?? []
		)
	}
}

// MARK: - Identity List Metadata

/// Encodes/decodes as a plain JSON array of LXDIdentity.
struct LXDIdentityListMetadata: Content {
	var items: [LXDIdentity]

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(items)
	}

	init(from decoder: Decoder) throws {
		items = try decoder.singleValueContainer().decode([LXDIdentity].self)
	}

	init(_ items: [LXDIdentity]) {
		self.items = items
	}
}

extension LXDResponse where T == LXDIdentityListMetadata {
	static func syncIdentities(_ items: [LXDIdentity]) -> LXDResponse<LXDIdentityListMetadata> {
		LXDResponse(type: "sync", status: "Success", statusCode: 200, operation: "", errorCode: 0, error: "", metadata: LXDIdentityListMetadata(items))
	}
}

// MARK: - Identity Models

struct LXDIdentity: Content {
	var authenticationMethod: String
	var type: String
	var id: String
	var name: String
	var groups: [String]
	var tlsCertificate: String

	enum CodingKeys: String, CodingKey {
		case type, id, name, groups
		case authenticationMethod = "authentication_method"
		case tlsCertificate = "tls_certificate"
	}
}

struct LXDIdentityPut: Content {
	var groups: [String]?
	var tlsCertificate: String?

	enum CodingKeys: String, CodingKey {
		case groups
		case tlsCertificate = "tls_certificate"
	}
}

/// Body for POST /1.0/auth/identities/tls
struct LXDIdentitiesTLSPost: Content {
	var name: String
	var trustToken: String?
	var token: Bool?
	var certificate: String?
	var groups: [String]?

	enum CodingKeys: String, CodingKey {
		case name, token, certificate, groups
		case trustToken = "trust_token"
	}
}

/// Body for POST /1.0/auth/identities/bearer
struct LXDIdentitiesBearerPost: Content {
	var type: String
	var name: String
	var groups: [String]?
}

struct LXDIdentityBearerToken: Content {
	var token: String
}

struct LXDIdentityBearerTokenPost: Content {
	var expiry: String?
}

/// Returned by GET /1.0/auth/identities/current
struct LXDIdentityInfo: Content {
	var authenticationMethod: String
	var type: String
	var id: String
	var name: String
	var groups: [String]
	var tlsCertificate: String
	var effectiveGroups: [String]
	var effectivePermissions: [LXDAuthGroupPermission]
	var fineGrained: Bool
	var expiresAt: String?

	enum CodingKeys: String, CodingKey {
		case type, id, name, groups
		case authenticationMethod = "authentication_method"
		case tlsCertificate = "tls_certificate"
		case effectiveGroups = "effective_groups"
		case effectivePermissions = "effective_permissions"
		case fineGrained = "fine_grained"
		case expiresAt = "expires_at"
	}
}

// MARK: - Auth Group Models

struct LXDAuthGroupPermission: Content {
	var entityType: String
	var url: String
	var entitlement: String

	enum CodingKeys: String, CodingKey {
		case entityType = "entity_type"
		case url
		case entitlement
	}
}

struct LXDAuthGroupIdentities: Content {
	var oidc: [String]
	var tls: [String]
}

struct LXDAuthGroup: Content {
	var name: String
	var description: String
	var permissions: [LXDAuthGroupPermission]
	var identities: LXDAuthGroupIdentities
	var identityProviderGroups: [String]

	enum CodingKeys: String, CodingKey {
		case name, description, permissions, identities
		case identityProviderGroups = "identity_provider_groups"
	}
}

/// Body for POST /1.0/auth/groups (create) and PUT/PATCH (update).
struct LXDAuthGroupWriteRequest: Content {
	var name: String?
	var description: String?
	var permissions: [LXDAuthGroupPermission]?
	var identities: LXDAuthGroupIdentities?
	var identityProviderGroups: [String]?

	enum CodingKeys: String, CodingKey {
		case name, description, permissions, identities
		case identityProviderGroups = "identity_provider_groups"
	}
}

// MARK: - Image List Metadata

/// Encodes/decodes as a plain JSON array of LXDImage.
struct LXDImageListMetadata: Content {
	var items: [LXDImage]

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(items)
	}

	init(from decoder: Decoder) throws {
		items = try decoder.singleValueContainer().decode([LXDImage].self)
	}

	init(_ items: [LXDImage]) {
		self.items = items
	}
}

extension LXDResponse where T == LXDImageListMetadata {
	static func syncImages(_ items: [LXDImage]) -> LXDResponse<LXDImageListMetadata> {
		LXDResponse(type: "sync", status: "Success", statusCode: 200, operation: "", errorCode: 0, error: "", metadata: LXDImageListMetadata(items))
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

// MARK: - Certificate List Metadata

/// Encodes/decodes as a plain JSON array of LXDCertificate.
struct LXDCertificateListMetadata: Content {
	var items: [LXDCertificate]

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(items)
	}

	init(from decoder: Decoder) throws {
		items = try decoder.singleValueContainer().decode([LXDCertificate].self)
	}

	init(_ items: [LXDCertificate]) {
		self.items = items
	}
}

extension LXDResponse where T == LXDCertificateListMetadata {
	static func syncCertificates(_ items: [LXDCertificate]) -> LXDResponse<LXDCertificateListMetadata> {
		LXDResponse(type: "sync", status: "Success", statusCode: 200, operation: "", errorCode: 0, error: "", metadata: LXDCertificateListMetadata(items))
	}
}

// MARK: - Certificate Models

struct LXDCertificate: Content {
	var name: String
	var type: String
	var restricted: Bool
	var projects: [String]
	var certificate: String
	var fingerprint: String
}

struct LXDCertificatesPost: Content {
	var name: String
	var type: String
	var restricted: Bool
	var projects: [String]?
	var certificate: String?
	var password: String?
	var trustToken: String?
	var token: Bool?

	enum CodingKeys: String, CodingKey {
		case name, type, restricted, projects, certificate, password, token
		case trustToken = "trust_token"
	}
}

struct LXDCertificatePut: Content {
	var name: String?
	var type: String?
	var restricted: Bool?
	var projects: [String]?
	var certificate: String?
}
