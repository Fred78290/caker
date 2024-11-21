
import Foundation
import GRPC
import ArgumentParser
import GRPCLib

private func saveToTempFile(_ data: Data) throws -> String {
  let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("txt")
  
  try data.write(to: url)

  return url.absoluteURL.path()
}

extension Tartd_BuildRequest {

  init (command: Build) throws {
	self.init()
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
}

extension Tartd_CloneRequest {
  init (command: Clone) throws {
	self.init()
    self.newName = command.newName
    self.sourceName = command.sourceName
  }
}

extension Tartd_CreateRequest {
  init (command: Create) throws {
	self.init()
    self.name = command.name
    self.linux = command.linux
    self.diskSize = Int32(self.diskSize)
    
    if let fromIpsw = command.fromIPSW {
      self.fromIpsw = fromIpsw
    }
  }
}

extension Tartd_DeleteRequest {
  init (command: Delete) throws {
	self.init()
    self.name = command.name
  }
}

extension Tartd_FqnRequest {
  init (command: FQN) throws {
	self.init()
    self.name = command.name
  }
}

extension Tartd_GetRequest {
  init (command: Get) throws {
	self.init()
    self.name = command.name

    if command.format == .json {
      self.format = .json
    } else if self.format == .text {
      self.format = .text
    }
  }
}

extension Tartd_ExportRequest {
  init (command: Export) {
	self.init()
    self.name = command.name

    if let path = command.path {
      self.path = path
    }
  }
}

extension Tartd_ImportRequest {
  init (command: Import) {
	self.init()
    self.name = command.name
    self.path = command.path
  }
}

extension Tartd_IPRequest {
  init (command: IP) {
	self.init()
    self.name = command.name
    self.wait = Int32(command.wait)

    if command.resolver == .dhcp {
      self.resolver = .dhcp
    } else if command.resolver == .arp {
      self.resolver = .arp
    }
  }
}

extension Tartd_LaunchRequest {
  init (command: Launch) throws {
	self.init()
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
}

extension Tartd_ListRequest {
  init (command: List) {
	self.init()
    self.quiet = command.quiet

    if command.format == .json {
      self.format = .json
    }
  }
}

extension Tartd_LoginRequest {
  init (command: Login) {
	self.init()
    self.host = command.host
    self.insecure = command.insecure
    self.noValidate = command.noValidate

    if let username = command.username {
      self.username = username
    }
  }
}

extension Tartd_LogoutRequest {
  init (command: Logout) {
	self.init()
    self.host = command.host
  }
}

extension Tartd_PruneRequest {
  init (command: Prune) {
	self.init()
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
}

extension Tartd_PullRequest {
  init (command: Pull) {
	  self.init()
    self.remoteName = command.remoteName
    self.deduplicate = command.deduplicate
    self.insecure = command.insecure
    self.concurrency = Int32(concurrency)
  }
}

extension Tartd_PushRequest{
  init (command: Push) {
	  self.init()
    self.localName = command.localName
    self.remoteNames = command.remoteNames
    self.insecure = command.insecure
    self.concurrency = Int32(concurrency)
  }
}

extension Tartd_RenameRequest{
  init (command: Rename) throws {
	  self.init()
    self.name = command.name
    self.newName = command.newName
  }

}

extension Tartd_VMDisplayConfig {
  init (width: Int32, height: Int32) {
	  self.init()
    self.width = width
    self.height = height
  }
}

extension Tartd_SetRequest {
  init (command: Set) {
	  self.init()
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
}

extension Tartd_StartRequest {
  init (command: Start) {
	  self.init()
    self.name = command.name
  }
}

extension Tartd_StopRequest {
  init (command: Stop) {
	  self.init()
    self.name = command.name
    self.timeout = Int32(command.timeout)
  }
}

extension Tartd_SuspendRequest {
  init (command: Suspend) {
	  self.init()
    self.name = command.name
  }
}
