import ArgumentParser
import Foundation

public struct UmountOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "umount", abstract: "Unmount a directory share from a VM")

	@Argument(help: "VM name")
	public var name: String = ""

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp("Give host path to umount", discussion: "Remove directory shares. If omitted all mounts will be removed from the named vm"))
	public var mounts: [DirectorySharingAttachment] = []

	public init() {
	}

	public func validate() throws {
		if name.contains("/") {
			throw ValidationError("\(name) should be a local name")
		}
	}
}
