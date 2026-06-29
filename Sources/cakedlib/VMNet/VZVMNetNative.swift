//
//  VZVMNetNative.swift
//  Caker
//
//  Created by Frederic BOLTZ on 29/06/2026.
//

import CakeAgentLib
import Foundation
import GRPC
import GRPCLib
import NIO
import Semaphore
import vmnet

@available(macOS 26.0, *)
class GRPCVMNetService: Vmnet_VMNetServiceAsyncProvider, @unchecked Sendable {
	let owner: VZVMNetNative

	init(owner: VZVMNetNative) {
		self.owner = owner
	}

	func getSerialization(request: Vmnet_Empty, context: GRPCAsyncServerCallContext) async throws -> Vmnet_SerializationReply {
		owner.logger.debug("VMNet \(owner.networkName) replying to serialization request")

		guard let serialization = owner.serialization else {
			return Vmnet_SerializationReply.with {
				$0.success = false
				$0.reason  = "VMNet serialization not available"
			}
		}

		do {
			let data = try encodeXPCObject(serialization)
			return Vmnet_SerializationReply.with {
				$0.data    = data
				$0.success = true
			}
		} catch {
			return Vmnet_SerializationReply.with {
				$0.success = false
				$0.reason  = error.localizedDescription
			}
		}
	}
}

public class VZVMNetNative: NSObject, VZVMNet {
	var grpcServer: Server? = nil
	let eventLoop: EventLoop
	let networkName: String
	let pidFile: URL
	let socketPath: URL
	let runMode: Utils.RunMode
	let semaphore = AsyncSemaphore(value: 0)
	var networkConfig: VZSharedNetwork
	var network_ref: vmnet_network_ref?
	let logger = Logger("VZVMNetNative")
	var serialization: xpc_object_t?
	let sigcaught: [DispatchSourceSignal]

	public init(on: EventLoop, socketPath: URL, socketGroup: gid_t, networkName: String, networkConfig: VZSharedNetwork, pidFile: URL, runMode: Utils.RunMode) {
		self.eventLoop = on
		self.networkName = networkName
		self.networkConfig = networkConfig
		self.pidFile = pidFile
		self.socketPath = socketPath
		self.runMode = runMode
		self.sigcaught = [SIGINT, SIGHUP, SIGQUIT, SIGTERM].map {
			signal($0, SIG_IGN)
			return DispatchSource.makeSignalSource(signal: $0)
		}
	}

	private func setupSignals() {
		sigcaught.forEach { sig in
			sig.setEventHandler {
				self.logger.info("Signal caught, stopping VMNet")
				self.stop()
			}
			sig.activate()
		}
	}

