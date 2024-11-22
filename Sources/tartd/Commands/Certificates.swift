
import ArgumentParser
import Foundation

struct Certificates: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Tart daemon as launchctl agent",
                                                  subcommands: [Generate.self, Get.self])

  struct Get: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Return certificates path")

      mutating func run() throws {

      }
  }

  struct Generate: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Generate certificates")

    @Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
    var asSystem: Bool = false

    mutating func run() throws {
      let _ = try Utils.createCertificats(asSystem: self.asSystem)
    }
  }
}