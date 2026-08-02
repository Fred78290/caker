//
//  PackerLiteTemplate.swift
//  CakedLib
//
//  A minimal YAML template format for unattended macOS Setup Assistant provisioning,
//  modeled after the boot_command concept used by Packer's cirruslabs/packer-plugin-tart,
//  but parsed and driven natively by caked instead of requiring the external packer binary.
//

import Foundation
import Yams

public struct PackerLiteTemplate: Codable, Sendable {
	public var variables: [String: String]?
	public var createGraceTime: String?
	public var bootTimeout: String?
	public var bootCommand: [String]?

	enum CodingKeys: String, CodingKey {
		case variables
		case createGraceTime = "create_grace_time"
		case bootTimeout = "boot_timeout"
		case bootCommand = "boot_command"
	}

	public init(
		variables: [String: String]? = nil,
		createGraceTime: String? = nil,
		bootTimeout: String? = nil,
		bootCommand: [String]? = nil
	) {
		self.variables = variables
		self.createGraceTime = createGraceTime
		self.bootTimeout = bootTimeout
		self.bootCommand = bootCommand
	}

	public var resolvedCreateGraceTime: TimeInterval { Self.parseDuration(createGraceTime, default: 30) }
	public var resolvedBootTimeout: TimeInterval { Self.parseDuration(bootTimeout, default: 45 * 60) }

	// MARK: Loading

	public static func load(from content: String, variables overrides: [String: String] = [:]) throws -> PackerLiteTemplate {
		let template = try YAMLDecoder().decode(PackerLiteTemplate.self, from: content)

		return template.resolvingVariables(overrides)
	}

	public static func load(fromFile path: String, variables overrides: [String: String] = [:]) throws -> PackerLiteTemplate {
		let content = try String(contentsOfFile: path, encoding: .utf8)

		return try load(from: content, variables: overrides)
	}

	// MARK: Variable substitution

	/// Substitutes every `${var.NAME}` occurrence in each `boot_command` entry, using `overrides`
	/// first and falling back to `variables:` defaults — mirrors Packer's `variable{}` blocks + `-var`.
	///
	/// Callers should pass the VM's actual `username`/`password` (from `CakeConfig.configuredUser`/
	/// `configuredPassword`, itself sourced from `--user`/`--password` or the UI) as overrides here
	/// rather than letting the template declare its own — there is exactly one source of truth for
	/// the account caked creates the VM with.
	public func resolvingVariables(_ overrides: [String: String]) -> PackerLiteTemplate {
		var merged = variables ?? [:]

		for (name, value) in overrides {
			merged[name] = value
		}

		var resolved = self

		resolved.bootCommand = bootCommand?.map { Self.substitute($0, variables: merged) }

		return resolved
	}

	private static func substitute(_ text: String, variables: [String: String]) -> String {
		var result = text

		for (name, value) in variables {
			result = result.replacingOccurrences(of: "${var.\(name)}", with: value)
		}

		return result
	}

	// MARK: boot_command parsing

	/// Parses every `boot_command` entry, wrapping parse failures with the offending index/string.
	public func parsedBootCommand() throws -> [[BootCommandStep]] {
		try (bootCommand ?? []).enumerated().map { index, command in
			do {
				return try BootCommand.parse(command)
			} catch {
				throw PackerLiteTemplateError.invalidBootCommand(index: index, command: command, underlying: error)
			}
		}
	}

	// MARK: Duration parsing

	/// Parses durations like "30s", "45m", "1h", or a bare number (seconds).
	static func parseDuration(_ text: String?, default defaultValue: TimeInterval) -> TimeInterval {
		guard let text, text.isEmpty == false else { return defaultValue }

		var digits = ""
		var unit = ""

		for character in text {
			if character.isNumber || character == "." {
				digits.append(character)
			} else {
				unit.append(character)
			}
		}

		guard let value = Double(digits) else { return defaultValue }

		switch unit {
			case "m": return value * 60
			case "h": return value * 3600
			default: return value
		}
	}
}

public enum PackerLiteTemplateError: Error, LocalizedError {
	case invalidBootCommand(index: Int, command: String, underlying: Error)

	public var errorDescription: String? {
		switch self {
			case .invalidBootCommand(let index, let command, let underlying):
				return "boot_command[\(index)] (\"\(command)\") failed to parse: \(underlying.localizedDescription)"
		}
	}
}
