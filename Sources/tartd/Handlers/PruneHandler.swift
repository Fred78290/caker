import Foundation
import SwiftDate

struct PruneHandler: TartdCommand {
  var entries: String = "caches"
  var olderThan: UInt?
  var cacheBudget: UInt?
  var spaceBudget: UInt?
  var gc: Bool = false

  func run() async throws {
    var arguments: [String] = []

    arguments.append(entries)

    if let olderThan = self.olderThan {
      arguments.append("--older-than=\(olderThan)")
    }

    if let spaceBudget = self.spaceBudget {
      arguments.append("--space-budget=\(spaceBudget)")
    }

    if gc {
      arguments.append("--gc")
    }

    try Shell.runTart(command: "prune", arguments: arguments)
  }
}