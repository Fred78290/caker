//
//  VZVMNetNative.swift
//  Caker
//
//  Created by Frederic BOLTZ on 29/06/2026.
//

import CakeAgentLib
import Foundation
import NIO
import Semaphore
import vmnet

@objc public protocol VZVMNetSerialization: AnyObject {
	func vmnet_serialization(with reply: @escaping (xpc_object_t?) -> Void)
}

public class VZVMNetNative: NSObject, VZVMNet {
	var serverChannel: Channel? = nil
	let eventLoop: EventLoop
	let networkName: String
	let pidFile: URL
	let semaphore = AsyncSemaphore(value: 0)
	var networkConfig: VZSharedNetwork
	var network_ref: vmnet_network_ref?
	let logger = Logger("VZVMNetNative")
	var listener: NSXPCListener?
	var serialization: xpc_object_t?
	let sigcaught: [DispatchSourceSignal]
	
	public init(on: EventLoop, socketPath: URL, socketGroup: gid_t, networkName: String, networkConfig: VZSharedNetwork, pidFile: URL) {
		self.eventLoop = on
		self.networkName = networkName
		self.networkConfig = networkConfig
		self.pidFile = pidFile
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
			self.network_ref = nil
			self.serialization = nil

			(self.network_ref, self.serialization) = try createVMNetwork()
		} else {
			throw ServiceError(String(localized: "VMNet reconfiguration is only available on macOS 26.0 and later"))
		}
	}

	public func stop() {
		guard let listener else {
			self.logger.info(String(localized: "VMNet \(self.networkName) is not running"))
			return
		}

		self.logger.info(String(localized: "VMNet \(self.networkName) stop network"))

		self.listener = nil
		self.network_ref = nil
		self.serialization = nil

		self.semaphore.signal()
		listener.invalidate()
	}

	public func start() throws {
		if #available(macOS 26.0, *) {
			guard self.listener == nil else {
				throw ServiceError(String(localized: "VMNet \(self.networkName) is already running"))
			}

			setupSignals()

			let listener = NSXPCListener(machServiceName: "com.aldunelabs.caked.vmnet.\(networkName)")
			listener.delegate = self

			(self.network_ref, self.serialization) = try createVMNetwork()
			self.listener = listener

			let future = self.eventLoop.makeFutureWithTask {
				self.logger.info("VMNet \(self.networkName) started")
				listener.activate()
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

		var addr = in_addr(s_addr: in_addr_t(network.storage))
		var mask = in_addr(s_addr: in_addr_t(netmask.storage))
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

extension VZVMNetNative: VZVMNetSerialization {
	public func vmnet_serialization(with reply: @escaping (xpc_object_t?) -> Void) {
		self.logger.debug("VMNet \(self.networkName) replying to serialization request \(String(describing: self.serialization))")

		reply(self.serialization)
	}
}

extension VZVMNetNative: NSXPCListenerDelegate {
	public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		self.logger.debug("VMNet \(self.networkName) handling connection")

		// Configure the connection.
		// First, set the interface that the exported object implements.
		newConnection.exportedInterface = NSXPCInterface(with: VZVMNetSerialization.self)

		// Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
		let exportedObject = self
		newConnection.exportedObject = exportedObject

		// Resuming the connection allows the system to deliver more incoming messages.
		newConnection.resume()

		// Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
		return true
	}
}
