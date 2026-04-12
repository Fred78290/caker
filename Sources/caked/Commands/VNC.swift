//
//  VNC.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/11/2025.
//

import ArgumentParser
import CakeAgentLib
import CakedLib
import Cocoa
import Foundation
import GRPC
import GRPCLib
import NIO
import RoyalVNCKit
import SwiftUI

struct VNC: CakeAgentParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vnc", abstract: String(localized: "Start a VNC client for a running VM"))
	static let logger = Logger("VNCClient")

	var createVM: Bool = false

	var logLevel: Logger.LogLevel {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "override client agent options"), visibility: .hidden)
	var options: CakeAgentClientOptions

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	@Flag(name: .customLong("vnc-debug"), help: ArgumentHelp(String(localized: "Trace vnc traffic"), visibility: .hidden))
	var vncDebug: Bool = false

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.validateOptions(runMode: self.common.runMode)

		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status != .running {
			throw ValidationError(String(localized: "VM \(self.name) is not running"))
		}
	}

	func run(on: EventLoopGroup, helper: CakeAgentHelper, callOptions: CallOptions?) throws {
		do {
			let location = try StorageLocation(runMode: runMode).find(name)
			let result = try CakedLib.InfosHandler.infos(location: location, runMode: self.common.runMode, client: helper, callOptions: callOptions)
			let infos = result.infos
			let screenSize = result.infos.screenSize ?? result.config.display

			guard let vncURL = VNCServer.findHostMatching(urls: infos.vncURL) else {
				Logger.appendNewLine("VM \(self.name) does not have a VNC connection")
				return
			}

			func vmStatus() -> Status {
				if location.status == .running {
					return .running
				}
				
				return .stopped
			}

			func screenSizeAction(_ screenSize: ViewSize) -> Void {
				_ = CakedLib.ScreenSizeHandler.setScreenSize(name: self.name, width: screenSize.width, height: screenSize.height, runMode: runMode)
			}

			try VNCApp.startVncClient(name: self.name,
									  config: result.config,
									  vncURL: vncURL,
									  screenSize: screenSize,
									  isDebugLoggingEnabled: vncDebug,
									  vmStatus: vmStatus,
									  screenSizeAction: screenSizeAction)

		} catch {
			Logger.appendNewLine(self.common.format.render(error.reason))
		}
	}
}