	public func reconfigure(networkConfig: VZSharedNetwork) throws {
		self.logger.debug("Reconfiguring VMNet \(self.networkName) with new parameters")
		self.networkConfig = networkConfig

		if #available(macOS 26.0, *) {
			self.network_ref   = nil
			self.serialization = nil

			(self.network_ref, self.serialization) = try createVMNetwork()
		} else {
			throw ServiceError(String(localized: "VMNet reconfiguration is only available on macOS 26.0 and later"))
		}
	}

	public func stop() {
		guard let server = grpcServer else {
			self.logger.info(String(localized: "VMNet \(self.networkName) is not running"))
			return
		}

		self.logger.info(String(localized: "VMNet \(self.networkName) stop network"))

		self.grpcServer    = nil
		self.network_ref   = nil
		self.serialization = nil

		self.semaphore.signal()
		try? server.close().wait()
	}

	public func start() throws {
		if #available(macOS 26.0, *) {
			guard self.grpcServer == nil else {
				throw ServiceError(String(localized: "VMNet \(self.networkName) is already running"))
			}

			setupSignals()

			(self.network_ref, self.serialization) = try createVMNetwork()

			let serviceProvider = GRPCVMNetService(owner: self)
			let socketFile = socketPath.path

			try? FileManager.default.removeItem(atPath: socketFile)

			let certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)
			var serverConfiguration = Server.Configuration.default(
				target: .unixDomainSocket(socketFile),
				eventLoopGroup: eventLoop,
				serviceProviders: [serviceProvider])
			serverConfiguration.tlsConfiguration = try GRPCTLSConfiguration.makeServerConfiguration(
				caCert: certLocation.caCertURL.path,
				tlsKey: certLocation.serverKeyURL.path,
				tlsCert: certLocation.serverCertURL.path)

			let server = try Server.start(configuration: serverConfiguration).wait()
			self.grpcServer = server

			let future = self.eventLoop.makeFutureWithTask {
				self.logger.info("VMNet \(self.networkName) started on \(socketFile)")
				try self.pidFile.writePID()

				do {
					try await self.semaphore.waitUnlessCancelled()
				} catch {
					Logger(self).error("Error: \(error)")
				}

				self.logger.info("VMNet \(self.networkName) stopped")
			}

			try future.wait()
		} else {
			throw ServiceError(String(localized: "VMNet network is only available on macOS 26.0 and later"))
		}
	}

	@available(macOS 26.0, *)
	private func createVMNetwork() throws -> (network_ref: vmnet_network_ref, serialization: xpc_object_t) {
		let dhcpStart = "\(networkConfig.dhcpStart)/\(networkConfig.netmask.netmaskToCidr())".toIPV4()

		guard let network = dhcpStart.address, let netmask = dhcpStart.netmask else {
			throw ServiceError(String(localized: "Bad network configuration \(networkConfig.dhcpStart)"))
		}

		var addr   = in_addr(s_addr: in_addr_t(network.storage))
		var mask   = in_addr(s_addr: in_addr_t(netmask.storage))
		var status: vmnet_return_t = .VMNET_SUCCESS

		guard let network_configuration = vmnet_network_configuration_create(networkConfig.mode == .shared ? .VMNET_SHARED_MODE : .VMNET_HOST_MODE, &status) else {
			throw ServiceError(String(localized: "Can't create vmnet configuration: \(status.description)"))
		}

		let result = vmnet_network_configuration_set_ipv4_subnet(network_configuration, &addr, &mask)

		guard result == .VMNET_SUCCESS else {
			throw ServiceError(String(localized: "Failed to reconfigure network: \(result.description)"))
		}

		if let nat66Prefix = networkConfig.nat66Prefix {
			let parts = nat66Prefix.split(separator: "/")

			guard let prefixStr = parts.first else {
				throw ServiceError(String(localized: "Invalid NAT66 prefix \(nat66Prefix)"))
			}

			let prefixLen = parts.count > 1 ? UInt8(parts[1]) ?? 64 : 64

			guard let parsed = String(prefixStr).to_in6_addr() else {
				throw ServiceError(String(localized: "Bad NAT66 prefix \(nat66Prefix)"))
			}

			var ipv6Prefix = parsed

			let result = withUnsafePointer(to: &ipv6Prefix) { ptr in
				vmnet_network_configuration_set_ipv6_prefix(network_configuration, UnsafeMutablePointer(mutating: ptr), prefixLen)
			}

			guard result == .VMNET_SUCCESS else {
				throw ServiceError(String(localized: "Failed to set NAT66 prefix (\(result.description))"))
			}
		}

		if networkConfig.mode == .host {
			vmnet_network_configuration_disable_nat44(network_configuration)
			vmnet_network_configuration_disable_nat66(network_configuration)
		}

		guard let network = vmnet_network_create(network_configuration, &status) else {
			throw ServiceError(String(localized: "Can't create vmnet network: \(status.description)"))
		}

		guard let serialized = vmnet_network_copy_serialization(network, &status) else {
			throw ServiceError(String(localized: "Can't serialize vmnet network: \(status.description)"))
		}

		return (network, serialized)
	}
}
