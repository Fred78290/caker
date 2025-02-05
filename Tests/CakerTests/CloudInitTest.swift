import XCTest

@testable import NIOCore
@testable import NIOPosix
@testable import caked
@testable import GRPCLib
@testable import NIOPortForwarding

let ubuntuCloudImage = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img"
let defaultSimpleStreamsServer = "https://images.linuxcontainers.org/"
let networkConfig = 
"""
#cloud-config
network:
  version: 2
  ethernets:
    enp0s1:
      match:
        name: enp0s1
      dhcp4: true
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
	let networkConfigPath: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("network-config.yaml").absoluteURL
	let userDataPath: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("user-data.yaml").absoluteURL
	let group: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

	override func setUp() {
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

	override func tearDown() {
		try? group.syncShutdownGracefully()
	}

	/*
	 * Assume sudoer
	 */
	static func getSharedNetAddress() throws -> String {
		do {
			return try Shell.execute(to: "sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address")
		} catch {
			Logger.error(error)
			throw error
		}
	}

	/*
	 * Helper to retrieve the correct finger print
	 */
	static func getFingerPrint(url: URL, product: String) throws -> String{
		do {
			return try Shell.execute(to: "curl -Ls \(url.absoluteString) | jq -r 'last(.products.\"\(product)\".versions|to_entries[]|.value.items.\"disk.qcow2\".sha256)' -r")
		} catch {
			Logger.error(error)

			throw error
		}
	}

	func testSimpleStreamsFindImage() async throws {
		if let linuxContainerURL: URL = URL(string: defaultSimpleStreamsServer) {
			let simpleStream: SimpleStreamProtocol = try await SimpleStreamProtocol(baseURL: linuxContainerURL)
			let arch = Architecture.current().rawValue
			let fingerprint = try CloudInitTests.getFingerPrint(url: try simpleStream.GetImagesIndexURL(), product: "ubuntu:noble:\(arch):cloud")
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: "ubuntu/noble/cloud")

			XCTAssertEqual(image.fingerprint, fingerprint)

			let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("alpine.img").absoluteURL

			try await image.retrieveSimpleStreamImageAndConvert(to: temporaryURL)

			print("saved to \(temporaryURL.path())")

			XCTAssert(FileManager.default.fileExists(atPath: temporaryURL.path()), temporaryURL.path())
		}
	}

	func buildVM(name: String, image: String) async throws {
		var options: BuildOptions = BuildOptions()
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory()

		options.name = name
		options.autostart = true
		options.displayRefit = true
		options.cpu = 1
		options.memory = 512
		options.diskSize = 20
		options.user = "admin"
		options.password = nil
		options.mainGroup = "admin"
		options.clearPassword = true
		options.image = image
		options.nested = true
		options.sshAuthorizedKey = NSString(string: "~/.ssh/id_rsa.pub").expandingTildeInPath
		options.userData = self.userDataPath.path()
		options.vendorData = nil
		options.networkConfig = self.networkConfigPath.path()
		options.forwardedPort = [
			ForwardedPort(argument: "2222:22/tcp")
		]
		options.mounts = []
		options.netBridged = []
		//options.netSoftnet = false
		//options.netSoftnetAllow = nil
		//options.netHost = false

		try await VMBuilder.buildVM(vmName: options.name, vmLocation: tempVMLocation, options: options)

		XCTAssertNoThrow(try StorageLocation(asSystem: false).relocate(options.name, from: tempVMLocation))
	}

	func testBuildVMWithCloudImage() async throws {
		try await buildVM(name: "noble-cloud-image", image: ubuntuCloudImage)
	}

	func testBuildVMWithQCow2() async throws {
		let tempLocation = try await CloudImageConverter.downloadLinuxImage(fromURL: URL(string: ubuntuCloudImage)!,
			toURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("qcow2"))
		
		defer {
			if let exists = try? tempLocation.exists() {
				if exists {
					try? FileManager.default.removeItem(at: tempLocation)
				}
			}
		}

		try await buildVM(name: "noble-qcow2-image", image: "qcow2://\(tempLocation.path())")
	}

	func testBuildVMWithOCI() async throws {
		try await buildVM(name: "noble-oci-image", image: "ocis://ghcr.io/cirruslabs/ubuntu:latest")
	}

	func testBuildVMWithContainer() async throws {
		try await buildVM(name: "noble-container-image", image: "images:ubuntu/noble/cloud")
	}

	func testBuildVMWithLXDContainers() async throws {
		try await buildVM(name: "noble-lxd-image", image: "ubuntu:noble")
	}

	func testBuildMustFail() async throws {
		do {
			try await buildVM(name: "noble-must-fail-image", image: "zlib://devregistry.aldunelabs.com/ubuntu:latest")
	        XCTFail("Error needs to be thrown")
		} catch {
		}
	}

	func testLaunchVMWithCloudImage() async throws {
		try await buildVM(name: "noble-cloud-image", image: ubuntuCloudImage)
		let vmLocation: VMLocation = try StorageLocation(asSystem: false).find("noble-cloud-image")
		let eventLoop = self.group.any()
		let promise = eventLoop.makePromise(of: Void.self)

		promise.futureResult.whenComplete { result in
			switch result {
				case .success:
					break
				case let .failure(err):
					XCTFail(err.localizedDescription)
			}
		}

		PortForwardingServer.createPortForwardingServer(on: self.group)

		let runningIP = StartHandler.startVM(on: eventLoop, vmLocation: vmLocation, waitIPTimeout: 180, promise: promise)
		
		runningIP.whenComplete { result in
			switch result {
				case let .success(ip):
					print("running ip: \(ip)")
				case let .failure(err):
					XCTFail(err.localizedDescription)
			}
		}

		// Wait VM die
		XCTAssertNoThrow(try promise.futureResult.wait())
	}
}
