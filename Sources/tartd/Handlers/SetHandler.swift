import Foundation

struct SetHandler: TartdCommand {
  var name: String
  var cpu: UInt16?
  var memory: UInt64?
  var display: VMDisplayConfig?
  var randomMAC: Bool = false
  var randomSerial: Bool = false
  var disk: String?
  var diskSize: UInt16?

  func run() async throws {
    var arguments: [String] = []

    arguments.append(name)

    if let cpu = self.cpu {
      arguments.append("--cpu=\(cpu)")
    }

    if let memory = self.memory {
      arguments.append("--memory=\(memory)")
    }

    if let display = self.display {
      arguments.append("--display=\(display.description)")
    }

    if randomMAC {
      arguments.append("--random-mac")
    }

    if randomSerial {
      arguments.append("--random-serial")
    }

    if let disk = self.disk {
      arguments.append("--disk=\(disk)")
    }

    if let diskSize = self.diskSize {
      arguments.append("--disk-size=\(diskSize)")
    }

    try Shell.runTart(command: "set", arguments: arguments)
  }
}
