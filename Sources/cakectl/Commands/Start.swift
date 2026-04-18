import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

struct Start: GrpcParsableCommand {
	static let configuration = CommandConfiguration(abstract: String(localized: "Start an existing VM"))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(help: ArgumentHelp(String(localized: "Max time to wait for IP"), valueName: "seconds"))
	var waitIPTimeout = 180

	@Flag(name: [.customLong("recovery")], help: ArgumentHelp(String(localized: "Launch vm in recovery mode"), discussion: String(localized: "This option allows starting the MacOS VM in recovery mode")))
	var recoveryMode: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		return self.options.format.render(try client.start(Caked_StartRequest(command: self), callOptions: callOptions).response.wait().vms.started)
	}
}
