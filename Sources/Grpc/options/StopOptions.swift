import Foundation
import ArgumentParser

public struct StopOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: "Stop VM(s)")
	
	@Argument(help: "VM names to stop")
	public var names: [String] = []
	
	@Flag(help: "Force stop")
	public var force: Bool = false
	
	@Flag(name: .shortAndLong, help: "Stop all VM")
	public var all: Bool = false
	
	public func validate() throws {
		if all {
			if !names.isEmpty {
				throw ValidationError("You cannot specify both --all and VM names.")
			}
		} else if names.isEmpty {
			throw ValidationError("You must specify at least one VM name.")
		}
	}
	
	public init() {
	}
}
