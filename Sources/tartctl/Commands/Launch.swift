import ArgumentParser
import Foundation

struct Launch : GrpcAsyncParsableCommand {
  static var configuration = CommandConfiguration(abstract: "Create a linux VM, initialize it with cloud-init and launch in background")

  @Argument(help: "VM name")
  var name: String

  @Option(name: [.long, .customShort("c")], help: "Number of VM CPUs")
  var cpu: UInt16 = 1

  @Option(name: [.long, .customShort("m")], help: "VM memory size in megabytes")
  var memory: UInt64 = 512

  @Option(name: [.long, .customShort("d")], help: ArgumentHelp("Disk size in GB"))
  var diskSize: UInt16 = 20

  @Option(name: [.long, .customShort("u")], help: "The user to use for the VM")
  var user: String = "admin"

  @Option(name: [.long, .customShort("g")], help: "The main existing group for the user")
  var mainGroup: String = "adm"

  @Flag(name: [.long, .customShort("k")], help: ArgumentHelp("Tell if the user admin allow clear password"))
  var insecure: Bool = false

  @Option(name: [.long, .customLong("cloud")], help: ArgumentHelp("create a linux VM using a qcow2 cloud-image file or URL", valueName: "path"))
  var cloudImage: String?

  @Option(name: [.long, .customLong("alias")], help: ArgumentHelp("create a linux VM using a linux container cloud-image alias", valueName: "alias"))
  var aliasImage: String?

  @Option(name: [.long, .customLong("image")], help: ArgumentHelp("create a linux VM using a raw image file or URL", valueName: "path"))
  var fromImage: String?

  @Option(name: [.long, .customLong("oci")], help: ArgumentHelp("create a linux VM using an OCI image", valueName: "path"))
  var ociImage: String?

  @Option(name: [.long, .customShort("i")], help: ArgumentHelp("Optional ssh-authorized-key file path for linux VM", valueName: "path"))
  var sshAuthorizedKey: String?

  @Option(name: [.customLong("remote"), .customShort("r")], help: ArgumentHelp("URL of images linuxcontainer", valueName: "url"))
  var remoteContainerServer: String = defaultSimpleStreamsServer

  @Option(help: ArgumentHelp("Optional cloud-init vendor-data file path for linux VM", valueName: "path"))
  var vendorData: String?

  @Option(help: ArgumentHelp("Optional cloud-init user-data file path for linux VM", valueName: "path"))
  var userData: String?

  @Option(help: ArgumentHelp("Optional cloud-init network-config file path for linux VM", valueName: "path"))
  var networkConfig: String?

  @Option(help: ArgumentHelp("Additional directory shares with an optional read-only and mount tag options (e.g. --dir=\"~/src/build\" or --dir=\"~/src/sources:ro\")", discussion: """
  Requires host to be macOS 13.0 (Ventura) or newer. macOS guests must be running macOS 13.0 (Ventura) or newer too.

  Options are comma-separated and are as follows:

  * ro — mount this directory share in read-only mode instead of the default read-write (e.g. --dir=\"~/src/sources:ro\")

  * tag=<TAG> — by default, the \"com.apple.virtio-fs.automount\" mount tag is used for all directory shares. On macOS, this causes the directories to be automatically mounted to "/Volumes/My Shared Files" directory. On Linux, you have to do it manually: "mount -t virtiofs com.apple.virtio-fs.automount /mount/point".

  Mount tag can be overridden by appending tag property to the directory share (e.g. --dir=\"~/src/build:tag=build\" or --dir=\"~/src/build:ro,tag=build\"). Then it can be mounted via "mount_virtiofs build ~/build" inside guest macOS and "mount -t virtiofs build ~/build" inside guest Linux.

  In case of passing multiple directories per mount tag it is required to prefix them with names e.g. --dir=\"build:~/src/build\" --dir=\"sources:~/src/sources:ro\". These names will be used as directory names under the mounting point inside guests. For the example above it will be "/Volumes/My Shared Files/build" and "/Volumes/My Shared Files/sources" respectively.
  """, valueName: "[name:]path[:options]"))
  var dir: [String] = []

  @Option(help: ArgumentHelp("""
  Use bridged networking instead of the default shared (NAT) networking \n(e.g. --net-bridged=en0 or --net-bridged=\"Wi-Fi\")
  """, discussion: """
  Specify "list" as an interface name (--net-bridged=list) to list the available bridged interfaces.
  """, valueName: "interface name"))
  var netBridged: [String] = []

  @Flag(help: ArgumentHelp("Use software networking instead of the default shared (NAT) networking",
                           discussion: "Learn how to configure Softnet for use with Tart here: https://github.com/cirruslabs/softnet"))
  var netSoftnet: Bool = false

  @Option(help: ArgumentHelp("Comma-separated list of CIDRs to allow the traffic to when using Softnet isolation\n(e.g. --net-softnet-allow=192.168.0.0/24)", valueName: "comma-separated CIDRs"))
  var netSoftnetAllow: String?

  @Flag(help: ArgumentHelp("Restrict network access to the host-only network"))
  var netHost: Bool = false

  func validate() throws {
    if name.contains("/") {
      throw ValidationError("\(name) should be a local name")
    }

    if fromImage == nil && cloudImage == nil && ociImage == nil && aliasImage == nil{
      throw ValidationError("Please specify either --from-img url or --cloud-image url or --oci-image url or --alias-image container image!")
    }

    var count = 0

    if fromImage != nil {
      count += 1
    }

    if cloudImage != nil {
      count += 1
    }

    if ociImage != nil{
      count += 1
    }

    if aliasImage != nil{
      count += 1
    }

    if count > 1 {
      throw ValidationError("--from-img url and --cloud-image url and --oci-image url and --alias-image are mutually exclusive!")
    }

    // check that not more than one network option is specified
    var netFlags = 0
    if netBridged.count > 0 { netFlags += 1 }
    if netSoftnet { netFlags += 1 }
    if netHost { netFlags += 1 }

    if netFlags > 1 {
      throw ValidationError("--net-bridged, --net-softnet and --net-host are mutually exclusive")
    }
  }

  mutating func run() async throws {
    throw GrpcError(code: 0, reason: "nothing here")
  }

  mutating func run(client: Tartd_ServiceNIOClient) async throws -> Tartd_TartReply {
    return try await client.launch(Tartd_LaunchRequest(command: self)).response.get()
  }

}
