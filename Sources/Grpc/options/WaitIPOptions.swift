import Foundation
import ArgumentParser

public struct WaitIPOptions: ParsableArguments {
	public static let configuration = CommandConfiguration(commandName: "waitip", abstract: "Wait for ip of a running VM")
	
	@Argument(help: "VM name")
	public var name: String
	
	@Option(help: ArgumentHelp("Max time to wait for IP", valueName: "seconds"))
	public var wait: Int = 0
	
	public init() {
	}
}
