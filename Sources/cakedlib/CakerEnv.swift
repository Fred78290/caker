//
//  CakerEnv.swift
//  CakedLib
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import Foundation
import GRPCLib
import Yams

// MARK: - Per-VM specification

/// Configuration for a single VM — used both as top-level fields (single-VM mode)
/// and as entries in the `vms:` map (multi-VM mode).
public struct CakerEnvVM: Codable {
	public var image: String?
	public var cpus: UInt16?
	public var memory: UInt64?
	public var disk: UInt64?
	public var user: String?
	public var password: String?
	public var ports: [String]?
	public var mounts: [String]?
	public var networks: [String]?
	public var cloudInit: String?
	public var autostart: Bool?
	public var nested: Bool?
	/// Names of VMs (within the same `.cakerenv`) that must be started before this one.
	public var dependsOn: [String]?

	enum CodingKeys: String, CodingKey {
		case image, cpus, memory, disk, user, password, ports, mounts, networks
		case cloudInit = "cloud-init"
		case autostart, nested
		case dependsOn = "depends-on"
	}

	public init() {}

	/// Convert to `BuildOptions`. Writes any inline `cloud-init` to a temp file.
	public func toBuildOptions(name: String) throws -> BuildOptions {
		var opts = BuildOptions()
		opts.name = name
		opts.image = image ?? defaultUbuntuImage
		opts.cpu = cpus ?? 2
		opts.memory = memory ?? 2048
		opts.diskSize = disk ?? 10
		opts.user = user ?? "admin"
		opts.password = password
		opts.autostart = autostart ?? false
		opts.nested = nested ?? false

		if let ports {
			opts.forwardedPorts = ports.compactMap { TunnelAttachement(argument: $0) }
		}
		if let mounts {
			opts.mounts = try mounts.compactMap { try DirectorySharingAttachment(parseFrom: $0) }
		}
		if let networks {
			opts.networks = try networks.compactMap { try BridgeAttachement(parseFrom: $0) }
		}
		if let cloudInit {
			let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
				.appendingPathComponent("cakerenv-cloud-init-\(UUID().uuidString).yaml")
			try cloudInit.write(to: tempFile, atomically: true, encoding: .utf8)
			opts.userData = tempFile.path
		}
		return opts
	}
}

// MARK: - Environment file

/// Declarative multi-VM environment read from a `.cakerenv` YAML file.
///
/// **Single-VM mode** (backwards-compatible): place all fields at the top level.
/// **Multi-VM mode**: use a `vms:` map with named entries, each a `CakerEnvVM`.
///
/// ```yaml
/// # Single-VM
/// name: myapp
/// image: ubuntu:24.04
/// cpus: 2
///
/// # Multi-VM
/// vms:
///   app:
///     image: ubuntu:24.04
///   db:
///     image: ubuntu:24.04
///     depends-on: [app]
/// ```
public struct CakerEnv: Codable {
	public static let filename = ".cakerenv"

	// Single-VM top-level fields (also used as backwards-compat path)
	public var name: String?
	public var image: String?
	public var cpus: UInt16?
	public var memory: UInt64?
	public var disk: UInt64?
	public var user: String?
	public var password: String?
	public var ports: [String]?
	public var mounts: [String]?
	public var networks: [String]?
	public var cloudInit: String?
	public var autostart: Bool?
	public var nested: Bool?

	/// Multi-VM map. When present, the top-level fields above are ignored.
	public var vms: [String: CakerEnvVM]?

	enum CodingKeys: String, CodingKey {
		case name, image, cpus, memory, disk, user, password, ports, mounts, networks
		case cloudInit = "cloud-init"
		case autostart, nested, vms
	}

	public init() {}

	// MARK: Load

	public static func load(
		from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
	) throws -> CakerEnv {
		let file = directory.appendingPathComponent(CakerEnv.filename)
		guard FileManager.default.fileExists(atPath: file.path) else {
			throw ServiceError(String(localized: "No \(CakerEnv.filename) found in \(directory.path)"))
		}
		return try load(fromFile: file.path)
	}

	public static func load(fromFile path: String) throws -> CakerEnv {
		let content = try String(contentsOfFile: path, encoding: .utf8)
		return try YAMLDecoder().decode(CakerEnv.self, from: content)
	}

	// MARK: Single-VM backwards compat

	/// Effective VM name in single-VM mode. Priority: override > `name:` field > directory name.
	public func resolvedName(override: String? = nil) -> String {
		if let override, !override.isEmpty { return override }
		if let name, !name.isEmpty { return name }
		return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
	}

