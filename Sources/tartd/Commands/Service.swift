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

let tartDSignature = "org.cirruslabs.tartd"

class StandardOutput {
  let standardOutput: DataWriteStream
  let savedStdout: Int32
  let savedStderr: Int32
  let savedOutPipe: Pipe
  let savedErrPipe: Pipe
  let outSemaphore: DispatchSemaphore
  let errSemaphore: DispatchSemaphore
  
  init() throws {
    Service.SyncSemaphore.wait()

    self.savedOutPipe = Pipe()
    self.savedErrPipe = Pipe()
    self.outSemaphore = DispatchSemaphore(value: 0)
    self.errSemaphore = DispatchSemaphore(value: 0)
    self.standardOutput = DataWriteStream()
    self.savedStdout = try StandardOutput.captureStandartOutput(fd: STDOUT_FILENO, output: self.standardOutput, outPipe: self.savedOutPipe, sema: self.outSemaphore)
    self.savedStderr = try StandardOutput.captureStandartOutput(fd: STDERR_FILENO, output: self.standardOutput, outPipe: self.savedErrPipe, sema: self.errSemaphore)
  }
  
  private static func captureStandartOutput(fd: Int32, output: DataWriteStream, outPipe: Pipe, sema: DispatchSemaphore) throws -> Int32 {
    outPipe.fileHandleForReading.readabilityHandler = { fileHandle in
      let data = fileHandle.availableData
      
      if data.isEmpty  { // end-of-file condition
        fileHandle.readabilityHandler = nil
        sema.signal()
      } else {
        try! output.write(data)
      }
    }
    
    // Redirect
    setvbuf(fd == STDOUT_FILENO ? stdout : stderr, nil, _IONBF, 0)
    
    let savedOutput = dup(fd)
    
    dup2(outPipe.fileHandleForWriting.fileDescriptor, fd)
    
    return savedOutput
  }
  
  func closeOutput() {
    dup2(savedStdout, STDOUT_FILENO)
    try! savedOutPipe.fileHandleForWriting.close()
    close(savedStdout)
    outSemaphore.wait() // Wait until read handler is done
    
    dup2(savedStderr, STDOUT_FILENO)
    try! savedErrPipe.fileHandleForWriting.close()
    close(savedStderr)
    errSemaphore.wait() // Wait until read handler is done
    
    Service.SyncSemaphore.signal()
  }
}

class ServiceError : Error {
  let description: String

  init(_ what: String) {
    self.description = what
  }
}

