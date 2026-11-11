//
//  NetworkStarter.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/11/2026.
//

import CakeAgentLib
import CakedLib
import Foundation
import GRPCLib
import Virtualization

extension Networks.VMNetOptions {
	public init(networkName: String, runMode: Utils.RunMode) throws {
		self.networkName = networkName
		self.debug = false
		self.networkName = networkName
		self.socketGroup = "staff"
		self.socketPath = nil
		self.vmfd = nil
		self.pidFile = nil

		if CakedLib.NetworksHandler.isPhysicalInterface(name: networkName) {
			if CakedLib.NetworksHandler.hasVMNetEntitlement {
				throw ServiceError(String(localized: "Network \(networkName) is handled natively, please use a different network"))
			}

			self.mode = .bridged
			self.macAddress = VZMACAddress.randomLocallyAdministered().string
			self.gateway = nil
			self.dhcpEnd = nil
			self.dhcpLease = nil
			self.subnetMask = "255.255.255.0"
			self.interfaceID = UUID().uuidString
			self.nat66Prefix = nil
			self.dns = false
			#if !USE_IMDS_COORDINATOR_IN_SERVICE
				self.imds = false
				self.imdsPort = IMDSServer.internalBindPort
			#endif
		} else {
			let home: Home = try Home(runMode: runMode)
			let networkConfig = try home.sharedNetworks()

			guard let network = networkConfig.sharedNetworks[networkName] else {
				throw ServiceError(String(localized: "Network \(networkName) doesn't exists"))
			}

			self.mode = network.mode
			self.gateway = network.dhcpStart
			self.dhcpEnd = network.dhcpEnd
			self.dhcpLease = network.dhcpLease
			self.subnetMask = network.netmask
			self.interfaceID = network.interfaceID
			self.nat66Prefix = network.nat66Prefix
			self.dns = network.dns ?? false
			#if !USE_IMDS_COORDINATOR_IN_SERVICE
				self.imds = networkName == IMDSNetworkInterface.imdsNetworkName ? IMDSNetworkInterface.imdsEnabled : false
				self.imdsPort = IMDSServer.internalBindPort
			#endif
		}
	}

	func vmnetEndpoint(runMode: Utils.RunMode) throws -> (socket: URL, pidFile: URL) {
		if let socketPath = self.socketPath, let pidFile = self.pidFile {
			return (URL(fileURLWithPath: socketPath), URL(fileURLWithPath: pidFile))
		} else {
			return try CakedLib.NetworksHandler.vmnetEndpoint(networkName: self.networkName, runMode: runMode)
		}
	}

