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

public class VZVMNetNative: VZVMNetCommon, @unchecked Sendable {
	var network_ref: vmnet_network_ref?

	public override init(on: EventLoop, socketGroup: gid_t, networkName: String, networkConfig: VZSharedNetwork, socketPath: URL, pidFile: URL, runMode: Utils.RunMode) {
		super.init(on: on, socketGroup: socketGroup, networkName: networkName, networkConfig: networkConfig, socketPath: socketPath, pidFile: pidFile, runMode: runMode)
	}

	public override func reconfigure(networkConfig: VZSharedNetwork) throws {
		self.logger.debug("Reconfiguring VMNet \(self.networkName) with new parameters")
		self.networkConfig = networkConfig

		if #available(macOS 26.0, *) {
			let (ref, serial) = try createVMNetwork()
			serializationLock.withLock {
				self.network_ref = ref
				self.serialization = serial
			}
		} else {
			throw ServiceError(String(localized: "VMNet reconfiguration is only available on macOS 26.0 and later"))
		}
	}

	public override func stop() {
		super.stop()
		self.network_ref = nil
	}

	public override func start() throws {
		if #available(macOS 26.0, *) {
			let (ref, serial) = try createVMNetwork()

			serializationLock.withLock {
				self.network_ref = ref
				self.serialization = serial
			}

			try super.start()
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

		status = vmnet_network_configuration_set_ipv4_subnet(network_configuration, &addr, &mask)

		guard status == .VMNET_SUCCESS else {
			throw ServiceError(String(localized: "Failed to reconfigure network: \(status.description)"))
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
