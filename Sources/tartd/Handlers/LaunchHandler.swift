import Foundation

struct LaunchHandler: TartdCommand, BuildArguments {
  var name: String
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
  var sshAuthorizedKey: String?
  var remoteContainerServer: String = defaultSimpleStreamsServer
  var vendorData: String?
  var userData: String?
  var networkConfig: String?
  var dir: [String] = []
  var netBridged: [String] = []
  var netSoftnet: Bool = false
  var netSoftnetAllow: String?
  var netHost: Bool = false

  func launch() throws {
    let vmDir = try VMStorageLocal().open(self.name)
    let lock = try vmDir.lock()

    if try !lock.trylock() {
      throw RuntimeError.VMAlreadyRunning("VM \"\(name)\" is already running!")
    }

    var arguments: [String] = ["--no-graphics", "--no-audio", "--nested"]

    // now VM state will return "running" so we can unlock
    try lock.unlock()

    for dir in self.dir {
      arguments.append("--dir=\(dir)")
    }

    for net in self.netBridged {
      arguments.append("--net-bridged=\(net)")
    }

    if self.netSoftnet {
      arguments.append("--net-softnet")
    }

    if let netSoftnetAllow = self.netSoftnetAllow {
      arguments.append("--net-softnet-allow=\(netSoftnetAllow)")
    }

    if self.netHost {
      arguments.append("--net-host")
    }

    var config: [String: Any] = try Dictionary(contentsOf: vmDir.configURL) as [String: Any]
    config["runningArguments"] = arguments
    try config.write(to: vmDir.configURL)

    try StartHandler.startVM(vmDir: vmDir)
  }

  func run() async throws  -> String{
    let tmpVMDir: VMDirectory = try VMDirectory.temporary()

    // Lock the temporary VM directory to prevent it's garbage collection
    let tmpVMDirLock = try FileLock(lockURL: tmpVMDir.baseURL)
    try tmpVMDirLock.lock()

    try await withTaskCancellationHandler(
      operation: {
        try await VMBuilder.buildVM(vmName: self.name, vmDir: tmpVMDir, arguments: self)
        try VMStorageLocal().move(name, from: tmpVMDir)
        try launch()
      },
      onCancel: {
        try? FileManager.default.removeItem(at: tmpVMDir.baseURL)
      })

    return "launched \(name)"
  }

}
