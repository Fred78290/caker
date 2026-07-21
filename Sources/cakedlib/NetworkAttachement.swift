import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Virtualization
import vmnet

public var phUseLimaVMNet = false

public protocol NetworkAttachement {
	func attachment(location: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment)
	func stop(runMode: Utils.RunMode)
}

// MARK: - Network shared
public class NATNetworkInterface: NetworkAttachement {
	let macAddress: VZMACAddress

	public init(macAddress: VZMACAddress) {
		self.macAddress = macAddress
	}

	public func attachment(location: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZNATNetworkDeviceAttachment())
	}

	public func stop(runMode: Utils.RunMode) {
	}
}

// MARK: - Network bridged
public class BridgedNetworkInterface: NetworkAttachement {
	let interface: VZBridgedNetworkInterface
	let macAddress: VZMACAddress

	public init(interface: VZBridgedNetworkInterface, macAddress: VZMACAddress) {
		self.interface = interface
		self.macAddress = macAddress
	}

	public func attachment(location: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		return (macAddress, VZBridgedNetworkDeviceAttachment(interface: interface))
	}

	public func stop(runMode: Utils.RunMode) {
	}
}

public class SharedNetworkInterface: NetworkAttachement, VZVMNetHandlerClient.CloseDelegate {
	let macAddress: VZMACAddress
	let mode: VMNetMode
	let networkName: String
	let networkConfig: VZSharedNetwork?
	var process: ProcessWithSharedFileHandle? = nil
	var pipeChannel: Channel? = nil
	var vmfd: Int32 = -1
	var hostfd: Int32 = -1
	var pidURL: URL? = nil

	public init(mode: VMNetMode, networkName: String, macAddress: VZMACAddress) {
		self.mode = mode
		self.networkName = networkName
		self.macAddress = macAddress
		self.networkConfig = nil
	}

	public init(macAddress: VZMACAddress, networkName: String = "shared", networkConfig: VZSharedNetwork? = nil) {
		self.mode = .shared
		self.networkName = networkName
		self.macAddress = macAddress
		self.networkConfig = networkConfig
	}

	public init(mode: VMNetMode, macAddress: VZMACAddress, networkName: String, networkConfig: VZSharedNetwork) {
		self.mode = mode
		self.networkName = networkName
		self.macAddress = macAddress
		self.networkConfig = networkConfig
	}

