
import Foundation
import GRPC
import ArgumentParser

public protocol TartdCommand {
  mutating func run() async throws
}

public protocol CreateTartdCommand {
  func createCommand() -> TartdCommand
}

private func saveToTempFile(_ data: Data) throws -> String {
  let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
  
  try data.write(to: url)

  return url.absoluteURL.path()
}

extension Tartd_BuildRequest : TartdCommand {

  init (command: Build) throws {
    self.name = command.name
    self.cpu = Int32(command.cpu)
    self.memory = Int32(command.memory)
    self.diskSize = Int32(command.diskSize)
    self.user = command.user
    self.mainGroup = command.mainGroup
    self.insecure = command.insecure
    self.remoteContainerServer = command.remoteContainerServer

    if let cloudImage = command.cloudImage {
      self.cloudImage = cloudImage
    }

    if let aliasImage = command.aliasImage {
      self.aliasImage = aliasImage
    }

    if let fromImage = command.fromImage {
      self.fromImage = fromImage
    }

    if let ociImage = command.ociImage {
      self.fromImage = ociImage
    }

    if let sshAuthorizedKey = command.sshAuthorizedKey {
      self.sshAuthorizedKey = try Data(contentsOf: URL(filePath: sshAuthorizedKey))
    }

    if let vendorData = command.vendorData {
      self.vendorData = try Data(contentsOf: URL(filePath: vendorData))
    }

    if let userData = command.userData {
      self.userData = try Data(contentsOf: URL(filePath: userData))
    }

    if let networkConfig = command.networkConfig {
      self.networkConfig = try Data(contentsOf: URL(filePath: networkConfig))
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command: Build = Build()

    command.name = self.name
    
    if self.hasCpu {
      command.cpu = UInt16(self.cpu)
    }
    
    if self.hasMemory {
      command.memory = UInt64(self.memory)
    }

    if self.hasDiskSize {
      command.diskSize = UInt16(self.diskSize)
    }

    if self.hasUser {
      command.user = self.user
    }
    
    if self.hasInsecure {
      command.insecure = self.insecure
    }
    
    if self.hasCloudImage {
      command.cloudImage = self.cloudImage
    }
    
    if self.hasAliasImage {
      command.aliasImage = self.aliasImage
    }
    
    if self.hasFromImage {
      command.fromImage = self.fromImage
    }
    
    if self.hasOciImage {
      command.ociImage = self.ociImage
    }

    if self.hasRemoteContainerServer {
      command.remoteContainerServer = self.remoteContainerServer
    }
          
    if self.hasSshAuthorizedKey {
      command.sshAuthorizedKey = try? saveToTempFile(self.sshAuthorizedKey)
    }
    
    if self.hasUserData {
      command.userData = try? saveToTempFile(self.userData)
    }

    if self.hasVendorData {
      command.vendorData = try? saveToTempFile(self.vendorData)
    }

    if self.hasNetworkConfig {
      command.networkConfig = try? saveToTempFile(self.networkConfig)
    }
    
    return command
  }
}

extension Tartd_CloneRequest : TartdCommand{
  init (command: Clone) throws {
    self.newName = command.newName
    self.sourceName = command.sourceName
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Clone()
    
    command.newName = self.newName
    command.sourceName = self.sourceName

    if self.hasDeduplicate {
       command.deduplicate = self.deduplicate
    }

    if self.hasInsecure {
      command.insecure = self.insecure
    }
    
    if self.hasConcurrency {
      command.concurrency = UInt(self.concurrency)
    }
    
    return command
  }
}

extension Tartd_CreateRequest : TartdCommand {
  init (command: Create) throws {
    self.name = command.name
    self.linux = command.linux
    self.diskSize = Int32(self.diskSize)
    
    if let fromIpsw = command.fromIPSW {
      self.fromIpsw = fromIpsw
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Create()
    
    command.name = self.name
    
    if self.hasLinux {
      command.linux = self.linux
    }
    
    if self.hasFromIpsw {
      command.fromIPSW = self.fromIpsw
    }

    if self.hasDiskSize {
        command.diskSize = UInt16(self.diskSize)
    }

    return command
  }
}

extension Tartd_DeleteRequest : TartdCommand {
  init (command: Delete) throws {
    self.name = command.name
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Delete()
    
    command.name = self.name

    return command
  }
}

extension Tartd_FqnRequest : TartdCommand {
  init (command: FQN) throws {
    self.name = command.name
  }