	func createVZVMNet(runMode: Utils.RunMode) throws -> (socketURL: URL, vmnet: VZVMNet) {
		let network: VZSharedNetwork

		if CakedLib.NetworksHandler.isPhysicalInterface(name: self.networkName) {
			network = VZSharedNetwork(mode: self.mode, netmask: String.empty, dhcpStart: String.empty, dhcpEnd: String.empty, dhcpLease: nil, interfaceID: self.interfaceID, nat66Prefix: nil, dns: false)
		} else {
			network = VZSharedNetwork(mode: self.mode, netmask: self.subnetMask, dhcpStart: self.gateway!, dhcpEnd: self.dhcpEnd!, dhcpLease: self.dhcpLease, interfaceID: self.interfaceID, nat66Prefix: self.nat66Prefix, dns: self.dns)
		}

		guard let grp = getgrnam(self.socketGroup) else {
			throw ServiceError(String(localized: "Failed to get group \(self.socketGroup)"))
		}

		guard let vmfd = self.vmfd else {
			let socketURL = try vmnetEndpoint(runMode: runMode)
			let socketControl = socketURL.pidFile.deletingLastPathComponent().appendingPathComponent(VZVMNetCommon.networkSocketControl)

			if CakedLib.NetworksHandler.vmnetNative {
				let vzvmnet = VZVMNetNative(
					on: Utilities.group.next(),
					socketGroup: grp.pointee.gr_gid,
					networkName: self.networkName,
					networkConfig: network,
					socketPath: socketURL.socket,
					socketControl: socketControl,
					pidFile: socketURL.pidFile,
					runMode: runMode
				)

				return (socketURL.pidFile, vzvmnet)
			} else if try socketURL.socket.exists() == false {
				let vzvmnet = VZVMNetSocket(
					on: Utilities.group.next(),
					socketGroup: grp.pointee.gr_gid,
					networkName: self.networkName,
					networkConfig: network,
					socketPath: socketURL.socket,
					socketControl: socketControl,
					pidFile: socketURL.pidFile,
					runMode: runMode
				)

				return (socketURL.pidFile, vzvmnet)
			} else {
				throw ServiceError(String(localized: "Socket file already exists at \(socketURL.socket.path(percentEncoded: false))"))
			}
		}

		guard let pidFile = self.pidFile else {
			throw ServiceError(String(localized: "pidfile is required when using vmfd"))
		}

		let pidUrl = URL(fileURLWithPath: pidFile)

		pidUrl.removeWithoutFollowingSymlinks()

		let vzvmnet = VZVMNetFileHandle(
			on: Utilities.group.next(),
			socketGroup: grp.pointee.gr_gid,
			inputOutput: CInt(vmfd),
			networkName: self.networkName,
			networkConfig: network,
			socketPath: pidUrl.deletingPathExtension().appendingPathExtension("sock"),
			socketControl: pidUrl.deletingPathExtension().appendingPathExtension(VZVMNetCommon.networkSocketControl),
			pidFile: pidUrl,
			runMode: runMode)

		return (pidUrl, vzvmnet)
	}
}

struct NetworkStarter {
	#if USE_DHCP_SERVER
		/// The DHCP server of `network`: pool from the first address after the gateway up to `dhcp-end`, leases kept in
		/// the network's own table.
		static func makeDHCPServer(networkName: String, network: VZSharedNetwork, runMode: Utils.RunMode) throws -> DHCPServer {
			guard let gateway = DHCPAddress.parse(network.gateway), let netmask = DHCPAddress.parse(network.netmask), let end = DHCPAddress.parse(network.dhcpEnd) else {
				throw ServiceError(String(localized: "Bad network configuration \(networkName)"))
			}

			let start = max(DHCPAddress.parse(network.dhcpStart) ?? 0, gateway + 1)
			let store = DHCPLeaseStore(
				gateway: gateway, poolStart: start, poolEnd: end, leaseDuration: TimeInterval(network.dhcpLease ?? 86400),
				fileURL: try CakedLib.NetworksHandler.dhcpLeaseFile(networkName: networkName, runMode: runMode))
			// The gateway is the DNS server: the compose resolver when `dns` is on, vmnet's proxy otherwise.
			let responder = DHCPResponder(configuration: .init(gateway: gateway, netmask: netmask, dnsServers: [gateway], domainName: network.dns == true ? ComposeDNS.domainSuffix : nil), store: store)

			return DHCPServer(group: Utilities.group, responder: responder, bindAddress: network.gateway)
		}
	#endif

