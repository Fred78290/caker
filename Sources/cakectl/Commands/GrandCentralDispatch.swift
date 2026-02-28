//
//  GrandCentralDispatch.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/02/2026.
//
import ArgumentParser
import Dispatch
import GRPC
import GRPCLib
import TextTable
import CakeAgentLib

struct CurrentUsage: Codable {
	let name: String
	let memory: InfoReply.MemoryInfo?
	let cpuCount: Int32
	let cpuInfos: CpuInformations?
	
	init(_ name: String, from infos: Caked_CurrentUsageReply) {
		self.name = name
		self.cpuCount = infos.cpuCount

		if infos.hasMemory {
			self.memory = .with {
				let m = infos.memory
				
				$0.total = UInt64(m.total)
				$0.free = UInt64(m.free)
				$0.used = UInt64(m.used)
			}
		} else {
			self.memory = nil
		}

		if infos.hasCpuInfos {
			let cpuInfos = infos.cpuInfos

			self.cpuInfos = CpuInformations(totalUsagePercent: cpuInfos.totalUsagePercent,
											user: cpuInfos.user,
											system: cpuInfos.system,
											idle: cpuInfos.idle,
											iowait: cpuInfos.iowait,
											irq: cpuInfos.irq,
											softirq: cpuInfos.softirq,
											steal: cpuInfos.steal,
											guest: cpuInfos.guest,
											guestNice: cpuInfos.guestNice,
											cores: cpuInfos.cores.map { core in
												CpuInformations.CpuCoreInfo(coreID: core.coreID,
																			usagePercent: core.usagePercent,
																			user: core.user,
																			system: core.system,
																			idle: core.idle,
																			iowait: core.iowait,
																			irq: core.irq,
																			softirq: core.softirq,
																			steal: core.steal,
																			guest: core.guest,
																			guestNice: core.guestNice)
			})
		} else {
			self.cpuInfos = nil
		}
	}
}

struct ShortCurrentUsage: Codable {
	let name: String
	let cpuCount: Int32
	let cpuUsage: Double
	
	init(_ name: String, from infos: Caked_CurrentUsageReply) {
		self.name = name
		self.cpuCount = infos.cpuCount
		self.cpuUsage = infos.cpuInfos.totalUsagePercent
	}
}

struct GrandCentralDispatch: GrpcParsableCommand {
	public static let configuration: CommandConfiguration = CommandConfiguration(commandName: "gcd", abstract: "Start the Grand Central Dispatch")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Flag(help: "Output format")
	var format: Format = .text

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let stream = client.grandCentralDispatcher(.init(), callOptions: .init(timeLimit: .none)) { reply in
			print("\u{001B}[2J\u{001B}[H")

			reply.status.statuses.forEach { status in
				switch status.message {
				case .failure(let message):
					print(self.format.renderSingle("Error: \(message)"))
				case .status(let status):
					print(self.format.renderSingle("Status: \(status.description)"))
				case .screenshot(let png):
					print(self.format.renderSingle("Screenshot: \(png)"))
				case .usage(let usage):
					switch self.format {
						case .text:
						print(self.format.renderSingle(ShortCurrentUsage(status.name, from: usage)))
						case .json:
						print(self.format.renderSingle(CurrentUsage(status.name, from: usage)))
					}
				default:
					break
				}
			}
		}

		_ = try stream.subchannel.wait()

		return ""
	}
	
}
