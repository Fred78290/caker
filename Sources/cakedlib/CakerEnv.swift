//
//  CakerEnv.swift
//  CakedLib
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import Foundation
import GRPCLib
import Yams

/// Declarative VM definition read from a `.cakerenv` YAML file.
///
/// Example `.cakerenv`:
/// ```yaml
/// name: myapp
/// image: ubuntu:24.04
/// cpus: 4
/// memory: 8192
/// disk: 20
/// user: ubuntu
/// password: ubuntu
/// ports:
///   - "3000:3000"
///   - "5432:5432/tcp"
/// mounts:
///   - ".:/workspace"
/// networks:
///   - nat
/// cloud-init: |
///   packages:
///     - nodejs
///     - git
/// ```
public struct CakerEnv: Codable {
	public static let filename = ".cakerenv"

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

	enum CodingKeys: String, CodingKey {
		case name, image, cpus, memory, disk, user, password
		case ports, mounts, networks
		case cloudInit = "cloud-init"
		case autostart, nested
	}

	public init() {}

	/// Load `.cakerenv` from `directory` (defaults to the current working directory).
	public static func load(
		from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
	) throws -> CakerEnv {
		let file = directory.appendingPathComponent(CakerEnv.filename)
		guard FileManager.default.fileExists(atPath: file.path) else {
			throw ServiceError(String(localized: "No \(CakerEnv.filename) found in \(directory.path)"))
		}
		return try load(fromFile: file.path)
	}

	/// Load from an explicit file path.
	public static func load(fromFile path: String) throws -> CakerEnv {
		let content = try String(contentsOfFile: path, encoding: .utf8)
		return try YAMLDecoder().decode(CakerEnv.self, from: content)
	}

	/// Resolve the effective VM name.
	/// Priority: explicit `override` > `name` field in YAML > current directory name.
	public func resolvedName(override: String? = nil) -> String {
		if let override, !override.isEmpty { return override }
		if let name, !name.isEmpty { return name }
		return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent
	}

	/// Convert this env definition to a `BuildOptions` value.
	/// Writes any inline `cloud-init` content to a temp file.
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

	/// A commented YAML template suitable for writing a new `.cakerenv`.
	public static var template: String {
		"""
		# .cakerenv — Caker dev environment definition
		# Run `cakectl up` in this directory to start the VM.
		# Run `cakectl down` to stop it. `cakectl init` regenerates this file.

		# VM name (optional — defaults to the current directory name)
		# name: myapp

		# Cloud image URL or registry reference (required)
		image: ubuntu:24.04

		# Resources
		cpus: 2
		memory: 2048   # MB
		disk: 20       # GiB

		# Login credentials
		user: ubuntu
		password: ubuntu

		# Port forwarding — docker syntax: [hostPort:]guestPort[/proto]
		# ports:
		#   - "3000:3000"
		#   - "5432:5432/tcp"

		# VirtioFS directory shares — host:guest or host (uses same path in guest)
		# mounts:
		#   - ".:/workspace"

		# Network interfaces: nat, host, bridged, or a named network
		networks:
		  - nat

		# Inline cloud-init user-data (or leave blank to skip cloud-init)
		# cloud-init: |
		#   packages:
		#     - nodejs
		#     - git
		#   runcmd:
		#     - cd /workspace && npm install

		# autostart: false
		# nested: false
		"""
	}
}
