import Foundation
import ArgumentParser

public struct MountOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: "Mount directory share into VM")

	@Argument(help: "VM name")
	public var name: String = ""

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Additional directory shares", discussion: mount_help))
	public var mounts: [DirectorySharingAttachment] = []

	public init() {
	}

	public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}
	}
}
