//
//  VNC.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/03/2026.
//
import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakedLib
import CakeAgentLib

struct VNC: AsyncGrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vnc", abstract: "Start a VNC client for a running VM")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: String

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let result = try client.info(name: self.name, includeConfig: true).vms.status

		let infos = result.infos
		let screenSize = result.infos.hasScreenSize ? ViewSize(result.infos.screenSize) : ViewSize(result.config.display)

		guard let vncURL = VNCServer.findHostMatching(urls: infos.vncURL) else {
			return "VM \(self.name) does not have a VNC connection"
		}

		try await VNCApp.startVncClient(name: self.name,
										config: CakedConfiguration(result.config),
										vncURL: vncURL,
										screenSize: screenSize,
										isDebugLoggingEnabled: self.options.logLevel > .info,
										vmStatus: {
			if let result = try? client.info(name: self.name, includeConfig: true).vms.status {
				if result.infos.status == .running || result.infos.status == .agentReady {
					return .running
				}
			}

			return .stopped
		}, screenSizeAction: { screenSize in
			_ = try? client.setScreenSize(.with {
				$0.name = self.name
				$0.screenSize = .with {
					$0.width = Int32(screenSize.width)
					$0.height = Int32(screenSize.height)
				}
			}).response.wait()
		})

		return ""
	}
}