  func createCommand() -> AsyncParsableCommand {
    var command = FQN()
    
    command.name = self.name
    
    return command
  }
}

extension Tartd_GetRequest : TartdCommand {
  init (command: Get) throws {
    self.name = command.name

    if command.format == .json {
      self.format = .json
    } else if self.format == .text {
      self.format = .text
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Get()
    
    command.name = self.name

    if self.hasFormat {
      if self.format == .json {
        command.format = .json
      } else if self.format == .text {
        command.format = .text
      }
    }

    return command
  }
}

extension Tartd_ExportRequest : TartdCommand {
  init (command: Export) {
    self.name = command.name

    if let path = command.path {
      self.path = path
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Export()
    
    command.name = self.name
    
    if self.hasPath {
      command.path = self.path
    }

    return command
  }
}

extension Tartd_ImportRequest : TartdCommand {
  init (command: Import) {
    self.name = command.name
    self.path = command.path
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Import()
    
    command.name = self.name
    command.path = self.path

    return command
  }
}

extension Tartd_IPRequest : TartdCommand {
  init (command: IP) {
    self.name = command.name
    self.wait = Int32(command.wait)

    if command.resolver == .dhcp {
      self.resolver = .dhcp
    } else if command.resolver == .arp {
      self.resolver = .arp
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = IP()
    
    command.name = self.name
    
    if self.hasResolver {
      if self.resolver == .dhcp {
        command.resolver = .dhcp
      } else if self.resolver == .arp {
        command.resolver = .arp
      }
    }

    if self.hasWait {
      command.wait = UInt16(self.wait)
    }

    return command
  }
}

extension Tartd_LaunchRequest : TartdCommand {
  init (command: Launch) throws {
    self.name = command.name
    self.cpu = Int32(command.cpu)
    self.memory = Int32(command.memory)
    self.diskSize = Int32(command.diskSize)
    self.user = command.user
    self.mainGroup = command.mainGroup
    self.insecure = command.insecure
    self.remoteContainerServer = command.remoteContainerServer
    self.dir = command.dir
    self.netBridged = command.netBridged
    self.netSofnet = command.netSoftnet
    self.netHost = command.netHost

    if let netSoftnetAllow: String = command.netSoftnetAllow {
      self.netSoftnetAllow = netSoftnetAllow
    }

    if let cloudImage: String = command.cloudImage {
      self.cloudImage = cloudImage
    }

    if let aliasImage = command.aliasImage {
      self.aliasImage = aliasImage
    }

    if let fromImage = command.fromImage {
      self.fromImage = fromImage
    }

    if let ociImage = command.ociImage {
      self.fromImage = ociImage
    }

    if let sshAuthorizedKey = command.sshAuthorizedKey {
      self.sshAuthorizedKey = try Data(contentsOf: URL(filePath: sshAuthorizedKey))
    }

    if let vendorData = command.vendorData {
      self.vendorData = try Data(contentsOf: URL(filePath: vendorData))
    }

    if let userData = command.userData {
      self.userData = try Data(contentsOf: URL(filePath: userData))
    }

    if let networkConfig = command.networkConfig {
      self.networkConfig = try Data(contentsOf: URL(filePath: networkConfig))
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Launch()

    command.name = self.name
    command.dir = self.dir
    command.netBridged = self.netBridged
    command.netHost = self.netHost

    if self.hasNetSofnet {
      command.netSoftnet = self.netSofnet
    }

    if self.hasCpu {
      command.cpu = UInt16(self.cpu)
    }
    
    if self.hasMemory {
      command.memory = UInt64(self.memory)
    }

    if self.hasDiskSize {
      command.diskSize = UInt16(self.diskSize)
    }

    if self.hasUser {
      command.user = self.user
    }
    
    if self.hasInsecure {
      command.insecure = self.insecure
    }
    
    if self.hasCloudImage {
      command.cloudImage = self.cloudImage
    }
    
    if self.hasAliasImage {
      command.aliasImage = self.aliasImage
    }
    
    if self.hasFromImage {
      command.fromImage = self.fromImage
    }
    
    if self.hasOciImage {
      command.ociImage = self.ociImage
    }

    if self.hasRemoteContainerServer {
      command.remoteContainerServer = self.remoteContainerServer
    }
          
    if self.hasSshAuthorizedKey {
      command.sshAuthorizedKey = try? saveToTempFile(self.sshAuthorizedKey)
    }
    
    if self.hasUserData {
      command.userData = try? saveToTempFile(self.userData)
    }

    if self.hasVendorData {
      command.vendorData = try? saveToTempFile(self.vendorData)
    }

    if self.hasNetworkConfig {
      command.networkConfig = try? saveToTempFile(self.networkConfig)
    }
    
    return command
  }
}

extension Tartd_ListRequest : TartdCommand {
  init (command: List) {
    self.quiet = command.quiet

    if command.format == .json {
      self.format = .json
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = List()
    
    command.quiet = self.quiet
    
    if self.hasFormat {
      if self.format == .json {
        command.format = .json
      }
    }

    return command
  }
}

extension Tartd_LoginRequest : TartdCommand {
  init (command: Login) {
    self.host = command.host
    self.insecure = command.insecure
    self.noValidate = command.noValidate

    if let username = command.username {
      self.username = username
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Login()
    
    command.host = self.host
    command.username = self.username
    command.insecure = self.insecure
    command.noValidate = self.noValidate

    return command
  }
}

extension Tartd_LogoutRequest : TartdCommand {
  init (command: Logout) {
    self.host = command.host
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Logout()
    
    command.host = self.host

    return command
  }
}

extension Tartd_PruneRequest : TartdCommand {
  init (command: Prune) {
    self.entries = command.entries

    if let olderThan = command.olderThan {
      self.olderThan = Int32(olderThan)
    }

    if let cacheBudget = command.cacheBudget {
      self.cacheBudget = Int32(cacheBudget)
    }

    if let spaceBudget = command.spaceBudget {
      self.spaceBudget = Int32(spaceBudget)
    }
  }
  
