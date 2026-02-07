//
//  ServiceHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 20/11/2025.
//
import Foundation
import GRPC
import GRPCLib
import NIO
import NIOSSL
import CakeAgentLib

public struct ServiceHandler {
	struct LaunchAgent: Codable {
		let label: String
		let programArguments: [String]
		let keepAlive: [String: Bool]
		let runAtLoad: Bool
		let abandonProcessGroup: Bool
		let softResourceLimits: [String: Int]
		let environmentVariables: [String: String]
		let standardErrorPath: String
		let standardOutPath: String
		let processType: String

		enum CodingKeys: String, CodingKey {
			case label = "Label"
			case programArguments = "ProgramArguments"
			case keepAlive = "KeepAlive"
			case runAtLoad = "RunAtLoad"
			case abandonProcessGroup = "AbandonProcessGroup"
			case softResourceLimits = "SoftResourceLimits"
			case environmentVariables = "EnvironmentVariables"
			case standardErrorPath = "StandardErrorPath"
			case standardOutPath = "StandardOutPath"
			case processType = "ProcessType"
		}

		func write(to: URL) throws {
			let encoder = PropertyListEncoder()
			encoder.outputFormat = .xml

			let data = try encoder.encode(self)
			try data.write(to: to)
		}
	}

	public static func findMe() throws -> String {
		if let caked = Bundle.main.path(forAuxiliaryExecutable: Home.cakedCommandName) {
			return caked
		}

		guard let url = URL.binary(Home.cakedCommandName) else {
			return try Shell.execute(to: "command", arguments: ["-v", Home.cakedCommandName])
		}

		return url.path
	}

	public static func createServer(
		eventLoopGroup: EventLoopGroup,
		runMode: Utils.RunMode,
		listeningAddress: URL?,
		serviceProviders: [CallHandlerProvider],
		caCert: String?,
		tlsCert: String?,
		tlsKey: String?
	) throws -> EventLoopFuture<Server> {

		if let listeningAddress = listeningAddress {
			let target: ConnectionTarget

			if listeningAddress.isFileURL || listeningAddress.scheme == "unix" {
				try listeningAddress.deleteIfFileExists()
				target = ConnectionTarget.unixDomainSocket(listeningAddress.path)
			} else if listeningAddress.scheme == "tcp" {
				target = ConnectionTarget.hostAndPort(listeningAddress.host ?? "127.0.0.1", listeningAddress.port ?? 5000)
			} else {
				throw ServiceError("unsupported listening address scheme: \(String(describing: listeningAddress.scheme))")
			}

			var serverConfiguration = Server.Configuration.default(
				target: target,
				eventLoopGroup: eventLoopGroup,
				serviceProviders: serviceProviders)

			if let tlsCert = tlsCert, let tlsKey = tlsKey {
				serverConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeServerConfiguration(caCert: caCert, tlsKey: tlsKey, tlsCert: tlsCert)
			}

			return Server.start(configuration: serverConfiguration)
		}

		throw ServiceError("connection address must be specified")
	}

	public static func installAgent(mode: VMRunServiceMode = .grpc, runMode: Utils.RunMode) throws {
		let certs = try CertificatesLocation.createCertificats(runMode: runMode)

		return try self.installAgent(listenAddress: [try Utils.getDefaultServerAddress(runMode: runMode)], insecure: false, caCert: certs.caCertURL.path, tlsCert: certs.serverCertURL.path, tlsKey: certs.serverKeyURL.path, runMode: runMode)
	}

	public static func installAgent(listenAddress: [String], insecure: Bool, caCert: String?, tlsCert: String?, tlsKey: String?, mode: VMRunServiceMode = .grpc, runMode: Utils.RunMode) throws {
		let cakeHome: URL = try Utils.getHome(runMode: runMode)
		let outputLog: String = Utils.getOutputLog(runMode: runMode)
		var arguments: [String] = [
			try Self.findMe(),
			"service",
			"listen",
			"--log-level=\(Logger.Level().description)",
		]

		listenAddress.forEach {
			arguments.append("--address=\($0)")
		}

		if mode == .grpc {
			arguments.append("--grpc")
		} else {
			arguments.append("--xpc")
		}

		if runMode == .system {
			arguments.append("--system")
		}

		if insecure == false {
			if let ca = caCert {
				arguments.append("--ca-cert=\(ca)")
			}

			if let key = tlsKey {
				arguments.append("--tls-key=\(key)")
			}

			if let cert = tlsCert {
				arguments.append("--tls-cert=\(cert)")
			}
		}

		let agent = LaunchAgent(
			label: Utils.cakerSignature,
			programArguments: arguments,
			keepAlive: [
				"SuccessfulExit": false
			],
			runAtLoad: true,
			abandonProcessGroup: true,
			softResourceLimits: [
				"NumberOfFiles": 4096
			],
			environmentVariables: [
				"PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin/:/sbin",
				"CAKE_HOME": cakeHome.path,
			],
			standardErrorPath: outputLog,
			standardOutPath: outputLog,
			processType: "Background")

		try agent.write(to: Self.agentLaunchURL(runMode: runMode))
	}