	static func startNetwork(options: Networks.VMNetOptions, runMode: Utils.RunMode, socket: URL, pidFile: URL) throws {
		let isPhysicalInterface = CakedLib.NetworksHandler.isPhysicalInterface(name: options.networkName)
		let logger = Logger(self)

		pidFile.removeWithoutFollowingSymlinks()
		try socket.deleteIfFileExists()

		let vzvmnet = try options.createVZVMNet(runMode: runMode)
		var signalReconfigure: DispatchSourceSignal? = nil
		var coordinator: ComposeDNSCoordinator? = nil

		#if !USE_IMDS_COORDINATOR_IN_SERVICE
			var imdsCoordinator: IMDSCoordinator? = nil
			var imdsLifecycleHandler: VMLifecycleHooks.HandlerID? = nil
		#endif

		#if USE_DHCP_SERVER
			var dhcpServer: DHCPServer? = nil
			var dhcpStartTask: Task<Void, Never>? = nil
		#endif

		// Starts or stops the network's own services so they follow its configuration: caked's DHCP server
		// (replaces vmnet's, see `NetworksHandler.usesCakerDHCP`) and the compose DNS resolver (`dns`).
		let syncServices: (VZSharedNetwork) -> Void = { network in
			let ownsDHCP = CakedLib.NetworksHandler.usesCakerDHCP(network)

			#if USE_DHCP_SERVER
				if ownsDHCP, dhcpServer == nil {
					do {
						dhcpServer = try Self.makeDHCPServer(networkName: options.networkName, network: network, runMode: runMode)

						if let server = dhcpServer {
							// Kept so `stopServices` can cancel it: the retry loop waits for a bridge that only exists once a guest
							// attaches, and must not start a server after the services were stopped or replaced.
							dhcpStartTask = Task {
								logger.info("Starting the DHCP server of network \(options.networkName)")

								do {
									try await server.startWithRetry()
								} catch is CancellationError {
									logger.debug("DHCP server of network \(options.networkName) was cancelled")
								} catch {
									logger.error("DHCP server of network \(options.networkName) failed: \(error)")
								}
							}
						} else {
							logger.error("Failed to start the DHCP server of network \(options.networkName)")
						}
					} catch {
						logger.error("Unable to start the DHCP server of network \(options.networkName): \(error)")
					}
				}
			#endif

			if network.dns == true {
				guard coordinator == nil else {
					return
				}

				// As the network's DHCP server hands the gateway out as DNS server, the resolver must answer on port 53
				// and pass what isn't its own on to the host's resolvers.
				let forwarder = ownsDHCP ? DNSForwarder(group: Utilities.group, upstreams: { DNSForwarder.systemResolvers(excluding: [network.gateway]) }) : nil
				let started = ComposeDNSCoordinator(
					group: Utilities.group,
					runMode: runMode,
					bindAddress: network.gateway,
					internalPort: ComposeDNS.internalBindPort,
					standardPort: ownsDHCP ? 53 : nil,
					forwarder: forwarder,
					networkName: ownsDHCP ? options.networkName : nil,
					subnet: ownsDHCP ? network.subnet : nil)

				coordinator = started

				Task {
					await started.startPollingSync()
				}
			} else if let stopped = coordinator {
				coordinator = nil

				Task {
					await stopped.shutdown()
				}
			}
		}

		// Stops everything `syncServices` started.
		let stopServices: () async -> Void = {
			#if !USE_IMDS_COORDINATOR_IN_SERVICE
				if let handler = imdsLifecycleHandler, let coordinator = imdsCoordinator {
					imdsLifecycleHandler = nil
					imdsCoordinator = nil

					VMLifecycleHooks.removeHandler(handler)
					await coordinator.shutdown()
				}
			#endif

			if let coordinator {
				await coordinator.shutdown()
			}

			#if USE_DHCP_SERVER
				dhcpStartTask?.cancel()
				dhcpStartTask = nil

				if let dhcpServer {
					await dhcpServer.shutdown()
				}

				dhcpServer = nil
			#endif

			coordinator = nil
		}

		defer {
			pidFile.removeWithoutFollowingSymlinks()
			try? socket.deleteIfFileExists()
		}

		let signals = [SIGINT, SIGTERM, SIGQUIT].map { sig in
			signal(sig, SIG_IGN)

			let sig = DispatchSource.makeSignalSource(signal: sig)

			sig.setEventHandler {
				logger.info("Will stop network: \(options.networkName)")

				vzvmnet.vmnet.stop()

				sig.setEventHandler {
					Foundation.exit(128)
				}

				sig.activate()
			}

			return sig
		}.map { sig in
			sig.activate()

			return sig
		}

		if isPhysicalInterface == false {
			let sigReconfigure = DispatchSource.makeSignalSource(signal: SIGUSR2)

			// With caked's own DHCP server the lease time is the network's `dhcpLease`, not a host-wide bootpd setting.
			if let dhcpLease = options.dhcpLease, Bundle.isApplicationSandboxed == false, CakedLib.NetworksHandler.usesCakerDHCP(mode: options.mode) == false {
				_ = try CakedLib.NetworksHandler.setDHCPLease(leaseTime: dhcpLease, runMode: runMode)
			}

			logger.info("Allow reconfigure network: \(options.networkName)")

			signal(SIGUSR2, SIG_IGN)

			@Sendable func reconfigureNetwork() async throws {
				logger.info("Will reconfigure network: \(options.networkName)")

				// The services must be stopped first: the network's `dns`/range may have changed.
				await stopServices()

				try syncServices(vzvmnet.vmnet.restart())
			}

			// The `restart` RPC (`networks configure` on a running network) runs the same sequence as SIGUSR2.
			vzvmnet.vmnet.reconfigureHandler = reconfigureNetwork

			sigReconfigure.setEventHandler {
				Task {
					do {
						try await reconfigureNetwork()
					} catch {
						Logger(self).error("Failed to reconfigure network: \(error)")
					}
				}
			}

			sigReconfigure.activate()
			signalReconfigure = sigReconfigure
		}

		defer {
			if let sig = signalReconfigure {
				sig.cancel()
			}

			Task.sync {
				await stopServices()
			}

			signals.forEach { sig in
				sig.cancel()
			}
		}

		#if !USE_IMDS_COORDINATOR_IN_SERVICE
			if options.imds {
				// Central IMDS server for Linux VMs (see IMDSCoordinator's doc comment): the
				// daemon learns about VM start/stop through VMLifecycleHooks, fired by
				// CakedLib.StartHandler whenever it spawns or reaps a `caked vmrun` child,
				// whether that's from autostart below or from a `Caked_StartRequest` RPC.
				// Off by default (IMDSNetworkInterface.imdsEnabled, toggled from Caker's
				// Advanced settings) — once on, this works including in sandboxed builds,
				// guests can always reach it on its unprivileged port.
				let coordinator = IMDSCoordinator(group: Utilities.group.next(), runMode: runMode, internalPort: options.imdsPort)

				imdsCoordinator = coordinator

				imdsLifecycleHandler = VMLifecycleHooks.addHandler { event in
					Task {
						await coordinator.handle(event)
					}
				}

				Task {
					await coordinator.registerAlreadyRunning()
				}
			}
		#endif

		do {
			try vzvmnet.vmnet.start { network in
				syncServices(network)
			}
		} catch {
			Logger(self).error("Failed to start network: \(error)")

			pidFile.removeWithoutFollowingSymlinks()
			try? socket.deleteIfFileExists()
			// Exit because vmnet scrash
			Foundation.exit(1)
		}
	}

