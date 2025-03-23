import ArgumentParser
import Foundation
import GRPCLib
import Virtualization
import NIOCore
import TextTable
import NIOPosix
import vmnet

enum VMNetMode: uint64, CaseIterable, ExpressibleByArgument, Codable {
	var defaultValueDescription: String { "host" }

	static var allValueStrings: [String] = VMNetMode.allCases.map { "\($0)" }

	case host = 1000
	case shared = 1001
	case bridged = 1002

	init?(argument: String) {
		switch argument {
		case "host":
			self = .host
		case "shared":
			self = .shared
		case "bridged":
			self = .bridged
		default:
			return nil
		}
	}
}

struct BridgedNetwork: Codable {
	var name: String
	var description: String?
	var interfaceID: String?
	var endpoint: String?
}
struct NetworksHandler: CakedCommand {
	var format: Format

	struct VMNetOptions: ParsableArguments {
		@Option(name: [.customLong("socket-group")], help: "socket group name")
		var socketGroup: String = "staff"

		@Option(name: [.customLong("mode")], help: "vmnet mode")
		var mode = VMNetMode.host

		@Option(name: [.customLong("interface")], help: ArgumentHelp("interface\n", discussion: "interface used for --vmnet=bridged, e.g., \"en0\""))
		var networkInterface: String? = nil

		@Option(name: [.customLong("gateway")], help: ArgumentHelp("IP gateway\n", discussion: "gateway used for --vmnet=(host|shared), e.g., \"192.168.105.1\" (default: decided by macOS)"))
		var gateway: String? = nil

		@Option(name: [.customLong("dhcp-end")], help: "end of the DHCP range")
		var dhcpEnd: String? = nil

		@Option(name: [.customLong("netmask")], help: ArgumentHelp("subnet mask\n", discussion: "requires --vmnet-gateway to be specified"))
		var subnetMask = "255.255.255.0"

		@Option(name: [.customLong("interface-id")], help: ArgumentHelp("vmnet interface ID\n", discussion: "randomly generated if not specified"))
		var interfaceID = UUID().uuidString

		@Option(name: [.customLong("nat66-prefix")], help: "The IPv6 prefix to use with shared mode")
		var nat66Prefix: String? = nil

		func validate() throws {
			if self.mode == .bridged {
				if self.networkInterface == nil {
					throw ValidationError("interface is required for bridged mode")
				}

				if self.gateway != nil {
					throw ValidationError("gateway is not allowed for bridged mode")
				}

				if self.dhcpEnd != nil {
					throw ValidationError("dhcp-end is not allowed for bridged mode")
				}
			} else if self.gateway != nil {
				if self.dhcpEnd == nil {
					throw ValidationError("dhcp-end is required for host/shared mode when gateway is specified")
				}
			}

		}

		func createVZVMNet(socketPath: String, socketGroup: gid_t) -> VZVMNet {
			VZVMNet(
				on: Root.group.next(),
				socketPath: socketPath,
				socketGroup: socketGroup,
				mode: self.mode,
				networkInterface: self.networkInterface,
				gateway: self.gateway,
				dhcpEnd: self.dhcpEnd,
				subnetMask: self.subnetMask,
				interfaceID: self.interfaceID,
				nat66Prefix: self.nat66Prefix
			)
		}
	}

	static func vmnetEndpoint(mode: VMNetMode, networkInterface: String? = nil) throws -> (URL, URL) {
		let home = try Home.init(asSystem: runAsSystem)
		let dirName: String

		if mode == .bridged {
			dirName = networkInterface!
		} else if mode == .host {
			dirName = "host"
		} else {
			dirName = "shared"
		}

		let networkDirectory = home.networkDirectory.appendingPathComponent(dirName, isDirectory: true)
		try FileManager.default.createDirectory(at: networkDirectory, withIntermediateDirectories: true)

		return (networkDirectory.appendingPathComponent("vmnet.sock").absoluteURL, networkDirectory.appendingPathComponent("vmnet.pd").absoluteURL)
	}

	static func run() throws {
		throw ServiceError("Please specify a subcommand")
	}

	static func start(options: NetworksHandler.VMNetOptions) async throws {
		let socketURL = try Self.vmnetEndpoint(mode: options.mode, networkInterface: options.networkInterface)
		let socketPath = socketURL.0.path
		let pidURL = socketURL.1
		let pid: pid_t = getpid()

		guard let grp = getgrnam(options.socketGroup) else {
			throw ServiceError("Failed to get group \(options.socketGroup)")
		}

		try "\(pid)".write(to: pidURL, atomically: true, encoding: .ascii)

		defer {
			try? FileManager.default.removeItem(at: pidURL)
		}

		if FileManager.default.fileExists(atPath: socketPath) == false {
			let vzvmnet = options.createVZVMNet(socketPath: socketPath, socketGroup: grp.pointee.gr_gid)

			try await vzvmnet.start()
		}
	}

	static func stop(options: NetworksHandler.VMNetOptions) throws -> String {
		let socketURL = try Self.vmnetEndpoint(mode: options.mode, networkInterface: options.networkInterface)
		let pidURL = socketURL.1

		if try pidURL.exists() {
			let pid = try String(contentsOf: pidURL, encoding: .ascii)

			if let pidInt = Int32(pid) {
				kill(pidInt, SIGTERM)
			}
		}

		return "stopped \(options)"
	}

	static func networks() -> [BridgedNetwork] {
		var networks: [BridgedNetwork] = [BridgedNetwork(name: "nat", description: "NAT shared network")]

		networks.append(contentsOf: VZBridgedNetworkInterface.networkInterfaces.map { inf in
			BridgedNetwork(name: inf.identifier, description: inf.localizedDisplayName)
		})

		return networks
	}

	func run(on: EventLoop, asSystem: Bool) throws -> String {
		self.format.renderList(style: Style.grid, uppercased: true, Self.networks())
	}
}