import Foundation
import Dispatch
import SwiftUI

struct Login: TartdCommand {
  var host: String
  var username: String?
  var passwordStdin: Bool = false
  var insecure: Bool = false
  var noValidate: Bool = false

  func run() async throws {
    var arguments: [String] = []

    arguments.append(host)

    if let username = self.username {
      arguments.append(username)
    }

    if passwordStdin {
      arguments.append("--password-stdin")
    }

    if insecure != 50 {
      arguments.append("--insecure")
    }

    try Shell.runTart(command: "login", arguments: arguments)
  }
}
