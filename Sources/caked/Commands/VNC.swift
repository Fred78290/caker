//
//  VNC.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/11/2025.
//

import ArgumentParser
import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib
import Logging
import NIO
import RoyalVNCKit
import Foundation
import Cocoa

class DelegateConnectionVNC: VNCConnectionDelegate, VNCLogger, Codable {
	var isDebugLoggingEnabled: Bool = true
	var username: String? = nil
	var password: String? = nil

	func logDebug(_ message: String) {
		VNC.logger.debug(message)
	}
	
	func logInfo(_ message: String) {
		VNC.logger.info(message)
	}
	
	func logWarning(_ message: String) {
		VNC.logger.warn(message)
	}
	
	func logError(_ message: String) {
		VNC.logger.error(message)
	}
	
	func connection(_ connection: RoyalVNCKit.VNCConnection, stateDidChange connectionState: RoyalVNCKit.VNCConnection.ConnectionState) {
		let connectionStateString: String

		switch connectionState.status {
			case .connecting:
				connectionStateString = "Connecting"
			case .connected:
				connectionStateString = "Connected"
			case .disconnecting:
				connectionStateString = "Disconnecting"
			case .disconnected:
				connectionStateString = "Disconnected"
		}

		if let error = connectionState.error {
			connection.logger.logDebug("connection stateDidChange: \(connectionStateString) with error: \(error)")
		} else {
			connection.logger.logDebug("connection stateDidChange: \(connectionStateString)")
		}
	}
	
	func connection(_ connection: RoyalVNCKit.VNCConnection, credentialFor authenticationType: RoyalVNCKit.VNCAuthenticationType, completion: @escaping ((any RoyalVNCKit.VNCCredential)?) -> Void) {
		let authenticationTypeString: String

		var credential: RoyalVNCKit.VNCCredential? = nil

		func readInput(_ prompt: String) -> String? {
			print(prompt, terminator: "")

			return readLine(strippingNewline: true)
		}

		func readUser() -> String? {
			if let username {
				return username
			}

			return readInput("Username: ")
		}

		func readPassword() -> String? {
			if let password {
				return password
			}
			
			return readInput("Password: ")
		}

		switch authenticationType {
			case .vnc:
				authenticationTypeString = "VNC"
			case .appleRemoteDesktop:
				authenticationTypeString = "Apple Remote Desktop"
			case .ultraVNCMSLogonII:
				authenticationTypeString = "UltraVNC MS Logon II"
			@unknown default:
				fatalError("Unknown authentication type: \(authenticationType)")
		}

		connection.logger.logDebug("connection credentialFor: \(authenticationTypeString)")

		if authenticationType.requiresUsername, authenticationType.requiresPassword {
			if let username = readUser(), let password = readPassword() {
				credential = VNCUsernamePasswordCredential(username: username, password: password)
			}
		} else if authenticationType.requiresPassword {
			if let password = readPassword() {
				credential = VNCPasswordCredential(password: password)
			}
		}

		completion(credential)
	}
	
	func connection(_ connection: RoyalVNCKit.VNCConnection, didCreateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		connection.logger.logDebug("connection didCreateFramebuffer")
	}
	
	func connection(_ connection: RoyalVNCKit.VNCConnection, didResizeFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		connection.logger.logDebug("connection didResizeFramebuffer")
	}
	
	func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
		connection.logger.logDebug("connection didUpdateFramebuffer")
	}
	
	func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateCursor cursor: RoyalVNCKit.VNCCursor) {
		connection.logger.logDebug("connection didUpdateCursor")
	}
}


struct VNC: CakeAgentAsyncParsableCommand {
	static var configuration = CommandConfiguration(commandName: "vnc", abstract: "Start a VNC client to debug your application")
	static let logger = Logger("VNCClient")

	var createVM: Bool = false

	var logLevel: Logging.Logger.Level {
		self.common.logLevel
	}

	var runMode: Utils.RunMode {
		self.common.runMode
	}
	
	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "override client agent options", visibility: .hidden)
	var options: CakeAgentClientOptions

	@Argument(help: "VM name")
	var name: String

	var isDebugLoggingEnabled: Bool
	var delegate: DelegateConnectionVNC

	init() {
		self.isDebugLoggingEnabled = true
		self.delegate = DelegateConnectionVNC()
	}
	
	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try self.validateOptions(runMode: self.common.runMode)

		let location = try StorageLocation(runMode: runMode).find(name)

		if location.status != .running {
			throw ValidationError("VM \(self.name) is not running")
		}
	}

	func run(on: EventLoopGroup, client: CakeAgentClient, callOptions: CallOptions?) async {
		let result: VirtualMachineStatusReply = CakedLib.InfosHandler.infos(name: self.name, runMode: self.common.runMode, client: CakeAgentHelper(on: on, client: client), callOptions: callOptions)

		if result.success {
			guard let u = result.status.vncURL, let vncURL = URL(string: u), let vncPort = vncURL.port else {
				Logger.appendNewLine("VM \(self.name) does not have a VNC connection")
				return
			}

			self.delegate.username = vncURL.user(percentEncoded: false)
			self.delegate.password = vncURL.password(percentEncoded: false)

			// Create settings
			let settings = VNCConnection.Settings(isDebugLoggingEnabled: true,
												  hostname: "127.0.0.1",
												  port: UInt16(vncPort),
												  isShared: true,
												  isScalingEnabled: true,
												  useDisplayLink: false,
												  inputMode: .none,
												  isClipboardRedirectionEnabled: false,
												  colorDepth: .depth24Bit,
												  frameEncodings: .default)

			// Create connection
			let connection = VNCConnection(settings: settings, logger: self.delegate)

			connection.delegate = self.delegate

			// Connect
			connection.connect()

			// Run loop until connection is disconnected
			while true {
				let connectionStatus = connection.connectionState.status

				if connectionStatus == .disconnected {
					break
				}
				
				try? await Task.sleep(nanoseconds: 1000_000_000)
			}
		} else {
			Logger.appendNewLine(self.common.format.render(result.reason))
		}
	}
}

