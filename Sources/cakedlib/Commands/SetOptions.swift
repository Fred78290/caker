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

			if keyValue.count == 2 {
				try config.set(String(keyValue[1]))
			} else {
				print("\(String(localized: "Value for")) \(String(keyValue[0])):", terminator: " ")

				try config.set(readLine())
			}
		}
	}
}
