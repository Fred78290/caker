import ArgumentParser
import Foundation

public struct RemoteAddOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "add", abstract: String(localized: "Add new remote servers"))

	public init() {
	}
}

public struct RemoteDeleteOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "delete", abstract: String(localized: "Remove remotes"))

	public init() {
	}
}

public struct RemoteListOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "list", abstract: String(localized: "List the available remotes"),  aliases: ["ls"])

	public init() {
	}
}
