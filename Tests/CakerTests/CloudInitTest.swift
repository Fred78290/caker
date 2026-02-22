import XCTest

@testable import CakedLib
@testable import GRPCLib
@testable import NIOCore
@testable import NIOPortForwarding
@testable import NIOPosix
@testable import CakeAgentLib

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

let uuid = UUID().uuidString

final class CloudInitTests: XCTestCase {
	let networkConfigPath: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("network-config.yaml").absoluteURL
	let userDataPath: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("user-data.yaml").absoluteURL
	let group: MultiThreadedEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
	let noble_oci_image = "noble-oci-image-\(uuid)"
	let noble_qcow2_image = "noble-qcow2-image-\(uuid)"
	let noble_container_image = "noble-container-image-\(uuid)"
	let noble_lxd_image = "noble-lxd-image-\(uuid)"
	let noble_cloud_image = "noble-cloud-image-\(uuid)"
	let noble_must_fail_image = "noble-must-fail-image"

	override func setUp() {
		do {
			var networkconfig = networkConfig
			let sharedNetAddress = try CloudInitTests.getSharedNetAddress().split(separator: ".")
			let sharedNetAddressStr = sharedNetAddress[0] + "." + sharedNetAddress[1] + "." + sharedNetAddress[2] + ".10"

			networkconfig.replace("$$Shared_Net_Address$$", with: sharedNetAddressStr)

			try networkconfig.data(using: .ascii)?.write(to: networkConfigPath)
			try userData.data(using: .ascii)?.write(to: userDataPath)
		} catch {
			print(error)
			exit(1)
		}
	}

	override func tearDown() {
		let names = [noble_cloud_image, noble_qcow2_image, noble_oci_image, noble_container_image, noble_lxd_image, noble_must_fail_image]
		let storageLocation: StorageLocation = StorageLocation(runMode: .user)

		for name in names {
			if storageLocation.exists(name) {
				if let location: VMLocation = try? storageLocation.find(name) {
					try? location.delete()
				}
			}
		}

		try? group.syncShutdownGracefully()

	}

	/*
	 * Assume sudoer
	 */
	static func getSharedNetAddress() throws -> String {
		do {
			return try Shell.execute(to: "sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.vmnet.plist Shared_Net_Address")
		} catch {
			Logger(self).error(error)
			throw error
		}
	}

	/*
	 * Helper to retrieve the correct finger print
	 */
	static func getFingerPrint(url: URL, product: String) throws -> String {
		do {
			return try Shell.execute(to: "curl -Ls \(url.absoluteString) | jq -r 'last(.products.\"\(product)\".versions|to_entries[]|.value.items.\"disk.qcow2\".sha256)' -r")
		} catch {
			Logger(self).error(error)

			throw error
		}
	}

	func testSimpleStreamsFindImage() async throws {
		if let linuxContainerURL: URL = URL(string: defaultSimpleStreamsServer) {
			let simpleStream: SimpleStreamProtocol = try await SimpleStreamProtocol(baseURL: linuxContainerURL, runMode: .user)
			let arch = Architecture.current().rawValue
			let fingerprint = try CloudInitTests.getFingerPrint(url: try simpleStream.GetImagesIndexURL(), product: "ubuntu:noble:\(arch):cloud")
			let image: LinuxContainerImage = try await simpleStream.GetImageAlias(alias: "ubuntu/noble/cloud", runMode: .user)

			XCTAssertEqual(image.fingerprint, fingerprint)

			let temporaryURL = try Home(runMode: .user).temporaryDirectory.appendingPathComponent("alpine.img").absoluteURL

			defer {
				try? temporaryURL.delete()
			}

			try await image.retrieveSimpleStreamImageAndConvert(to: temporaryURL, runMode: .user, progressHandler: ProgressObserver.progressHandler)

			print("saved to \(temporaryURL.path)")

			XCTAssert(FileManager.default.fileExists(atPath: temporaryURL.path), temporaryURL.path)
		}
	}

	func buildVM(name: String, image: String) async throws {
		var options: BuildOptions = BuildOptions()
		let tempVMLocation: VMLocation = try VMLocation.tempDirectory(runMode: .user)

		options.name = name
		options.autostart = true
		options.displayRefit = true
		options.cpu = 1
		options.memory = 512
		options.diskSize = 20
		options.attachedDisks = []
		options.user = "admin"
		options.password = nil
		options.mainGroup = "adm"
		options.otherGroup = ["sudo"]
		options.clearPassword = true
		options.image = image
		options.nested = true
		options.autoinstall = false
		options.suspendable = true
		options.sshAuthorizedKey = NSString(string: "~/.ssh/id_rsa.pub").expandingTildeInPath
		options.userData = self.userDataPath.path
		options.vendorData = nil
		options.screenSize = VMScreenSize.standard
		options.dynamicPortForwarding = false
		options.netIfnames = false
		options.networkConfig = self.networkConfigPath.path
		options.consoleURL = nil
		options.mounts = []
		options.networks = []
		options.sockets = []
		options.forwardedPorts = [
			TunnelAttachement(host: 2022, guest: 22, proto: .tcp)
		]

		_ = try await VMBuilder.buildVM(vmName: options.name, location: tempVMLocation, options: options, runMode: .user, queue: nil, progressHandler: ProgressObserver.progressHandler)

		XCTAssertNoThrow(try StorageLocation(runMode: .user).relocate(options.name, from: tempVMLocation))
	}

