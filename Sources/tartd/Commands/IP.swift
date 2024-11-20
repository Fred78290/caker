import ArgumentParser
import Foundation
import tartlib

enum IPResolutionStrategy: String, ExpressibleByArgument, CaseIterable {
  case dhcp, arp

  private(set) static var allValueStrings: [String] = Format.allCases.map { "\($0)"}
}

struct IP: TartdCommand {
  var name: String
  var wait: UInt16 = 0
  var resolver: IPResolutionStrategy = .dhcp

  func run() async throws {
    var arguments: [String] = []

    arguments.append(name)

    if resolver != .dhcp {
      arguments.append("--resolver=\(resolver.rawValue)")
    }

    if wait != 0 {
      arguments.append("--wait=\(wait)")
    }

    try Shell.runTart(command: "ip", arguments: arguments)
  }
}
