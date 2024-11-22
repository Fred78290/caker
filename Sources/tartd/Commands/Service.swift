import ArgumentParser
import Foundation
import ShellOut
import GRPC
import NIOSSL
import NIOCore
import NIOPosix
import Synchronization
import Crypto
import SwiftASN1
import X509
import Security

let tartDSignature = "com.aldunelabs.tartd"

class ServiceError : Error, CustomStringConvertible {
  let description: String

  init(_ what: String) {
    self.description = what
  }
}

struct Service: ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Tart daemon as launchctl agent",
                                                  subcommands: [Install.self, Listen.self])
  static let SyncSemaphore = DispatchSemaphore(value: 0)
  
}

extension Service {
  struct LaunchAgent: Codable {
    let label: String
    let programArguments: [String]
    let keepAlive: [String:Bool]
    let runAtLoad: Bool
    let abandonProcessGroup: Bool
    let softResourceLimits: [String:Int]
    let environmentVariables: [String:String]
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
  struct Install : ParsableCommand {    
    static var configuration = CommandConfiguration(abstract: "Install tart daemon as launchctl agent")

    @Option(name: [.customLong("system"), .customShort("s")], help: "Install agent as system agent, need sudo")
    var asSystem: Bool = false

    static func findMe() throws -> String {
      return try shellOut(to: "command", arguments: ["-v", "tart"])
    }

    mutating func run() throws {
      let certs = try Utils.createCertificats(asSystem: self.asSystem)
      let certicate = certs["server.pem"]
      let privateKey = certs["server.key"]
      let listenAddress: String = try Utils.getListenAddress(asSystem: self.asSystem)
      let outputLog: String = Utils.getOutputLog(asSystem: self.asSystem)
      let tartHome: URL = try Utils.getTartHome(asSystem: self.asSystem)
      let agent = LaunchAgent(label: tartDSignature,
                              programArguments: [
                                try Install.findMe(),
                                "listen",
                                "--address",
                                listenAddress,
                                "--tls-cert",
                                certicate!.path(),
                                "--tls-key",
                                privateKey!.path()
                              ],
                              keepAlive: [
                                "SuccessfulExit" : false
                              ],
                              runAtLoad: true,
                              abandonProcessGroup: true,
                              softResourceLimits: [
                                "NumberOfFiles" : 4096
                              ],
                              environmentVariables: [
                                "PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin/:/sbin",
                                "TART_HOME" : tartHome.path()
                              ],
                              standardErrorPath: outputLog,
                              standardOutPath: outputLog,
                              processType: "Background")
      
      let agentURL: URL

      if self.asSystem {
        agentURL = URL(fileURLWithPath: "/Library/LaunchDaemons/\(tartDSignature).plist")
      } else {
        agentURL = URL(fileURLWithPath: "\(NSHomeDirectory())/Library/LaunchAgents/\(tartDSignature).plist")
      }

      try agent.write(to: agentURL)
    }
  }
  struct Listen : AsyncParsableCommand {
    static var configuration = CommandConfiguration(abstract: "tart daemon listening")

    @Option(name: [.customLong("address"), .customShort("l")], help: "Listen on address")
    var address: String?

    @Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
    var caCert: String?

    @Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Server TLS certificate")
    var tlsCert: String?

    @Option(name: [.customLong("tls-key"), .customShort("k")], help: "Server private key")
    var tlsKey: String?

    func validate() throws {
      if let caCert = self.caCert, let tlsCert = self.tlsCert, let tlsKey = self.tlsKey {
        if FileManager.default.fileExists(atPath: caCert) == false {
          throw ServiceError("Root certificate file not found: \(caCert)")
        }

        if FileManager.default.fileExists(atPath: tlsCert) == false {
          throw ServiceError("TLS certificate file not found: \(tlsCert)")
        }

        if FileManager.default.fileExists(atPath: tlsKey) == false {
          throw ServiceError("TLS key file not found: \(tlsKey)")
        }
      } else if (self.tlsKey != nil || self.tlsCert != nil) && (self.tlsKey == nil || self.tlsCert == nil) {
        throw ServiceError("Some cert files not provided")
      }
    }

    private func getServerAddress() throws -> String {
      if let address = self.address {
        return address
      } else {
        return try Utils.getListenAddress(asSystem: false)
      }
    }

    private func createServer(on: MultiThreadedEventLoopGroup) async throws -> EventLoopFuture<Server> {
      let listeningAddress = URL(string: try self.getServerAddress())
      let builder: Server.Builder

      if let caCert = caCert, let tlsCert = tlsCert, let tlsKey = tlsKey {
        builder = Server.usingTLSBackedByNIOSSL(
          on: on,
          certificateChain: [try NIOSSLCertificate(file: tlsCert, format: .pem)],
          privateKey: try NIOSSLPrivateKey(file: tlsKey, format: .pem))
        .withTLS(trustRoots: .certificates([try NIOSSLCertificate(file: caCert, format: .pem)]))
      } else {
        builder = Server.insecure(group: on)
      }

      builder.withServiceProviders([TartDaemonProvider()])

      if let listeningAddress = listeningAddress {
        if listeningAddress.scheme == "unix" {
          return builder.bind(unixDomainSocketPath: listeningAddress.path())
        } else if listeningAddress.scheme == "tcp" {
          return builder.bind(host: listeningAddress.host ?? "127.0.0.1", port: listeningAddress.port ?? 5000)
        } else {
          throw ServiceError("unsupported listening address scheme: \(String(describing: listeningAddress.scheme))")
        }
      }

      throw ServiceError("connection address must be specified")
    }

    func run() async throws {
      let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
      defer {
        Task {
          try! await group.shutdownGracefully()
        }
      }

      // Start the server and print its address once it has started.
      let server = try await createServer(on: group).get()

      // Wait on the server's `onClose` future to stop the program from exiting.
      try await server.onClose.get()
    }
  }
}
