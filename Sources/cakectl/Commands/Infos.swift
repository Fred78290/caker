import ArgumentParser
import Foundation
import GRPCLib
import GRPC
import TextTable
import CakeAgentLib

extension InfoReply {
	static func with(infos: Caked_InfoReply) -> InfoReply{
		var memory: InfoReply.MemoryInfo? = nil

		memory = infos.hasMemory ? InfoReply.MemoryInfo.with {
			let memory = infos.memory

			$0.total = memory.total
			$0.free = memory.hasFree ? memory.free : nil
			$0.used = memory.hasUsed ? memory.used : nil
		} : nil

		return InfoReply.with {
			$0.name = infos.name
			$0.version = infos.hasVersion ? infos.version : nil
			$0.uptime = infos.hasUptime ? infos.uptime : nil
			$0.cpuCount = infos.cpuCount
			$0.ipaddresses = infos.ipaddresses
			$0.osname = infos.osname
			$0.hostname = infos.hasHostname ? infos.hostname : nil
			$0.release = infos.hasRelease ? infos.release : nil
			$0.status = .init(rawValue: infos.status) ?? .unknown
			$0.mounts = infos.mounts
			$0.memory = memory
		}
	}
}

struct Infos: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "infos", abstract: "Get info for VM")

	@OptionGroup var options: Client.Options

	@Option(name: .shortAndLong, help: "Output format: text or json")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: String

	func run(client: Caked_ServiceNIOClient, arguments: [String], callOptions: CallOptions?) throws -> Caked_Reply {
		let infos = try client.info(Caked_InfoRequest(command: self), callOptions: callOptions).response.wait()

		return Caked_Reply.with {
			if format == .json {
				$0.output = format.renderSingle(style: Style.grid, uppercased: true, InfoReply.with(infos: infos))
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