struct Service : ParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Tart daemon as launchctl agent",
                                                  subcommands: [Install.self, Listen.self])
  static let SyncSemaphore = DispatchSemaphore(value: 0)
  
  static func getTartHome(asDaemon: Bool) throws -> URL {
    if asDaemon {
      let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .systemDomainMask, true)
      var applicationSupportDirectory = URL(fileURLWithPath: paths.first!, isDirectory: true)
      
      applicationSupportDirectory = URL(fileURLWithPath: tartDSignature,
                                        isDirectory: true,
                                        relativeTo: applicationSupportDirectory)
      try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
      
      return applicationSupportDirectory
    }
    
    return try Config().tartHomeDir
  }
  
  static func getOutputLog(asDaemon: Bool) -> String {
    if asDaemon {
      return "/Library/Logs/tartd.log"
    }
    
    return URL(fileURLWithPath: "tartd.log", relativeTo: try? Config().tartHomeDir).absoluteURL.path()
  }
  
  static func getListenAddress(asDaemon: Bool) throws -> String {
    if let tartdListenAddress = ProcessInfo.processInfo.environment["TARTD_LISTEN_ADDRESS"] {
      return tartdListenAddress
    } else {
      var home = try Service.getTartHome(asDaemon: asDaemon)
      
      home.append(path: "tard.sock")
      
      return "unix://\(home.absoluteURL.path())"
    }
  }

  static func generateClientServerCertificate(subject: String, numberOfYears: Int,
                                              caKeyURL: URL, caCertURL: URL,
                                              serverKeyURL: URL, serverCertURL:URL,
                                              clientKeyURL: URL, clientCertURL: URL) throws {
    let notValidBefore = Date()
    let notValidAfter = notValidBefore.addingTimeInterval(TimeInterval(60 * 60 * 24 * 365 * numberOfYears))
    let rootPrivateKey = P521.Signing.PrivateKey()
    let rootCertKey = Certificate.PrivateKey(rootPrivateKey)
    let rootCertName = try! DistinguishedName {
        CommonName("Tart Daemon Root CA")
    }
    let rootCert = try! Certificate(
        version: .v3,
        serialNumber: .init(),
        publicKey: rootCertKey.publicKey,
        notValidBefore: notValidBefore,
        notValidAfter: notValidAfter,
        issuer: rootCertName,
        subject: rootCertName,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try! Certificate.Extensions {
            Critical(
                BasicConstraints.isCertificateAuthority(maxPathLength: nil)
            )
        },
        issuerPrivateKey: rootCertKey
    )

    let savePrivateKey = { (_ key: P521.Signing.PrivateKey, to: URL) in
      let data = "-----BEGIN RSA PRIVATE KEY-----\n"
                  + key.rawRepresentation.base64EncodedString()
                  + "\n-----END RSA PRIVATE KEY-----"

      FileManager.default.createFile(atPath: to.absoluteURL.path,
                                     contents: data.data(using: .ascii),
                                     attributes: [.posixPermissions : 0o600])
    }

    let subjectName = try DistinguishedName {
      CommonName(subject);
      OrganizationName("Cirrus Labs");
    }

    let serverPrivateKey = P521.Signing.PrivateKey()
    let serverCertKey = Certificate.PrivateKey(serverPrivateKey)
    let serverCertificate = try Certificate(
        version: .v3,
        serialNumber: Certificate.SerialNumber(),
        publicKey: serverCertKey.publicKey,
        notValidBefore: notValidBefore,
        notValidAfter: notValidAfter,
        issuer: rootCertName,
        subject: subjectName,
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
          Critical(
              BasicConstraints.isCertificateAuthority(maxPathLength: nil)
          )
          Critical(
            KeyUsage(digitalSignature: true, keyEncipherment: true, dataEncipherment: true, keyCertSign: true)
          )
          Critical(
            try ExtendedKeyUsage([.serverAuth, .clientAuth])
          )
          SubjectAlternativeNames([
            .dnsName("localhost"),
            .dnsName("*")
          ])
        },
        issuerPrivateKey: rootCertKey)

    let clientPrivateKey = P521.Signing.PrivateKey()
    let clientCertKey = Certificate.PrivateKey(clientPrivateKey)
    let clientCertificate = try Certificate(
        version: .v3,
        serialNumber: Certificate.SerialNumber(),
        publicKey: clientCertKey.publicKey,
        notValidBefore: notValidBefore,
        notValidAfter: notValidAfter,
        issuer: subjectName,
        subject: try DistinguishedName {
          CommonName("Tart client");
          OrganizationName("Cirrus Labs");
        },
        signatureAlgorithm: .ecdsaWithSHA256,
        extensions: try Certificate.Extensions {
          Critical(
              BasicConstraints.isCertificateAuthority(maxPathLength: nil)
          )
          Critical(
            KeyUsage(digitalSignature: true, keyEncipherment: true)
          )
          Critical(
            try ExtendedKeyUsage([.clientAuth])
          )
          SubjectAlternativeNames([
            .dnsName("localhost"),
            .dnsName("*"),
            .ipAddress(ASN1OctetString(contentBytes: [127, 0, 0, 1]))
          ])
        },
        issuerPrivateKey: serverCertKey)

    savePrivateKey(rootPrivateKey, caKeyURL)
    savePrivateKey(serverPrivateKey, serverKeyURL)
    savePrivateKey(clientPrivateKey, clientKeyURL)

    FileManager.default.createFile(atPath: caCertURL.absoluteURL.path(),
                                   contents: try rootCert.serializeAsPEM().pemString.data(using: .ascii),
                                   attributes: [.posixPermissions : 0o600])

    FileManager.default.createFile(atPath: serverCertURL.absoluteURL.path(),
                                   contents: try serverCertificate.serializeAsPEM().pemString.data(using: .ascii),
                                   attributes: [.posixPermissions : 0o644])

    FileManager.default.createFile(atPath: clientCertURL.absoluteURL.path(),
                                   contents: try clientCertificate.serializeAsPEM().pemString.data(using: .ascii),
                                   attributes: [.posixPermissions : 0o644])
  }
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
    init() {
      self.certicate = nil
      self.privateKey = nil
    }
    
    static var configuration = CommandConfiguration(abstract: "Install tart daemon as launchctl agent")

    @Option(name: [.customLong("global"), .customShort("g")], help: "Install agent globally, need sudo")
    var asDaemon: Bool = false

    var certicate: URL?
    var privateKey: URL?

    static func findMe() throws -> String {
      return try shellOut(to: "command", arguments: ["-v", "tart"])
    }

    mutating func createCertificats() throws {
      let certHome: URL = URL(fileURLWithPath: "certs", isDirectory: true, relativeTo: try Service.getTartHome(asDaemon: self.asDaemon))
      let caCertURL = URL(fileURLWithPath: "ca.pem", relativeTo: certHome)
      let caKeyURL = URL(fileURLWithPath: "ca.key", relativeTo: certHome)
      let serverKeyURL: URL = URL(fileURLWithPath: "server.key", relativeTo: certHome)
      let serverCertURL = URL(fileURLWithPath: "server.pem", relativeTo: certHome)
      let clientKeyURL: URL = URL(fileURLWithPath: "client.key", relativeTo: certHome)
      let clientCertURL = URL(fileURLWithPath: "client.pem", relativeTo: certHome)

      if FileManager.default.fileExists(atPath: serverKeyURL.path()) == false {
        try FileManager.default.createDirectory(at: certHome, withIntermediateDirectories: true)
        try Service.generateClientServerCertificate(subject: "Tart daemon", numberOfYears: 1,
                                                    caKeyURL: caKeyURL, caCertURL: caCertURL,
                                                    serverKeyURL: serverKeyURL, serverCertURL: serverCertURL,
                                                    clientKeyURL: clientKeyURL, clientCertURL: clientCertURL)
      }

      self.certicate = serverCertURL
      self.privateKey = serverKeyURL
    }

    mutating func validate() throws {
      try createCertificats()
    }

    mutating func run() throws {
      let listenAddress: String = try Service.getListenAddress(asDaemon: self.asDaemon)
      let outputLog: String = Service.getOutputLog(asDaemon: self.asDaemon)
      let tartHome: URL = try Service.getTartHome(asDaemon: self.asDaemon)
      let agent = LaunchAgent(label: tartDSignature,
                              programArguments: [
                                try Install.findMe(),
                                "listen",
                                "--address",
                                listenAddress,
                                "--tls-cert",
                                self.certicate!.path(),
                                "--tls-key",
                                self.privateKey!.path()
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

      if self.asDaemon {
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

    @Option(name: [.customLong("tls-cert"), .customShort("c")], help: "Server TLS certificate")
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
      } else if let tartdListenAddress = ProcessInfo.processInfo.environment["TARTD_LISTEN_ADDRESS"] {
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

      builder.withServiceProviders([GreeterTartd()])

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