	func testBuildVMWithCloudImage() async throws {
		try await buildVM(name: noble_cloud_image, image: ubuntuCloudImage)
	}

	func testBuildVMWithQCow2() async throws {
		let tmpQcow2 = try Home(runMode: .user).temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("qcow2")
		let tempLocation = try await CloudImageConverter.downloadLinuxImage(fromURL: URL(string: ubuntuCloudImage)!, toURL: tmpQcow2, runMode: .user, progressHandler: ProgressObserver.progressHandler)

		defer {
			try? tempLocation.delete()
			try? tmpQcow2.delete()
		}

		try await buildVM(name: noble_qcow2_image, image: "qcow2://\(tempLocation.path)")
	}

	func testBuildVMWithOCI() async throws {
		try await buildVM(name: noble_oci_image, image: "ocis://ghcr.io/cirruslabs/ubuntu:latest")
	}

	func testBuildVMWithContainer() async throws {
		try await buildVM(name: noble_container_image, image: "images:ubuntu/noble/cloud")
	}

	func testBuildVMWithLXDContainers() async throws {
		try await buildVM(name: noble_lxd_image, image: "ubuntu:noble")
	}

	func testBuildMustFail() async throws {
		do {
			try await buildVM(name: noble_must_fail_image, image: "zlib://devregistry.aldunelabs.com/ubuntu:latest")
			XCTFail("Error needs to be thrown")
		} catch {
		}
	}

	func testLaunchVMWithCloudImage() async throws {
		try await buildVM(name: noble_cloud_image, image: ubuntuCloudImage)
		let location: VMLocation = try StorageLocation(runMode: .user).find(noble_cloud_image)
		let eventLoop = self.group.any()
		let promise = eventLoop.makePromise(of: String.self)

		promise.futureResult.whenComplete { result in
			switch result {
			case .success(let name):
				print("VM Stopped: \(name)")
				break
			case .failure(let err):
				XCTFail(err.localizedDescription)
			}
		}

		// Start VM
		let runningIP = StartHandler.startVM(location: location, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: 180, startMode: .background, runMode: .user, promise: promise)

		print("startVM got running ip: \(runningIP)")

		try location.stopVirtualMachine(force: false, runMode: .user)

		// Wait VM die
		XCTAssertNoThrow(try promise.futureResult.wait())
	}

	func testShouldDeleteVM() async throws {
		let names = [noble_cloud_image, noble_qcow2_image, noble_oci_image, noble_container_image, noble_lxd_image, noble_must_fail_image]
		let storageLocation: StorageLocation = StorageLocation(runMode: .user)

		for name in names {
			if storageLocation.exists(name) {
				let location: VMLocation = try storageLocation.find(name)
				XCTAssertNoThrow(try location.delete())
				XCTAssertFalse(storageLocation.exists(name), "VM \(name) should be deleted")
			}
		}
	}

	func testCurrentStatusUpdate() async throws {
		try await buildVM(name: noble_cloud_image, image: ubuntuCloudImage)
		let location: VMLocation = try StorageLocation(runMode: .user).find(noble_cloud_image)
		let eventLoop = self.group.any()
		let promise = eventLoop.makePromise(of: String.self)

		promise.futureResult.whenComplete { result in
			switch result {
			case .success(let name):
				print("VM starting: \(name)")
				break
			case .failure(let err):
				XCTFail(err.localizedDescription)
			}
		}

		let (stream, continuation) = AsyncThrowingStream.makeStream(of: CurrentStatusHandler.CurrentStatusReply.self)

		try await CurrentStatusHandler.currentStatus(location: location, frequency: 1, statusStream: continuation, runMode: .user)

		// Start VM
		let result = StartHandler.startVM(location: location, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: 180, startMode: .foreground, runMode: .user, promise: promise)

		XCTAssertTrue(result.started, "VM \(name) should be started")

		print("startVM got running ip: \(result)")

		var count = 0

		for try await status in stream {
			print("Current Status[\(count)]: \(status)")
			count += 1
			
			if count > 9 {
				break
			}
		}

		continuation.finish()

		try location.stopVirtualMachine(force: false, runMode: .user)

		// Wait VM die
		XCTAssertNoThrow(try promise.futureResult.wait())

		XCTAssertNoThrow(try location.delete())
	}
}
