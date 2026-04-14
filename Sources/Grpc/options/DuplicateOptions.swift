import ArgumentParser
import Foundation

public struct DuplicateOptions: ParsableArguments {
	public static let configuration: CommandConfiguration = CommandConfiguration(abstract: String(localized: "Duplicate a VM to a new name"))

	@Option(name: .shortAndLong, help: ArgumentHelp(String(localized: "Reset mac address")))
	public var resetMacAddress: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "Duplicate vm in foreground"), discussion: String(localized: "This option allow display window of running vm to debug it"), visibility: .hidden))
	public var foreground: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Source VM name")))
	public var from: String

	@Argument(help: ArgumentHelp(String(localized: "Duplicated VM name")))
	public var to: String

	public init() {
	}
}
