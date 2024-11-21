import Dispatch
import Foundation
import SwiftUI
import Virtualization

protocol BuildArguments {
  var name: String { get }
  var cpu: UInt16 { get }
  var memory: UInt64 { get }
  var user: String { get }
  var mainGroup: String { get }
  var insecure: Bool { get }
  var cloudImage: String? { get }
  var remoteContainerServer: String { get }
  var aliasImage: String? { get }
  var fromImage: String? { get }
  var ociImage: String? { get }
  var sshAuthorizedKey: String? { get }
  var vendorData: String? { get }
  var userData: String? { get }
  var networkConfig: String? { get }
  var diskSize: UInt16 { get }
}

struct BuildHandler: TartdCommand, BuildArguments {
  var name: String = ""
  var cpu: UInt16 = 1
  var memory: UInt64 = 512
  var diskSize: UInt16 = 20
  var user: String = "admin"
  var mainGroup: String = "adm"
  var insecure: Bool = false
  var cloudImage: String?
  var aliasImage: String?
  var fromImage: String?
  var ociImage: String?
  var remoteContainerServer: String = defaultSimpleStreamsServer
  var sshAuthorizedKey: String?
  var vendorData: String?
  var userData: String?
  var networkConfig: String?

  func run() async throws {
    let tmpVMDir: VMDirectory = try VMDirectory.temporary()

    // Lock the temporary VM directory to prevent it's garbage collection
    let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
    try tmpVMDirLock.lock()

    try await withTaskCancellationHandler(
      operation: {
        try await VMBuilder.buildVM(vmName: self.name, vmDir: tmpVMDir, arguments: self)
        try VMStorageLocal().move(name, from: tmpVMDir)
      },
      onCancel: {
        try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
      })
  }
}
