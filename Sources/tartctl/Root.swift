import ArgumentParser
import Darwin
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import NIOSSL
import Sentry
import SwiftDate

class GrpcError: Error {
  let code: Int
  let reason: String

  init(code: Int, reason: String) {
    self.code = code
    self.reason = reason
  }
}

protocol GrpcAsyncParsableCommand: AsyncParsableCommand {
  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply
}

@main
struct Root: AsyncParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "tartctl",
    version: CI.version,
    subcommands: [
      Build.self,
      Create.self,
      Clone.self,
      Set.self,
      Get.self,
      Launch.self,
      List.self,
      Login.self,
      Logout.self,
      IP.self,
      Pull.self,
      Push.self,
      Import.self,
      Export.self,
      Prune.self,
      Rename.self,
      Start.self,
      Stop.self,
      Delete.self,
      FQN.self,
    ])

  @Option(name: [.customLong("address"), .customShort("l")], help: "connect to address")
  var address: String = try! Root.getDefaultServerAddress()

  @Option(name: [.customLong("ca-cert"), .customShort("c")], help: "CA TLS certificate")
  var caCert: String?

  @Option(name: [.customLong("tls-cert"), .customShort("t")], help: "Client TLS certificate")
  var tlsCert: String?

  @Option(name: [.customLong("tls-key"), .customShort("k")], help: "Client private key")
  var tlsKey: String?

  private static func getDefaultServerAddress() throws -> String {
    if let tartdListenAddress = ProcessInfo.processInfo.environment["TARTD_LISTEN_ADDRESS"] {
      return tartdListenAddress
    } else {
      var tartHomeDir: URL

      if let customTartHome = ProcessInfo.processInfo.environment["TART_HOME"] {
        tartHomeDir = URL(fileURLWithPath: customTartHome)
      } else {
        tartHomeDir = FileManager.default
          .homeDirectoryForCurrentUser
          .appendingPathComponent(".tart", isDirectory: true)
      }

      try FileManager.default.createDirectory(at: tartHomeDir, withIntermediateDirectories: true)

      tartHomeDir.append(path: "tard.sock")

      return "unix://\(tartHomeDir.absoluteURL.path())"
    }
  }

  func createClient(on: MultiThreadedEventLoopGroup) throws -> ClientConnection {
    let listeningAddress = URL(string: self.address)
    let connection: ClientConnection.Builder

    if let caCert = caCert, let tlsCert = tlsCert, let tlsKey = tlsKey {
      connection =
        ClientConnection
        .usingTLSBackedByNIOSSL(on: on)
        .withTLS(privateKey: try NIOSSLPrivateKey(file: tlsKey, format: .pem))
        .withTLS(certificateChain: [try NIOSSLCertificate(file: tlsCert, format: .pem)])
        .withTLS(trustRoots: .certificates([try NIOSSLCertificate(file: caCert, format: .pem)]))
    } else {
      connection = ClientConnection.insecure(group: on)
    }

    if let listeningAddress = listeningAddress {
      if listeningAddress.scheme == "unix" {
        let clientSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        let addr = try SocketAddress(unixDomainSocketPath: listeningAddress.path())

        try addr.withSockAddr { addr, size in
          let ret = connect(clientSocket, addr, UInt32(size))

          if ret == -1 {
            throw GrpcError(code: -1, reason: "clientSocket failed: errno = \(errno)")
          }
        }

        let flags = fcntl(clientSocket, F_GETFL, 0)

        if flags == -1 {
          throw GrpcError(code: -1, reason: "clientSocket failed: errno = \(errno)")
        }

        if fcntl(clientSocket, F_SETFL, flags | O_NONBLOCK) != 0 {
          throw GrpcError(code: -1, reason: "fcntl failed: errno = \(errno)")
        }

        return connection.withConnectedSocket(clientSocket)
      } else if listeningAddress.scheme == "tcp" {
        return connection.connect(
          host: listeningAddress.host ?? "127.0.0.1", port: listeningAddress.port ?? 5000)
      } else {
        throw GrpcError(
          code: -1,
          reason:
            "unsupported listening address scheme: \(String(describing: listeningAddress.scheme))")
      }
    }

    throw GrpcError(code: -1, reason: "connection address must be specified")
  }

  func execute(command: inout GrpcAsyncParsableCommand) async throws -> String {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    // Make sure the group is shutdown when we're done with it.
    defer {
      Task {
        try! await group.shutdownGracefully()
      }
    }

    let connection = try createClient(on: group)

    defer {
      Task {
        try! await connection.close().get()
      }
    }

    let grpcClient = Tartd_ServiceNIOClient(channel: connection)
    let reply = try await command.run(client: grpcClient)

    return reply.output
  }
  mutating func run() async throws {
    // Ensure the default SIGINT handled is disabled,
    // otherwise there's a race between two handlers
    signal(SIGINT, SIG_IGN)
    // Handle cancellation by Ctrl+C ourselves
    let task = withUnsafeCurrentTask { $0 }!
    let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT)
    sigintSrc.setEventHandler {
      task.cancel()
    }
    sigintSrc.activate()

    // Set line-buffered output for stdout
    setlinebuf(stdout)

    // Parse and run command
    do {
      guard var command = try Self.parseAsRoot() as? GrpcAsyncParsableCommand else {
        var commandName: String?
        var arguments: [String] = []
        for argument in CommandLine.arguments.dropFirst() {
          if argument.hasPrefix("-") || commandName != nil {
            arguments.append(argument)
          } else if commandName == nil {
            commandName = argument
          }
        }

        var command: any GrpcAsyncParsableCommand = Tart(command: commandName, arguments: arguments)

        print(try await self.execute(command: &command))

        return
      }
      print(try await self.execute(command: &command))
    } catch {
      // Handle any other exception, including ArgumentParser's ones
      Self.exit(withError: error)
    }
  }
}
