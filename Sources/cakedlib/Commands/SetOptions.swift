//
//  SetOptions.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/04/2026.
//
import Foundation
import Security
import ArgumentParser
import GRPCLib

public struct SetOptions: ParsableCommand {
	public static let configuration = CommandConfiguration(commandName: "set", abstract: String(localized: "Set, to the given value, the configuration setting corresponding to the given key"))

	@Argument(
		help: ArgumentHelp(
			String(localized: "keyval"),
			discussion: String(
				localized: "A key, or a key-value pair. The key specifies a path to the setting to configure.\nThe value is its intended value. If only the key is given, the value will be prompted for.")))

	public var arguments: [String] = []

	public init() {

	}

	public func validate() throws {
		guard arguments.isEmpty == false else {
			throw ValidationError(String(localized: "Need exactly one key-value pair (in <key>=<value> form)."))
		}
	}

	public func run() throws {
		try arguments.forEach {
			let keyValue = $0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

			guard let config = CakedKeyConfig(rawValue: String(keyValue[0])) else {
				throw ValidationError(String(localized: "Invalid key"))
			}

			let value: String?

			if keyValue.count == 2 {
				value = String(keyValue[1])
			} else {
				print("\(String(localized: "Value for")) \(String(keyValue[0])):", terminator: " ")

				value = readLine()
			}

			// Store a boolean key as a `Bool`, the type Caker.app's `@AppStorage` reads.
			if config.isBoolean, let value {
				guard let flag = CakedKeyConfig.parseBool(value) else {
					throw ValidationError(String(format: String(localized: "Invalid value '%@' for %@: expected true or false"), value, config.rawValue))
				}

				config.set(flag)
			} else {
				config.set(value)
			}
		}
	}
}
