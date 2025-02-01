import ArgumentParser
import Foundation
import GRPCLib
import GRPC

struct Exec: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "exec", abstract: "Run a shell command in a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String

	@Argument(help: "Command to execute")
	var arguments: [String]

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		let response = try client.execute(Caked_ExecuteRequest(command: self), callOptions: callOptions).response.wait()

		if response.hasError {
			return Caked_Reply.with {
				$0.error = Caked_Error.with {
					$0.code = response.exitCode
					$0.reason = String(data: response.error, encoding: .utf8) ?? ""
				}
			}
		} else {
			return Caked_Reply.with {
				$0.output = String(data: response.output, encoding: .utf8) ?? ""
			}
		}
	}
}