	public func attachment(location: VMLocation, runMode: Utils.RunMode) throws -> (VZMACAddress, VZNetworkDeviceAttachment) {
		if #available(macOS 26.0, *), networkConfig != nil, NetworksHandler.vmnetNative {
			return (macAddress, VZVmnetNetworkDeviceAttachment(network: try self.createVMNetwork(runMode: runMode)))
		}
		return (macAddress, VZFileHandleNetworkDeviceAttachment(fileHandle: try self.open(location: location, runMode: runMode)))
	}

	private func startNetworkSandboxed(socketURL: (socket: URL, pidFile: URL), runMode: Utils.RunMode) throws {
		var arguments = ["networks", "start", networkName]

		if Logger.LoggingLevel() > .info {
			arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")
		}

		if runMode.isSystem {
			arguments.append("--system")
		}

		try? socketURL.socket.delete()

		try Bundle.runCakedWithUnixTask(with: arguments)

		try socketURL.pidFile.waitPID()
	}

	@available(macOS 26.0, *)
	private func createVMNetwork(runMode: Utils.RunMode) throws -> vmnet_network_ref {
		guard networkConfig != nil else {
			throw ServiceError(String(localized: "Unable to configure network"))
		}

		var socketURL = try self.vmnetEndpoint(runMode: runMode)

		if socketURL.pidFile.isPIDRunning().running == false {
			if Bundle.mustUseUnixTask {
				try startNetworkSandboxed(socketURL: socketURL, runMode: runMode)
			} else {
				socketURL = try NetworksHandler.startNetwork(networkName: networkName, runMode: runMode)
			}
		}

		let client = try NetworksHandler.getVMNetControlClient(socketURL.socket, runMode: runMode)

		defer {
			_ = try? client.channel.close().wait()
		}

		let reply = try client.getSerialization(Vmnet_Empty()).response.wait()

		guard reply.success else {
			throw ServiceError(String(localized: "VMNet serialization failed: \(reply.reason)"))
		}

		let serialization = try decodeXPCObject(reply.data)

		var status: vmnet_return_t = vmnet_return_t.VMNET_SUCCESS

		guard let network = vmnet_network_create_with_serialization(serialization, &status) else {
			throw ServiceError(String(localized: "Failed to create vmnet network with serialization, status: \(status.description)"))
		}

		return network
	}

	public func closed(side: VZVMNetHandlerClient.HandlerSide) {
		if self.pipeChannel != nil {
			self.pipeChannel = nil

			if side == .host {
				Logger(self).info("VMNet closed by the host")
			} else {
				Logger(self).info("VMNet closed by the guest")
			}
		}
	}

	internal func setSocketBuffers(fd: Int32, sizeBytes: Int) throws {
		let option_len = socklen_t(MemoryLayout<Int>.size)
		var sendBufferSize = sizeBytes
		var receiveBufferSize = 4 * sizeBytes
		var ret = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receiveBufferSize, option_len)

		if ret != 0 {
			perror("setsockopt(SO_RCVBUF) returned \(ret)")
			throw ServiceError(String(localized: "setsockopt(SO_RCVBUF) returned \(ret)"))
		}

		ret = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sendBufferSize, option_len)

		if ret != 0 {
			perror("setsockopt(SO_SNDBUF) returned \(ret)")
			throw ServiceError(String(localized: "setsockopt(SO_SNDBUF) returned \(ret), \(String(cString:strerror(errno)))"))
		}
	}

	internal func vmnetEndpoint(runMode: Utils.RunMode) throws -> (socket: URL, pidFile: URL) {
		let result: (socket: URL, pidFile: URL)

		if runMode.isSystem {
			result = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)
		} else {
			let systemSocketURL = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: .system)

			if try systemSocketURL.socket.exists() == false {
				result = try NetworksHandler.vmnetEndpoint(networkName: networkName, runMode: runMode)
			} else {
				result = systemSocketURL
			}
		}

		// Clear socket
		if try result.socket.exists() && result.pidFile.isPIDRunning().running == false {
			try? FileManager.default.removeItem(at: result.socket)
			try? FileManager.default.removeItem(at: result.pidFile)
		}

		return result
	}

	internal func open(location: VMLocation, runMode: Utils.RunMode) throws -> FileHandle {
		var socketURL = try self.vmnetEndpoint(runMode: runMode)

		if VMRunHandler.launchedFromService || runMode == .app {
			if try socketURL.socket.exists() == false || (try socketURL.socket.exists() && socketURL.pidFile.isPIDRunning().running == false) {
				if Bundle.mustUseUnixTask {
					try startNetworkSandboxed(socketURL: socketURL, runMode: runMode)
				} else {
					socketURL = try NetworksHandler.startNetwork(networkName: networkName, runMode: runMode)
				}
			}
		}

		let socketAddress = try SocketAddress(unixDomainSocketPath: socketURL.socket.path)

		(self.vmfd, self.hostfd) = try socketAddress.withSockAddr { _, len in
			let fds: UnsafeMutablePointer<Int32> = UnsafeMutablePointer<Int32>.allocate(capacity: MemoryLayout<Int>.stride * 2)

			defer {
				fds.deallocate()
			}

			if socketpair(AF_UNIX, SOCK_DGRAM, 0, fds) != 0 {
				throw ServiceError(String(localized: "unable to create socket with exit code \(String(errno: errno))"))
			}

			try setSocketBuffers(fd: fds[0], sizeBytes: Int(MoB))
			try setSocketBuffers(fd: fds[1], sizeBytes: Int(MoB))

			return (fds[0], fds[1])
		}

		if try socketURL.socket.exists() {
			Logger(self).info("Use VZVMNet at: \(socketURL.socket.path)")

			let client = ClientBootstrap(group: Utilities.group)
				.channelInitializer { inboundChannel in
					// When the child channel is created, create a new pipe and add the handlers
					return NIOPipeBootstrap(group: inboundChannel.eventLoop)
						.takingOwnershipOfDescriptor(inputOutput: self.hostfd)
						.flatMap { childChannel in
							let (guestHandler, hostHandler) = VZVMNetHandlerClient.matchedPair(useLimaVMNet: false, delegate: self)

							return childChannel.pipeline.addHandler(guestHandler)
								.flatMap {
									inboundChannel.pipeline.addHandler(hostHandler)
								}
						}
				}

			let futureChannel = client.connect(to: socketAddress)

			futureChannel.whenComplete { result in
				switch result {
				case .success:
					Logger(self).info("Network file handle connected to \(socketURL.socket.path)")
				case .failure(let error):
					Logger(self).error("Network file handle failed to connect to \(socketURL.socket.path), \(error)")
				}
			}

			self.pipeChannel = try futureChannel.wait()
		} else {
			Logger(self).info("Use standalone VZVMNet with fd: \(vmfd)")

			let pidURL = location.rootURL.appending(path: "\(self.networkName).pid")
			self.process = try NetworksHandler.run(fileDescriptor: hostfd, networkConfig: .init(name: networkName, config: networkConfig), pidFile: pidURL, runMode: runMode)
			self.pidURL = pidURL
		}

		return FileHandle(fileDescriptor: self.vmfd, closeOnDealloc: true)
	}

	public func stop(runMode: Utils.RunMode) {
		if let process {
			if process.isRunning {
				if geteuid() != 0 {
					_ = NetworksHandler.stop(pidURL: self.pidURL!, runMode: runMode)
				} else {
					// Otherwise, we can just kill the process directly
					kill(process.processIdentifier, SIGTERM)
				}

				Logger(self).info("Terminated VZVMNet process")

				self.process = nil
			}
		} else if let pipeChannel {
			// If we are running as a service, we need to close the channel
			let promise = pipeChannel.eventLoop.makePromise(of: Void.self)

			pipeChannel.close(promise: promise)

			do {
				try promise.futureResult.wait()
			} catch {
				Logger(self).error("Failed to close VZVMNet channel, \(error)")
			}

			self.pipeChannel = nil
		}

		if self.vmfd != -1 {
			close(self.vmfd)
			self.vmfd = -1
		}

		if self.hostfd != -1 {
			close(self.hostfd)
			self.hostfd = -1
		}
	}
}

