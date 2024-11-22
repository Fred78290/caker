import ArgumentParser
import Foundation

struct IPHandler: TartdCommand {
  var name: String
  var wait: UInt16 = 0
  var resolver: IPResolutionStrategy = .dhcp

  func run() async throws -> String {
    var arguments: [String] = []

    arguments.append(name)

    if resolver != .dhcp {
      arguments.append("--resolver=\(resolver.rawValue)")
    }

    if wait != 0 {
      arguments.append("--wait=\(wait)")
    }

    return try Shell.runTart(command: "ip", arguments: arguments)
  }
}
