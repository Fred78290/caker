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
import NIO

struct VNC: AsyncGrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vnc", abstract: String(localized: "Start a VNC client for a running VM"))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Flag(name: .customLong("vnc-debug"), help: ArgumentHelp(String(localized: "Trace vnc traffic"), visibility: .hidden))
	var vncDebug: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	@MainActor
	private func doVNC(client: CakedServiceClient, config: CakedConfiguration, screenSize: ViewSize, channel: Channel, port: Int) {
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

		do {
			try VNCApp.startVncClient(name: self.name,
									  config: config,
									  vncURL: URL(string: "vnc://127.0.0.1:\(port)")!,
									  screenSize: screenSize,
									  isDebugLoggingEnabled: vncDebug,
									  vmStatus: vmStatus,
									  screenSizeAction: screenSizeAction)
		} catch {
			// Handle or log the error; the closure itself must not throw
			fputs("VNC client failed to start: \(error)\n", stderr)
		}

		channel.close(promise: nil)
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		let result = try client.info(name: self.name, includeConfig: true).vms.status
		let screenSize = result.infos.hasScreenSize ? ViewSize(result.infos.screenSize) : ViewSize(result.config.display)

		try await client.createVNCTunnel(eventLoopGroup: Utilities.group, vmName: self.name) { (channel, port) in
			self.doVNC(client: client, config: CakedConfiguration(result.config), screenSize: screenSize, channel: channel, port: port)
		}

		return String.empty
	}
}
