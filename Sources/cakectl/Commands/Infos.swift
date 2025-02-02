import ArgumentParser
import Foundation
import GRPCLib
import GRPC
import TextTable

struct Infos: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@OptionGroup var options: Client.Options

	@Option(help: "Output format: text or json")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		let infos = try client.info(Caked_InfoRequest(command: self), callOptions: callOptions).response.wait()

		return Caked_Reply.with {
			if format == .json {
				let reply = FullInfoReply(
					name: name,
					version: infos.version,
					uptime: infos.uptime,
					memory: infos.hasMemory ? FullInfoReply.MemoryInfo(total: infos.memory.total,
					                                                   free: infos.memory.free,
					                                                   used: infos.memory.used) : nil,
					cpuCount: infos.cpuCount,
					ipaddresses: infos.ipaddresses,
					osname: infos.osname,
					hostname: infos.hostname,
					release: infos.release)
				$0.output = format.renderSingle(style: Style.grid, uppercased: true, reply)
			} else {
				let reply = GRPCLib.ShortInfoReply(name: name,
				                                   ipaddresses: infos.ipaddresses,
				                                   cpuCount: infos.cpuCount,
				                                   memory: infos.hasMemory ? infos.memory.total : 0)
				$0.output = format.renderSingle(style: Style.grid, uppercased: true, reply)
			}
		}
	}
}
