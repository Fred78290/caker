//
//  NetworkWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/11/2025.
//

import ArgumentParser
import CakedLib
import GRPCLib
import SwiftUI

struct NetworkWizard: View {
	@Environment(\.dismiss) private var dismiss
	@State private var vzNetwork: VZSharedNetwork?
	@State private var currentItem: BridgedNetwork
	@State private var reason: String?

	init() {
		let network = BridgedNetwork(name: "private", mode: .host, description: "Hosted network", gateway: "192.168.111.1/24", dhcpEnd: "192.168.111.254/24", dhcpLease: Self.getDhcpLease(), interfaceID: UUID().uuidString, endpoint: "", usedBy: 0)
		let valid = Self.validate(network)

		self.vzNetwork = valid.0
		self.reason = valid.1
		self.currentItem = network
	}

	var body: some View {
		VStack {
			NetworkDetailView(
				$currentItem,
				reloadNetwork: Binding<Bool>(
					get: {
						false
					},
					set: { newValue in
						if newValue {
							DispatchQueue.main.async {
								AppState.shared.reloadNetworks()
							}
						}
					}
				), forEditing: true)
			Spacer()
			if let reason = self.reason {
				Text(reason).font(.callout)
			}
			Divider()
			HStack {
				Spacer()
				Button("Create") {
					createNetwork()
				}.disabled(vzNetwork == nil)
				Button("Cancel") {
					dismiss()
				}.buttonStyle(.borderedProminent)
				Spacer()
			}
		}
		.padding()
		.onChange(of: currentItem) { _, newValue in
			(self.vzNetwork, self.reason) = Self.validate(newValue)
		}
	}

	static func validate(_ network: BridgedNetwork) -> (VZSharedNetwork?, String?) {
		do {
			guard AppState.shared.networks.first(where: { $0.name == network.name }) == nil else {
				throw ValidationError("Network \(network.name) already exist")
			}

			let inet = network.gateway.toNetwork()
			let gateway = network.gateway.toIPV4()
			let dhcpEnd = network.dhcpEnd.toIPV4()

			guard let inet = inet else {
				throw ValidationError("Invalid address \(network.gateway)")
			}

			guard let dhcpStart = gateway.address, let netmask = gateway.netmask else {
				throw ValidationError("Invalid address \(network.gateway)")
			}

			guard let dhcpEnd = dhcpEnd.address else {
				throw ValidationError("Invalid address \(network.dhcpEnd)")
			}

			guard AppState.shared.networks.first(where: { $0.gateway == network.gateway }) == nil else {
				throw ValidationError("Gateway \(dhcpStart) is already in use")
			}

			guard inet.contains(dhcpEnd) else {
				throw ValidationError("dhcp end \(dhcpEnd) is not in the range of the network \(network.description)")
			}

			let network = VZSharedNetwork(
				mode: network.mode == .shared ? .shared : .host,
				netmask: netmask.description,
				dhcpStart: dhcpStart.description,
				dhcpEnd: dhcpEnd.description,
				dhcpLease: Int32(network.dhcpLease),
				interfaceID: network.interfaceID,
				nat66Prefix: nil
			)

			return (network, nil)
		} catch {
			print(error)
			if let error = error as? ValidationError {
				return (nil, error.description)
			}

			if let error = error as? ServiceError {
				return (nil, error.description)
			}

			return (nil, error.localizedDescription)
		}
	}

	func createNetwork() {
		do {
			try AppState.shared.createNetwork(network: self.currentItem)
		} catch {
			alertError(error)
		}
		dismiss()
	}

	static func getDhcpLease() -> String {
		guard let dhcpLease = try? NetworksHandler.getDHCPLease() else {
			return ""
		}

		return "\(dhcpLease)"
	}
}

#Preview {
	NetworkWizard()
}
