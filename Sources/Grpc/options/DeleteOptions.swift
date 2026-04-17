import ArgumentParser
import Foundation
import NIOPortForwarding

public struct DeleteOptions: ParsableArguments {
	public static let configuration: CommandConfiguration = CommandConfiguration(abstract: String(localized: "Delete a VM"))

	@Flag(name: [.short, .long], help: ArgumentHelp(String(localized: "Delete all VM")))
	public var all: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "VM names")))
	public var names: [String] = []

	public init() {
	}

	public func validate() throws {
		if all {
			if !names.isEmpty {
				throw ValidationError(String(localized: "You cannot specify both --all and VM names."))
			}
		} else if names.isEmpty {
			throw ValidationError(String(localized: "You must specify at least one VM name."))
		}
	}
}
