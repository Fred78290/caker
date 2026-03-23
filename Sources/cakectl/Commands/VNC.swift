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

struct VNC: GrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vnc", abstract: "Start a VNC client for a running VM")

	@OptionGroup(title: "Client options")
	var options: Client.Options

	@Flag(help: "Output format: text or json")
	var format: Format = .text

	@Argument(help: "VM name")
	var name: String

	@Flag(name: .customLong("vnc-debug"), help: ArgumentHelp("Trace vnc traffic", visibility: .hidden))
	var vncDebug: Bool = false

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		let result = try client.info(name: self.name, includeConfig: true).vms.status

		let infos = result.infos
		let screenSize = result.infos.hasScreenSize ? ViewSize(result.infos.screenSize) : ViewSize(result.config.display)

		guard let vncURL = VNCServer.findHostMatching(urls: infos.vncURL) else {
			return "VM \(self.name) does not have a VNC connection"
		}

		func vmStatus() -> Status {
			if let result = try? client.info(name: self.name, includeConfig: true).vms.status {
				if result.infos.status == .running || result.infos.status == .agentReady {
					return .running
				}
			}

			return .stopped
		}

		func screenSizeAction(_ screenSize: ViewSize) -> Void {
			_ = try? client.setScreenSize(.with {
				$0.name = self.name
				$0.screenSize = .with {
					$0.width = Int32(screenSize.width)
					$0.height = Int32(screenSize.height)
				}
			}).response.wait()
		}

		try VNCApp.startVncClient(name: self.name,
								  config: CakedConfiguration(result.config),
								  vncURL: vncURL,
								  screenSize: screenSize,
								  isDebugLoggingEnabled: vncDebug,
								  vmStatus: vmStatus,
								  screenSizeAction: screenSizeAction)

		return ""
	}
}
