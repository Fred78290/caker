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
import Cocoa

public struct ServiceHandler {
    // Keep a strong reference to the Bonjour service so it remains published
    private static var bonjourService: Set<NetService> = []
	private static var bonjourDeletegate: ServiceHandlerBonjourDelegate?

	class ServiceHandlerBonjourDelegate: NSObject, NetServiceDelegate {
		func netServiceWillPublish(_ sender: NetService) {
			Logger("ServiceHandler").debug("Attempting to publish Bonjour service '\(sender.name)' on port \(sender.port) with type '\(sender.type)'")
		}

		func netServiceDidPublish(_ sender: NetService) {
			Logger("ServiceHandler").debug("Successfully published Bonjour service '\(sender.name)' on port \(sender.port) with type '\(sender.type)'")
		}

		func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
			Logger("ServiceHandler").error("Failed to publish Bonjour service '\(sender.name)' with type '\(sender.type)'. Error: \(errorDict)")
		}

		func netServiceDidStop(_ sender: NetService) {
			Logger("ServiceHandler").info("Stopped Bonjour service '\(sender.name)' with type '\(sender.type)'")
		}

	}

	private static func publishBonjourService(name: String, type: String, domain: String = "local.", port: Int32, txt: [String: String] = [:]) {
		let service = NetService(domain: domain, type: type, name: name, port: port)

		if txt.isEmpty == false {
			let dict = txt.reduce(into: [String: Data]()) { acc, pair in
				acc[pair.key] = pair.value.data(using: .utf8)
			}
			service.setTXTRecord(NetService.data(fromTXTRecord: dict))
		}

		if bonjourDeletegate == nil {
			bonjourDeletegate = ServiceHandlerBonjourDelegate()
		}

		service.delegate = bonjourDeletegate!
		service.publish()

		self.bonjourService.insert(service)
	}

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
		password: String?,
		caCert: String?,
		tlsCert: String?,
		tlsKey: String?
	) throws -> EventLoopFuture<Server> {
		if let listeningAddress = listeningAddress {
			let target: ConnectionTarget
			var listeningPort = 0
			
			if listeningAddress.isFileURL || listeningAddress.scheme == "unix" {
				try listeningAddress.deleteIfFileExists()
				target = ConnectionTarget.unixDomainSocket(listeningAddress.path)
			} else if listeningAddress.scheme == "tcp" {
				let listeningHost = listeningAddress.host ?? "127.0.0.1"

				listeningPort = listeningAddress.port ?? Caked.defaultServicePort

				if listeningPort == 0 {
					listeningPort = try Utilities.findFreePort(listeningHost)
				}

				target = ConnectionTarget.hostAndPort(listeningHost, listeningPort)
                // TCP target selected; we'll publish via Bonjour after server starts.
			} else {
				throw ServiceError(String(localized: "unsupported listening address scheme: \(String(describing: listeningAddress.scheme))"))
			}

			var serverConfiguration = Server.Configuration.default(
				target: target,
				eventLoopGroup: eventLoopGroup,
				serviceProviders: serviceProviders)

			if let tlsCert = tlsCert, let tlsKey = tlsKey {
				serverConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeServerConfiguration(caCert: caCert, tlsKey: tlsKey, tlsCert: tlsCert)
			}

            let serverFuture = Server.start(configuration: serverConfiguration)

            // If using TCP, publish a Bonjour service once the server has started and bound to a port
            if listeningAddress.scheme == "tcp" {
				return serverFuture.flatMap { server in
					// Try to read the bound port from the server's channel
					let boundPort: Int32 = Int32(listeningPort)

					// Service type must be of the form _name._tcp.
					let serviceType = "_caked._tcp."

					let txt: [String: String] = [
						"host": listeningAddress.host ?? "localhost",
						"tls": serverConfiguration.tlsConfiguration != nil ? "true" : "false",
						"secure": (password ?? "").isEmpty ? "false" : "true",
					]

					Logger("ServiceHandler").info("Publishing Bonjour service on port \(boundPort) with type '\(serviceType)'")

					Self.publishBonjourService(name: "", type: serviceType, port: boundPort, txt: txt)

					return serverFuture
                }
            }

            return serverFuture
		}

		throw ServiceError(String(localized: "connection address must be specified"))
	}

	public static func installAgent(password: String?, mode: VMRunServiceMode = .grpc, runMode: Utils.RunMode) throws {
		let certs = try CertificatesLocation.createCertificats(runMode: runMode)

		if password == nil {
			return try self.installAgent(listenAddress: [try Utils.getDefaultServerAddress(runMode: runMode)], insecure: false, password: password, caCert: certs.caCertURL.path, tlsCert: certs.serverCertURL.path, tlsKey: certs.serverKeyURL.path, runMode: runMode)
		} else {
			return try self.installAgent(listenAddress: [try Utils.getDefaultServerAddress(runMode: runMode), "tcp://0.0.0.0:\(Caked.defaultServicePort)"], insecure: false, password: password, caCert: certs.caCertURL.path, tlsCert: certs.serverCertURL.path, tlsKey: certs.serverKeyURL.path, runMode: runMode)
		}
	}

	public static func installAgent(listenAddress: [String], insecure: Bool, password: String?, caCert: String?, tlsCert: String?, tlsKey: String?, mode: VMRunServiceMode = .grpc, runMode: Utils.RunMode) throws {
		let home = try Home(runMode: runMode)
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

		if let password {
			arguments.append("--password=\(password)")
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
				"CAKE_HOME": home.cakeHomeDirectory.path,
			],
			standardErrorPath: outputLog,
			standardOutPath: outputLog,
			processType: "Background")

		let agentURL = self.agentLaunchURL(runMode: runMode)
		
		Logger("ServiceHandler").info("Install agent to: \(agentURL.absoluteString)")

		try agent.write(to: agentURL)
	}

	public static func agentLaunchURL(runMode: Utils.RunMode) -> URL {
		if runMode == .system {
			return URL(fileURLWithPath: "/Library/LaunchDaemons/\(Utils.cakerSignature).plist")
		} else {
			return URL(fileURLWithPath: "\(NSHomeDirectory())/Library/LaunchAgents/\(Utils.cakerSignature).plist")
		}
	}

	public static func uninstallAgent(runMode: Utils.RunMode) throws {
		if self.isAgentRunning(runMode: runMode).running {
			try self.stopAgent(runMode: runMode)
		}

		try self.agentLaunchURL(runMode: runMode).delete()
	}

	public static func launchAgent(runMode: Utils.RunMode) throws {
		let plistURL = self.agentLaunchURL(runMode: runMode)

		guard (try? plistURL.exists()) == true else {
			throw ServiceError(String(localized: "agent not installed: missing plist at \(plistURL.path)"))
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

	public static func isAgentInstalled(runMode: Utils.RunMode) -> Bool {
		if let exist = try? self.agentLaunchURL(runMode: runMode).exists(), exist {
			return true
		}

		return false
	}

	public static var isAgentInstalled: Bool {
		for runMode in [Utils.RunMode.system, .user] {
			if let exist = try? self.agentLaunchURL(runMode: runMode).exists(), exist {
				return true
			}
		}

		return false
	}

	public static func stopAgentRunning(runMode: Utils.RunMode) throws {
		let home = try Home(runMode: runMode, createItIfNotExists: false)

		guard home.agentPID.isPIDRunning().running else {
			throw ServiceError(String(localized: "Caked service is not running"))
		}

		if home.agentPID.killPID(SIGINT) != 0 {
			throw ServiceError(String(localized: "Failed to stop caked service \(errno)"))
		}
	}

	public static func isAgentRunning(runMode: Utils.RunMode) -> (running: Bool, agentURL: URL?, pid: Int32?) {
		if let home = try? Home(runMode: runMode, createItIfNotExists: false) {
			let run = home.agentPID.isPIDRunning()

			if run.running {
				return (true, home.agentPID, run.pid)
			}
		}

		return (false, nil, nil)
	}

	public static var isAgentRunningWithPID: (running: Bool, agentURL: URL?, pid: Int32?) {
		for runMode in [Utils.RunMode.system, .user] {
			let run = self.isAgentRunning(runMode: runMode)

			if run.running {
				return run
			}
		}

		return (false, nil, nil)
	}

	public static var isAgentRunning: Bool {
		for runMode in [Utils.RunMode.system, .user] {
			if self.isAgentRunning(runMode: runMode).running {
				return true
			}
		}

		return false
	}

	public static var runningMode: Utils.RunMode {
		for runMode in [Utils.RunMode.system, .user] {
			if self.isAgentRunning(runMode: runMode).running {
				return runMode
			}
		}

		return .app
	}
	
	public static var serviceClient: CakedServiceClient? {
		for runMode in [Utils.RunMode.system, .user] {
			if let client = try? self.createCakedServiceClient(tls: true, runMode: runMode) {
				return client
			}
		}
		
		return nil
	}
	
	public static func createCakedServiceClient(listenAddress: String? = nil, password: String? = nil, tls: Bool, connectionTimeout: Int64 = 5, retries: ConnectionBackoff.Retries = .upTo(1), runMode: Utils.RunMode) throws -> CakedServiceClient {
		let listeningAddress: URL

		if let listenAddress {
			guard let u = URL(string: listenAddress) else {
				throw ServiceError(String(localized: "Wrong listen address"))
			}

			if u.isFileURL == false && u.scheme != "unix" && u.scheme != "tcp" {
				throw ServiceError(String(localized: "unsupported listening address scheme: \(listenAddress)"))
			}

			listeningAddress = u
		} else {
			guard isAgentRunning(runMode: runMode).running else {
				throw ServiceError(String(localized: "Caked service is not running"))
			}

			listeningAddress = try URL(string: Utils.getDefaultServerAddress(runMode: runMode))!
		}

		var caCert: String? = nil
		var tlsCert: String? = nil
		var tlsKey: String? = nil

		if tls {
			let certs = try ClientCertificatesLocation.getCertificats(runMode: runMode)

			if certs.exists() {
				caCert = certs.caCertURL.path
				tlsCert = certs.clientCertURL.path
				tlsKey = certs.clientKeyURL.path
			}
		}

		return try Caked.createClient(on: Utilities.group.next(),
									  listeningAddress: listeningAddress,
									  connectionTimeout: connectionTimeout,
									  retries: retries,
									  caCert: caCert,
									  tlsCert: tlsCert,
									  tlsKey: tlsKey,
									  password: password)
	}
}

