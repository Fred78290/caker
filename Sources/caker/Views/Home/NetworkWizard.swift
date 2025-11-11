//
//  NetworkWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/11/2025.
//

import SwiftUI
import GRPCLib
import CakedLib
import ArgumentParser

struct NetworkWizard: View {
	@Environment(\.dismiss) private var dismiss
	@Binding var appState: AppState
	@State private var vzNetwork: VZSharedNetwork?
	@State private var currentItem: BridgedNetwork
	@State private var reason: String?
	private var networkConfig: VZVMNetConfig

	init(appState: Binding<AppState>) {
		let network = BridgedNetwork(name: "private", mode: .host, description: "Hosted network", gateway: "192.168.111.1/24", dhcpEnd: "192.168.111.254/24", dhcpLease: Self.getDhcpLease(), interfaceID: UUID().uuidString, endpoint: "")
		let networkConfig = try! Home(runMode: .app).sharedNetworks()
		let valid = Self.validate(network, networkConfig: networkConfig)

		self.vzNetwork = valid.0
		self.reason = valid.1
		self._appState = appState
		self.currentItem = network
		self.networkConfig = networkConfig
	}

	var body: some View {
		VStack {
			NetworkDetailView($currentItem, forEditing: true)
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
			(self.vzNetwork, self.reason) = Self.validate(newValue, networkConfig: self.networkConfig)
		}
    }
	
	static func validate(_ network: BridgedNetwork, networkConfig: VZVMNetConfig) -> (VZSharedNetwork?, String?) {
		do {
			if CakedLib.NetworksHandler.isPhysicalInterface(name: network.name) {
				throw ValidationError("Network \(network.name) is a physical interface")
			}
			
			if networkConfig.sharedNetworks[network.name] != nil {
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

			let networks = VZSharedNetwork.networkInterfaces(networkConfig: networkConfig).map {
				$0.value.network
			}

			guard networks.first(where: { $0.contains(dhcpStart) }) == nil else {
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
			let home: Home = try Home(runMode: .app)
			let name = self.currentItem.name
			var networkConfig = self.networkConfig

			networkConfig.userNetworks[name] = self.vzNetwork!
			try home.setSharedNetworks(networkConfig)
			try appState.reloadNetworks()
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
	NetworkWizard(appState: .constant(AppState.shared))
}