	static func start(options: Networks.VMNetOptions, fork: Bool, runMode: Utils.RunMode) -> StartedNetworkReply {
		let isPhysicalInterface = CakedLib.NetworksHandler.isPhysicalInterface(name: options.networkName)
		let networkName = options.networkName

		if isPhysicalInterface && CakedLib.NetworksHandler.hasVMNetEntitlement {
			return StartedNetworkReply(name: options.networkName, started: false, reason: String(localized: "Network \(networkName) is handled natively, please use a different network"))
		}

		do {
			let socketURL = try options.vmnetEndpoint(runMode: runMode)
			let home = try Home(runMode: runMode)
			let networkConfig = try home.sharedNetworks()
			let sharedNetworks = networkConfig.sharedNetworks

			if socketURL.pidFile.isCakedRunning() {
				return StartedNetworkReply(name: options.networkName, started: false, reason: String(localized: "Network already running"))
			}

			if fork {
				try startNetwork(options: options, runMode: runMode, socket: socketURL.socket, pidFile: socketURL.pidFile)

				return StartedNetworkReply(name: networkName, started: true, reason: String(localized: "Network \(networkName) ended"))
			}

			if isPhysicalInterface == false && sharedNetworks[networkName] == nil {
				return StartedNetworkReply(name: options.networkName, started: false, reason: String(localized: "Network \(networkName) doesn't exists"))
			}

			let log = try CakedLib.NetworksHandler.vmnetFileLog(networkName: networkName, runMode: runMode)

			func startForkedNetwork() throws {
				let cakedExecutableURL = try Bundle.main.caked()

				var arguments: [String] = ["networks", "start", "--fork", options.networkName]
				let process = try Bundle.createProcess()

				if runMode.isSystem {
					arguments.append("--system")
				}

				arguments.append("--log-level=\(Logger.LoggingLevel().rawValue)")

				process.executableURL = cakedExecutableURL
				process.standardInput = nil
				process.standardOutput = log
				process.standardError = log
				process.arguments = arguments
				process.terminationHandler = { process in
					Logger(self).debug("Process died: \(process.terminationStatus), \(process.terminationReason)")
				}

				try process.run()

				sleep(1)

				try socketURL.pidFile.waitPID {
					if process.isRunning {
						Logger(self).info("Network \(networkName) started")
					} else {
						if process.terminationReason == .uncaughtSignal {
							throw ServiceError(String(localized: "Network \(networkName) failed to start: \(process.terminationStatus), \(process.terminationReason.rawValue)"))
						} else {
							throw ServiceError(String(localized: "Network \(networkName) stopped: \(process.terminationStatus)"))
						}
					}
				}
			}

			func startWithHelper() throws -> Bool {
				// Disable macos26 vmnet features for testing on macOS 26+ when the environment variable is set to "0"
				guard ProcessInfo.processInfo.environment["CAKED_VMNET_NATIVE"] != "0" else {
					return false
				}

				#if USE_AUTHORIZATION_HELPER
					return try DirectAuthorizationHelperConnector.viaHelperSync(runMode: runMode, { try await $0.startNetwork(networkName: networkName, runMode: runMode) }) != nil
				#else
					return false
				#endif
			}

			if CakedLib.NetworksHandler.canManageNetworkWithoutRoot(mode: isPhysicalInterface ? .bridged : (sharedNetworks[networkName])?.mode) {
				try startForkedNetwork()
			} else if try startWithHelper() {
				// Started as root by the privileged helper, which waited for the pid file.
				Logger(self).info("Network \(networkName) started by the privileged helper")
			} else {
				if try SudoCaked(arguments: ["networks", "start", "--fork", networkName], runMode: runMode, log: log).run().terminationStatus != 0 {
					throw ServiceError(String(localized: "Failed to start networks \(options.networkName)"))
				}

				sleep(1)
				try socketURL.pidFile.waitPID()
			}

			return StartedNetworkReply(name: networkName, started: true, reason: String(localized: "Network \(networkName) started"))
		} catch {
			return StartedNetworkReply(name: networkName, started: false, reason: error.reason)
		}
	}

	public static func startAll(runMode: Utils.RunMode) -> [StartedNetworkReply] {
		let networks = CakedLib.NetworksHandler.networks(all: true, runMode: runMode)

		func start(_ name: String) -> StartedNetworkReply {
			do {
				return self.start(options: try Networks.VMNetOptions(networkName: name, runMode: runMode), fork: false, runMode: runMode)
			} catch {
				return StartedNetworkReply(name: name, started: false, reason: error.reason)
			}
		}

		if networks.success {
			return networks.networks.filter { $0.running == false && $0.managed }.map { network in
				start(network.name)
			}
		} else {
			return [StartedNetworkReply(name: "<all>", started: false, reason: networks.reason)]
		}
	}

}
