//
//  GetOptions.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/04/2026.
//

import Foundation
import ArgumentParser
import GRPCLib

public struct GetOptions: ParsableCommand {
	public static let configuration = CommandConfiguration(commandName: "get", abstract: String(localized: "Get the configuration setting corresponding to the given key, or all settings if no key is specified."))

	@Flag(help: ArgumentHelp(String(localized: "Output in raw format. For now, this affects only the representation of empty values (i.e. \"\" instead of \"<empty>\").")))
	public var raw: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "List available settings keys. This outputs the whole list of currently available settings keys, or just <arg>, if provided and a valid key.")))
	public var keys: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "arg"), discussion: String(localized: "Setting key, i.e. path to the intended setting.")))
	public var arguments: [String] = []

	public init() {
		
	}
	
	public static var primaryName: String {
		guard let name = try? CakedKeyConfig.primaryName.get() else {
			return "primary"
		}

		guard name.isEmpty == false else {
			return "primary"
		}

		return name
	}

	public func validate() throws {
		guard self.keys || self.arguments.isEmpty == false else {
			throw ValidationError(String(localized: "Please try again with one setting key or just the `--keys` option for now."))
		}

		try arguments.forEach {
			if CakedKeyConfig(rawValue: $0) == nil {
				throw ValidationError(String(localized: "Unrecognized settings key: \($0)"))
			}
		}
	}

	public func run() throws {
		let values: String

		if self.keys {
			if arguments.isEmpty {
				values = CakedKeyConfig.allCases.map(\.rawValue).joined(separator: "\n")
			} else {
				values = arguments.compactMap {
					if CakedKeyConfig(rawValue: $0) != nil {
						return $0
					}
					
					return nil
				}.joined(separator: "\n")
			}
		} else {
			values = try arguments.compactMap {
				if let config = CakedKeyConfig(rawValue: $0) {
					return config
				}
				return nil
			}.map {
				if let value = try $0.get() {
					return value
				} else {
					return self.raw ? "" : "<empty>"
				}
			}.joined(separator: "\n")
		}

		if values.isEmpty && self.keys == false && self.raw == false {
			print("<empty>")
		} else {
			print(values)
		}
	}
}