public class HostNetworkInterface: SharedNetworkInterface {
	public init(macAddress: VZMACAddress) {
		super.init(mode: .host, networkName: "host", macAddress: macAddress)
	}
}

public class VMNetworkInterface: SharedNetworkInterface {
	let interface: VZBridgedNetworkInterface

	public init(interface: VZBridgedNetworkInterface, macAddress: VZMACAddress) {
		self.interface = interface
		super.init(mode: .bridged, networkName: interface.identifier, macAddress: macAddress)
	}
}

// MARK: - IMDS host network
//
// vmnet.framework's host-mode API only accepts subnets within 192.168.0.0/16 — it rejects
// link-local (169.254.0.0/16) ranges outright — so the actual DHCP subnet/gateway below live
// in that range, not at the AWS-style 169.254.169.x addresses. The guest still gets a static
// route for 169.254.169.254/32 via this gateway (see CloudInit.swift), matching AWS's own
// convention (169.254.169.254 isn't on-link there either — it's routed) for tooling that
// hardcodes that address, on a best-effort basis.
public class IMDSNetworkInterface: SharedNetworkInterface {
	public static let imdsGateway = "192.168.169.1"
	public static let imdsDhcpEnd = "192.168.169.253"
	public static let imdsSubnetCIDR = "192.168.169.0/24"
	public static let imdsNetmask = "255.255.255.0"
	public static let imdsNetworkName = "imds"

	public static var imdsEnabled: Bool {
		get {
			return CakedKeyConfig.imdsEnabled.bool(true)
		}
		set {
			CakedKeyConfig.imdsEnabled.set(newValue)
		}
	}
	
	/// The AWS-style link-local address guests get a static route to (see CloudInit.swift).
	/// Not on-link on the imds subnet itself — genuinely reaching it host-side needs a `pf`
	/// address-alias redirect to `imdsGateway` (see `PFRedirect.enableAddressAlias`).
	public static let awsCompatAddress = "169.254.169.254"

	public init(macAddress: VZMACAddress) {
		let networkConfig = VZSharedNetwork(
			mode: .host,
			netmask: IMDSNetworkInterface.imdsNetmask,
			dhcpStart: IMDSNetworkInterface.imdsGateway,
			dhcpEnd: IMDSNetworkInterface.imdsDhcpEnd,
			dhcpLease: nil,
			interfaceID: IMDSNetworkInterface.imdsNetworkName,
			nat66Prefix: nil
		)
		super.init(mode: .host, macAddress: macAddress, networkName: IMDSNetworkInterface.imdsNetworkName, networkConfig: networkConfig)
	}
}