	/// Backwards-compat wrapper: convert top-level fields to `BuildOptions`.
	public func toBuildOptions(name: String) throws -> BuildOptions {
		return try singleVMSpec().toBuildOptions(name: name)
	}

	// MARK: Multi-VM

	/// All VM entries, optionally filtered by name.
	/// In single-VM mode (no `vms:` key) returns one entry derived from top-level fields.
	public func resolvedVMs(nameOverride: String? = nil, filter: [String] = []) -> [(name: String, vm: CakerEnvVM)] {
		if let vms, !vms.isEmpty {
			let keys: [String] = filter.isEmpty ? vms.keys.sorted() : filter
			return keys.compactMap { k in vms[k].map { (k, $0) } }
		}
		let singleName = resolvedName(override: nameOverride)
		if !filter.isEmpty && !filter.contains(singleName) { return [] }
		return [(singleName, singleVMSpec())]
	}

	/// VM entries sorted by `depends-on` declarations (topological order).
	/// Throws on cycles or references to undefined VMs.
	public func startOrder(nameOverride: String? = nil, filter: [String] = []) throws -> [(name: String, vm: CakerEnvVM)] {
		let entries = resolvedVMs(nameOverride: nameOverride, filter: filter)
		guard entries.count > 1 else { return entries }

		var result: [(name: String, vm: CakerEnvVM)] = []
		var visited = Set<String>()
		var visiting = Set<String>()

		func visit(_ vmName: String, _ vmSpec: CakerEnvVM) throws {
			if visited.contains(vmName) { return }
			guard !visiting.contains(vmName) else {
				throw ServiceError(String(localized: "Circular dependency involving '\(vmName)'"))
			}
			visiting.insert(vmName)
			for dep in vmSpec.dependsOn ?? [] {
				guard let depSpec = vms?[dep] else {
					throw ServiceError(String(localized: "'\(vmName)' depends on '\(dep)' which is not defined in \(CakerEnv.filename)"))
				}
				try visit(dep, depSpec)
			}
			visiting.remove(vmName)
			visited.insert(vmName)
			result.append((vmName, vmSpec))
		}

		for (n, vm) in entries { try visit(n, vm) }
		return result
	}

	/// Reverse of `startOrder` — use this for graceful shutdown.
	public func downOrder(nameOverride: String? = nil, filter: [String] = []) throws -> [(name: String, vm: CakerEnvVM)] {
		return try startOrder(nameOverride: nameOverride, filter: filter).reversed()
	}

	// MARK: Private

	private func singleVMSpec() -> CakerEnvVM {
		var vm = CakerEnvVM()
		vm.image = image
		vm.cpus = cpus
		vm.memory = memory
		vm.disk = disk
		vm.user = user
		vm.password = password
		vm.ports = ports
		vm.mounts = mounts
		vm.networks = networks
		vm.cloudInit = cloudInit
		vm.autostart = autostart
		vm.nested = nested
		return vm
	}

	// MARK: Template

	public static var template: String {
		"""
		# .cakerenv — Caker dev environment definition
		# Run `cakectl up` to start all VMs (or a specific one: `cakectl up app`).
		# Run `cakectl down` to stop them. `cakectl init` regenerates this file.
		#
		# ── Single-VM mode (shorthand) ──────────────────────────────────────────
		# Place all fields at the top level when you only need one VM.
		#
		# name: myapp          # defaults to the current directory name
		# image: ubuntu:24.04
		# cpus: 2
		# memory: 2048         # MB
		# disk: 20             # GiB
		# user: ubuntu
		# password: ubuntu
		# ports:
		#   - "3000:3000"
		# mounts:
		#   - ".:/workspace"
		# networks:
		#   - nat
		# cloud-init: |
		#   packages:
		#     - nodejs
		#
		# ── Multi-VM mode (docker-compose style) ─────────────────────────────────
		# Use a `vms:` map to define several VMs. Each is started in depends-on
		# order; `cakectl down` stops them in reverse order.

		vms:
		  app:
		    image: ubuntu:24.04
		    cpus: 2
		    memory: 2048   # MB
		    disk: 20       # GiB
		    user: ubuntu
		    password: ubuntu
		    ports:
		      - "3000:3000"
		    mounts:
		      - ".:/workspace"
		    networks:
		      - nat
		    # cloud-init: |
		    #   packages:
		    #     - nodejs
		    #     - git

		  database:
		    image: ubuntu:24.04
		    cpus: 2
		    memory: 4096
		    disk: 40
		    user: ubuntu
		    password: ubuntu
		    networks:
		      - nat
		    depends-on:
		      - app
		"""
	}
}
