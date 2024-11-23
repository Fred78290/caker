import ArgumentParser
import Foundation
import Network
import SystemConfiguration
import Sentry
import GRPCLib

enum IPResolutionStrategy: String, ExpressibleByArgument, CaseIterable {
    case dhcp, arp

    private(set) static var allValueStrings: [String] = IPResolutionStrategy.allCases.map { "\($0)"}
}

struct IP: GrpcAsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Get VM's IP address")

    @Argument(help: "VM name")
    var name: String

    @Option(help: "Number of seconds to wait for a potential VM booting")
    var wait: UInt16 = 0

    @Option(help: ArgumentHelp("Strategy for resolving IP address: dhcp or arp",
                               discussion: """
                               By default, Tart is looking up and parsing DHCP lease file to determine the IP of the VM.\n
                               This method is fast and the most reliable but only returns local IP adresses.\n
                               Alternatively, Tart can call external `arp` executable and parse it's output.\n
                               In case of enabled Bridged Networking this method will return VM's IP address on the network interface used for Bridged Networking.\n
                               Note that `arp` strategy won't work for VMs using `--net-softnet`.
                               """))
    var resolver: IPResolutionStrategy = .dhcp

    mutating func run() async throws {
        throw GrpcError(code: 0, reason: "nothing here")
    }

    mutating func run(client: Tartd_ServiceNIOClient, arguments: [String]) async throws -> Tartd_TartReply {
		return try await client.tartCommand(Tartd_TartCommandRequest(command: "ip", arguments: arguments)).response.get()
    }
}
