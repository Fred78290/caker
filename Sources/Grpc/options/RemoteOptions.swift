import Foundation
import ArgumentParser

public struct RemoteAddOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "add", abstract: "Add new remote servers")

	public init() {
	}
}

public struct RemoteDeleteOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "delete", abstract: "Remove remotes")

	public init() {
	}
}

public struct RemoteListOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "list", abstract: "List the available remotes")

	public init() {
	}
}
