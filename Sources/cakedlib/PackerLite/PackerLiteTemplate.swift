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

public struct ParsedPackerLiteTemplate: Sendable {
	public var bootTimeout: TimeInterval
	public var ignoreIP: Bool?
	public var installAgent: Bool? = true
	public var preBootCommand: BootCommandSteps
	public var bootCommand: BootCommandSteps
	public var postBootCommand: [String]?

	init(bootTimeout: TimeInterval, ignoreIP: Bool?, installAgent: Bool?, preBootCommand: BootCommandSteps, bootCommand: BootCommandSteps, postBootCommand: [String]?) {
		self.bootTimeout = bootTimeout
		self.ignoreIP = ignoreIP
		self.installAgent = installAgent
		self.postBootCommand = postBootCommand
		self.preBootCommand = preBootCommand
		self.bootCommand = bootCommand
	}
}

public struct PackerLiteTemplate: Codable, Sendable {
	private var resolvedBootTimeout: TimeInterval { Self.parseDuration(bootTimeout, default: 45 * 60) }
	private var variables: [String: String]?
	private var requiredVariables: [String]?
	public var ignoreIP: Bool?
	public var installAgent: Bool? = true
	private var bootTimeout: String?
	private var preBootCommand: [Command]?
	private var bootCommand: [Command]?
	public var postBootCommand: [String]?

	public struct Command: Codable, Sendable {
		public var title: String
		public var commands: [String]
	}

	enum CodingKeys: String, CodingKey {
		case variables
		case requiredVariables = "required_variables"
		case ignoreIP = "ignore_ip"
		case installAgent = "install_agent"
		case bootTimeout = "boot_timeout"
		case bootCommand = "boot_command"
		case preBootCommand = "pre_boot_command"
		case postBootCommand = "post_boot_command"
	}

	public init(
		variables: [String: String]? = nil,
		requiredVariables: [String]? = nil,
		ignoreIP: Bool = false,
		installAgent: Bool = true,
		bootTimeout: String? = nil,
		bootCommand: [Command]? = nil,
		postBootCommand: [String]? = nil
	) {
		self.variables = variables
		self.requiredVariables = requiredVariables
		self.ignoreIP = ignoreIP
		self.installAgent = installAgent
		self.bootTimeout = bootTimeout
		self.bootCommand = bootCommand
		self.postBootCommand = postBootCommand
	}

	// MARK: Loading
	@MainActor
	public static func load(from content: String, variables overrides: [String: String] = [:]) throws -> ParsedPackerLiteTemplate {
		let template = try YAMLDecoder().decode(PackerLiteTemplate.self, from: content).resolvingVariables(overrides)

		return try template.parse()
	}

	@MainActor
	public static func load(fromFile path: String, variables overrides: [String: String] = [:]) async throws -> ParsedPackerLiteTemplate {
		let content = try String(contentsOfFile: path, encoding: .utf8)

		return try load(from: content, variables: overrides)
	}

	private func parse() throws -> ParsedPackerLiteTemplate {
		let preBootCommandSteps = try parsedBootCommand(bootCommand: preBootCommand)
		let bootCommandSteps = try parsedBootCommand(bootCommand: bootCommand)

		return ParsedPackerLiteTemplate(
			bootTimeout: resolvedBootTimeout,
			ignoreIP: ignoreIP,
			installAgent: installAgent,
			preBootCommand: preBootCommandSteps,
			bootCommand: bootCommandSteps,
			postBootCommand: postBootCommand
		)
	}

	// MARK: Variable substitution

	/// Substitutes every `${var.NAME}` occurrence in each `boot_command` entry, using `overrides`
	/// first and falling back to `variables:` defaults — mirrors Packer's `variable{}` blocks + `-var`.
	///
	/// Callers should pass the VM's actual `username`/`password` (from `CakeConfig.configuredUser`/
	/// `configuredPassword`, itself sourced from `--user`/`--password` or the UI) as overrides here
	/// rather than letting the template declare its own — there is exactly one source of truth for
	/// the account caked creates the VM with.
	private func resolvingVariables(_ overrides: [String: String]) throws -> PackerLiteTemplate {
		var merged = variables ?? [:]

		for (name, value) in overrides {
			merged[name] = value
		}

		if let requiredVariables = self.requiredVariables {
			for name in requiredVariables where merged[name] == nil {
				throw PackerLiteTemplateError.requiredVariableNotFound(variable: name)
			}
		}
		var resolved = self

		resolved.preBootCommand = preBootCommand?.map {
			Self.substitute($0, variables: merged)
		}

		resolved.bootCommand = bootCommand?.map {
			Self.substitute($0, variables: merged)
		}

		return resolved
	}

	private static func substitute(_ cmd: Command, variables: [String: String]) -> Command {
		var result = cmd

		for (name, value) in variables {
			result.commands = result.commands.map {
				$0.replacingOccurrences(of: "${var.\(name)}", with: value)
			}
		}

		return result
	}

	// MARK: boot_command parsing

	/// Parses every `boot_command` entry, wrapping parse failures with the offending index/string.
	private func parsedBootCommand(bootCommand: [Command]?) throws -> BootCommandSteps {
		var parsed: [BootCommandStep] = []

		guard let bootCommand else {
			return parsed
		}

		for command in bootCommand {
			do {
				let step = try BootCommand.parse(command)
				parsed.append(step)
			} catch {
				throw PackerLiteTemplateError.invalidBootCommand(command: command, underlying: error)
			}
		}

		return parsed
	}

	// MARK: Duration parsing

	/// Parses durations like "30s", "45m", "1h", or a bare number (seconds).
	private static func parseDuration(_ text: String?, default defaultValue: TimeInterval) -> TimeInterval {
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
	case invalidBootCommand(command: PackerLiteTemplate.Command, underlying: Error)
	case requiredVariableNotFound(variable: String)

	public var errorDescription: String? {
		switch self {
			case .invalidBootCommand(let command, let underlying):
			return "boot_command[\(command.title)] (\"\(command.commands.joined(separator: ", "))\") failed to parse: \(underlying.localizedDescription)"
		case .requiredVariableNotFound(variable: let variable):
			return "required variable \"\(variable)\" not found"
		}
	}
}