  func createCommand() -> AsyncParsableCommand {
    var command = Prune()
    
    if self.hasEntries {
      command.entries = self.entries
    }

    if self.hasOlderThan {
      command.olderThan = UInt(self.olderThan)
    }

    if self.hasCacheBudget {
      command.cacheBudget = UInt(self.cacheBudget)
    }

    if self.hasSpaceBudget {
      command.spaceBudget = UInt(self.spaceBudget)
    }

    return command
  }
}

extension Tartd_PullRequest : TartdCommand {
  init (command: Pull) {
    self.remoteName = command.remoteName
    self.deduplicate = command.deduplicate
    self.insecure = command.insecure
    self.concurrency = Int32(concurrency)
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Pull()
    
    command.remoteName = self.remoteName
    command.deduplicate = self.deduplicate
    command.insecure = self.insecure
    
    if self.hasConcurrency {
      command.concurrency = UInt(self.concurrency)
    }

    return command
  }
}

extension Tartd_PushRequest : TartdCommand{
  init (command: Push) {
    self.localName = command.localName
    self.remoteNames = command.remoteNames
    self.insecure = command.insecure
    self.concurrency = Int32(concurrency)
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Push()
    
    command.localName = self.localName
    command.remoteNames = self.remoteNames
    command.insecure = self.insecure
    command.populateCache = self.populateCache

    if self.hasConcurrency {
      command.concurrency = UInt(self.concurrency)
    }

    return command
  }
}

extension Tartd_RenameRequest : TartdCommand{
  init (command: Rename) throws {
    self.name = command.name
    self.newName = command.newName
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Rename()
    
    command.name = self.newName
    command.newName = self.newName

    return command
  }
}

extension Tartd_VMDisplayConfig {
  init (width: Int32, height: Int32) {
    self.width = width
    self.height = height
  }
}

extension Tartd_SetRequest : TartdCommand {
  init (command: Set) {
    self.name = command.name
    self.randomMac = command.randomMAC
    self.randomSerial = command.randomSerial

    if let cpu = command.cpu {
      self.cpu = Int32(cpu)
    }
    
    if let memory = command.memory {
      self.memory = Int32(memory)
    }
    
    if let disk = command.disk {
      self.disk = disk
    }
    
    if let display = command.display {
      self.display = Tartd_VMDisplayConfig(
        width: Int32(display.width),
        height: Int32(display.height)
      )
    }
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Set()
    
    command.name = self.name
    command.randomMAC = self.randomMac
    command.randomSerial = self.randomSerial

    if self.hasCpu {
      command.cpu = UInt16(self.cpu)
    }
    
    if self.hasMemory {
      command.memory = UInt64(self.memory)
    }
    
    if self.hasDisk {
      command.disk = self.disk
    }
    
    if self.hasDisplay {
      command.display = VMDisplayConfig(
        width: Int(self.display.width),
        height: Int(self.display.height)
      )
    }

    return command
  }
}

extension Tartd_StartRequest : TartdCommand {
  init (command: Start) {
    self.name = command.name
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Start()
    
    command.name = self.name
    
    return command
  }
}

extension Tartd_StopRequest : TartdCommand {
  init (command: Stop) {
    self.name = command.name
    self.timeout = Int32(command.timeout)
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Stop()
    
    command.name = self.name
    
    if self.hasTimeout {
      command.timeout = UInt64(self.timeout)
    }

    return command
  }
}

extension Tartd_SuspendRequest : TartdCommand {
  init (command: Suspend) {
    self.name = command.name
  }

  func createCommand() -> AsyncParsableCommand {
    var command = Suspend()
    
    command.name = self.name
    
    return command
  }
}
