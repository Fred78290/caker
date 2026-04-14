import ArgumentParser
import Foundation

public struct StopOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Stop VM(s)"))

	@Flag(help: ArgumentHelp(String(localized: "Force stop")))
	public var force: Bool = false

	@Flag(name: .shortAndLong, help: ArgumentHelp(String(localized: "Stop all VM")))
	public var all: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "VM names to stop")))
	public var names: [String] = []

	public func validate() throws {
		if all {
			if !names.isEmpty {
				throw ValidationError(String(localized: "You cannot specify both --all and VM names."))
			}
		} else if names.isEmpty {
			throw ValidationError(String(localized: "You must specify at least one VM name."))
		}
	}

	public init() {
	}
}
