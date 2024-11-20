import Foundation

struct Logout: TartdCommand {
  var host: String

  func run() async throws {
    try Shell.runTart(command: "logout", arguments: [host])
  }
}
