import ArgumentParser
import Foundation

public struct MountOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(abstract: String(localized: "Mount directory share into VM"))

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	public var name: String = String.empty

	@Option(name: [.customLong("mount"), .customShort("v")], help: ArgumentHelp(String(localized: "Additional directory shares"), discussion: mount_help))
	public var mounts: DirectorySharingAttachments = []

	public init() {
	}

	public func validate() throws {
		if name.contains("/") {
			throw ValidationError(String(localized: "\(name) should be a local name"))
		}
	}
}
