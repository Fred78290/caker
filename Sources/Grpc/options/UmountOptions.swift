import ArgumentParser
import Foundation

public struct UmountOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "umount", abstract: String(localized: "Unmount a directory share from a VM"))

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String = String.empty

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp(String(localized: "Give host path to umount"), discussion: String(localized: "Remove directory shares. If omitted all mounts will be removed from the named vm")))
	public var mounts: DirectorySharingAttachments = []

	public init() {
	}

	public func validate() throws {
		if name.contains("/") {
			throw ValidationError(String(localized: "\(name) should be a local name"))
		}
	}
}
