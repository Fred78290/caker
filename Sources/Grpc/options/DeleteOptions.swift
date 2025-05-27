import ArgumentParser
import Foundation
import NIOPortForwarding

public struct DeleteOptions: ParsableArguments {
	public static let configuration: CommandConfiguration = CommandConfiguration(abstract: "Delete a VM")

	@Argument(help: "VM names")
	public var names: [String] = []

	@Flag(name: [.short, .long], help: "Delete all VM")
	public var all: Bool = false

	public init() {
	}

	public func validate() throws {
		if all {
			if !names.isEmpty {
				throw ValidationError("You cannot specify both --all and VM names.")
			}
		} else if names.isEmpty {
			throw ValidationError("You must specify at least one VM name.")
		}
	}
}
