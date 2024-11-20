import XCTest
import ShellOut
@testable import tart

let networkConfig = 
"""
#cloud-config
network:
  version: 2
  ethernets:
    enp0s1:
      match:
        name: enp0s1
      dhcp4: false
      dhcp-identifier: mac
      addresses:
      - $$Shared_Net_Address$$/24
      nameservers:
        addresses:
        - 8.8.8.8
        search:
        - aldunelabs.com
"""

let userData = 
"""
#cloud-config
package_update: false
package_upgrade: false
timezone: Europe/Paris
write_files:
- content: |
    apiVersion: kubelet.config.k8s.io/v1
    kind: CredentialProviderConfig
    providers:
      - name: ecr-credential-provider
        matchImages:
          - "*.dkr.ecr.*.amazonaws.com"
          - "*.dkr.ecr.*.amazonaws.cn"
          - "*.dkr.ecr-fips.*.amazonaws.com"
          - "*.dkr.ecr.us-iso-east-1.c2s.ic.gov"
          - "*.dkr.ecr.us-isob-east-1.sc2s.sgov.gov"
        defaultCacheDuration: "12h"
        apiVersion: credentialprovider.kubelet.k8s.io/v1
        args:
          - get-credentials
        env:
          - name: AWS_ACCESS_KEY_ID 
            value: HIDDEN
          - name: AWS_SECRET_ACCESS_KEY
            value: HIDDEN
  owner: root:root
  path: /var/lib/rancher/credentialprovider/config.yaml
  permissions: '0644'
runcmd:
- hostnamectl set-hostname openstack-dev-k3s-worker-02
"""

final class CloudInitTests: XCTestCase {
  static let networkConfigPath: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("network-config.yaml").absoluteURL
  static let userDataPath: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("user-data.yaml").absoluteURL

  override class func setUp() {
    do {
      var networkconfig = networkConfig
      let sharedNetAddress = try CloudInitTests.getSharedNetAddress().split(separator: ".")
      let sharedNetAddressStr = sharedNetAddress[0]+"."+sharedNetAddress[1]+"."+sharedNetAddress[2]+".10"

      networkconfig.replace("$$Shared_Net_Address$$", with: sharedNetAddressStr)
      
      try networkconfig.data(using: .ascii)?.write(to: networkConfigPath)
      try userData.data(using: .ascii)?.write(to: userDataPath)
    } catch {
       print(error)
       exit(1)
    }
  }

  /*
  * Assume sudoer
  */
  static func getSharedNetAddress() throws -> String {
    do {
      return try shellOut(to: "sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address")
    } catch {
      let error = error as! ShellOutError

      defaultLogger.appendNewLine(error.message)
      defaultLogger.appendNewLine(error.output)

      throw error
    }
  }

  /*
  * Helper to retrieve the correct finger print
  */
  static func getFingerPrint(url: URL, product: String) throws -> String{
    do {
      return try shellOut(to: "curl -Ls \(url.absoluteString) | jq -r 'last(.products.\"\(product)\".versions|to_entries[]|.value.items.\"disk.qcow2\".sha256)' -r")
    } catch {
      let error = error as! ShellOutError

      defaultLogger.appendNewLine(error.message)
      defaultLogger.appendNewLine(error.output)

      throw error
    }
  }

  func testSimpleStreamsFindImage() async throws {
    if let linuxContainerURL: URL = URL(string: defaultSimpleStreamsServer) {
      let simpleStream: SimpleStreamProtocol = try await SimpleStreamProtocol(baseURL: linuxContainerURL)
      let arch = CurrentArchitecture().rawValue
      let fingerprint = try CloudInitTests.getFingerPrint(url: try simpleStream.GetImagesIndexURL(), product: "ubuntu:noble:\(arch):cloud")
      let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: "ubuntu/noble/cloud")

      XCTAssertEqual(image.fingerprint, fingerprint)

      let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("alpine.img").absoluteURL

      try await image.retrieveSimpleStreamImageAndConvert(to: temporaryURL)

      print("saved to \(temporaryURL.path())")

      XCTAssert(FileManager.default.fileExists(atPath: temporaryURL.path()), temporaryURL.path())
    }
  }

  func testBuildVMWithCloudImage() async throws {
    let tmpVMDir: VMDirectory = try VMDirectory.temporary()

    try await VM.buildVM(vmDir: tmpVMDir,
                         cloudImageURL: URL(string: "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img")!,
                         cpu: 1,
                         memory: 512,
                         diskSizeGB: 10,
                         userName: "admin",
                         insecure: true,
                         sshAuthorizedKey: NSString(string: "~/.ssh/id_rsa.pub").expandingTildeInPath,
                         vendorData: nil,
                         userData: CloudInitTests.userDataPath.path(),
                         networkConfig: CloudInitTests.networkConfigPath.path())

      try VMStorageLocal().move("noble-cloud-image", from: tmpVMDir)
  }

  func testBuildVMWithOCI() async throws {
    let tmpVMDir: VMDirectory = try VMDirectory.temporary()

    try await VM.buildVM(vmDir: tmpVMDir,
                         ociImage: "devregistry.aldunelabs.com/ubuntu:latest",
                         cpu: 1,
                         memory: 512,
                         diskSizeGB: 10,
                         userName: "admin",
                         insecure: true,
                         sshAuthorizedKey: NSString(string: "~/.ssh/id_rsa.pub").expandingTildeInPath,
                         vendorData: nil,
                         userData: CloudInitTests.userDataPath.path(),
                         networkConfig: CloudInitTests.networkConfigPath.path())

      try VMStorageLocal().move("noble-oci-image", from: tmpVMDir)
  }

  func testBuildVMWithContainer() async throws {
    let tmpVMDir: VMDirectory = try VMDirectory.temporary()

    try await VM.buildVM(vmDir: tmpVMDir,
                         remoteContainerServer: "https://images.linuxcontainers.org",
                         aliasImage: "ubuntu/noble/cloud",
                         cpu: 1,
                         memory: 512,
                         diskSizeGB: 10,
                         userName: "admin",
                         insecure: true,
                         sshAuthorizedKey: NSString(string: "~/.ssh/id_rsa.pub").expandingTildeInPath,
                         vendorData: nil,
                         userData: CloudInitTests.userDataPath.path(),
                         networkConfig: CloudInitTests.networkConfigPath.path())

      try VMStorageLocal().move("noble-container-image", from: tmpVMDir)
  }

  func testBuildVMWithLXDContainers() async throws {
    let tmpVMDir: VMDirectory = try VMDirectory.temporary()

    try await VM.buildVM(vmDir: tmpVMDir,
                         remoteContainerServer: "https://cloud-images.ubuntu.com/releases/",
                         aliasImage: "noble",
                         cpu: 1,
                         memory: 512,
                         diskSizeGB: 10,
                         userName: "admin",
                         insecure: true,
                         sshAuthorizedKey: NSString(string: "~/.ssh/id_rsa.pub").expandingTildeInPath,
                         vendorData: nil,
                         userData: CloudInitTests.userDataPath.path(),
                         networkConfig: CloudInitTests.networkConfigPath.path())

      try VMStorageLocal().move("noble-lxd-image", from: tmpVMDir)
  }
}
