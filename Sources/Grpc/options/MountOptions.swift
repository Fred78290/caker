import ArgumentParser
import Foundation

public struct MountOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Mount directory share into VM"))

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp(String(localized: "Additional directory shares"), discussion: String(localized: "mount_help")))
	public var mounts: DirectorySharingAttachments = []

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String = String.empty

	public init() {
	}

	public func validate() throws {
		if name.contains("/") {
			throw ValidationError(String(localized: "\(name) should be a local name"))
		}
	}
}