	public static func agentLaunchURL(runMode: Utils.RunMode) -> URL {
		if runMode == .system {
			return URL(fileURLWithPath: "/Library/LaunchDaemons/\(Utils.cakerSignature).plist")
		} else {
			return URL(fileURLWithPath: "\(NSHomeDirectory())/Library/LaunchAgents/\(Utils.cakerSignature).plist")
		}
	}

	public static func uninstallAgent(runMode: Utils.RunMode) throws {
		if self.isAgentRunning(runMode: runMode) {
			try self.stopAgent(runMode: runMode)
		}

		try self.agentLaunchURL(runMode: runMode).delete()
	}

	public static func launchAgent(runMode: Utils.RunMode) throws {
		let plistURL = self.agentLaunchURL(runMode: runMode)

		guard (try? plistURL.exists()) == true else {
			throw ServiceError("agent not installed: missing plist at \(plistURL.path)")
		}

		// Determine launchctl domain and commands
		let domain: String
		switch runMode {
		case .system:
			domain = "system"
		default:
			domain = "gui/\(getuid())"
		}

		// Use modern launchctl where possible
		// 1) bootstrap the plist
		do {
			_ = try Shell.execute(to: "/bin/launchctl", arguments: ["bootstrap", domain, plistURL.path])
		} catch {
			// If already bootstrapped or on older systems, try load as a fallback
			_ = try? Shell.execute(to: "/bin/launchctl", arguments: ["load", plistURL.path])
		}

		// 2) enable the service
		_ = try? Shell.execute(to: "/bin/launchctl", arguments: ["enable", "\(domain)/\(Utils.cakerSignature)"])

		// 3) kickstart (start immediately)
		_ = try? Shell.execute(to: "/bin/launchctl", arguments: ["kickstart", "-k", "\(domain)/\(Utils.cakerSignature)"])
	}

	public static func stopAgent(runMode: Utils.RunMode) throws {
		// Determine launchctl domain and service label
		let domain: String
		switch runMode {
		case .system:
			domain = "system"
		default:
			domain = "gui/\(getuid())"
		}

		let service = "\(domain)/\(Utils.cakerSignature)"

		// Try to stop and remove the service from the bootstrap namespace
		do {
			_ = try Shell.execute(to: "/bin/launchctl", arguments: ["bootout", service])
		} catch {
			// Fallback for older systems: unload the plist if present
			let plistURL = self.agentLaunchURL(runMode: runMode)
			_ = try? Shell.execute(to: "/bin/launchctl", arguments: ["unload", plistURL.path])
		}

		// Best-effort disable so it doesn't auto-restart until explicitly launched again
		_ = try? Shell.execute(to: "/bin/launchctl", arguments: ["disable", service])
	}

	public static var isAgentInstalled: Bool {
		for runMode in [Utils.RunMode.system, .user] {
			if let exist = try? self.agentLaunchURL(runMode: runMode).exists(), exist {
				return true
			}
		}

		return false
	}

	public static func isAgentRunning(runMode: Utils.RunMode) -> Bool {
		if let home = try? Home(runMode: runMode, createItIfNotExists: false) {
			if home.agentPID.isPIDRunning().running {
				return true
			}
		}

		return false
	}

	public static var isAgentRunning: Bool {
		for runMode in [Utils.RunMode.system, .user] {
			if self.isAgentRunning(runMode: runMode) {
				return true
			}
		}

		return false
	}

	public static var runningMode: Utils.RunMode {
		for runMode in [Utils.RunMode.system, .user] {
			if self.isAgentRunning(runMode: runMode) {
				return runMode
			}
		}

		return .app
	}

	public static var serviceClient: CakedServiceClient? {
		guard isAgentRunning else {
			return nil
		}

		for runMode in [Utils.RunMode.system, .user] {
			if let listenAddress = try? Utils.getDefaultServerAddress(runMode: runMode), let certs = try? ClientCertificatesLocation.getCertificats(runMode: runMode) {

				var caCert: String? = nil
				var tlsCert: String? = nil
				var tlsKey: String? = nil

				if certs.exists() {
					caCert = certs.caCertURL.path
					tlsCert = certs.clientCertURL.path
					tlsKey = certs.clientKeyURL.path
				}

				return try? Caked.createClient(on: Utilities.group.next(), listeningAddress: URL(string: listenAddress), connectionTimeout: 5, retries: .upTo(1), caCert: caCert, tlsCert: tlsCert, tlsKey: tlsKey)
			}
		}

		return nil
	}
}
