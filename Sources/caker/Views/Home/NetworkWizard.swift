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

	init(appState: Binding<AppState>) {
		let network = BridgedNetwork(name: "private", mode: .host, description: "Hosted network", gateway: "192.168.111.1/24", dhcpEnd: "192.168.111.254/24", dhcpLease: Self.getDhcpLease(), interfaceID: UUID().uuidString, endpoint: "")
		let valid = Self.validate(network)

		self.vzNetwork = valid.0
		self.reason = valid.1
		self._appState = appState
		self.currentItem = network
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
			(self.vzNetwork, self.reason) = Self.validate(newValue)
		}
    }
	
	static func validate(_ network: BridgedNetwork) -> (VZSharedNetwork?, String?) {
		do {
			let gateway = network.gateway.toIPV4()
			let dhcpEnd = network.dhcpEnd.toIPV4()

			guard let dhcpStart = gateway.address, let netmask = gateway.netmask else {
				throw ValidationError("Invalid address \(network.gateway)")
			}

			guard let dhcpEnd = dhcpEnd.address else {
				throw ValidationError("Invalid address \(network.dhcpEnd)")
			}

			let home: Home = try Home(runMode: .app)
			let networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[network.name] != nil {
				throw ValidationError("Network \(network.name) already exist")
			}

			if CakedLib.NetworksHandler.isPhysicalInterface(name: network.name) {
				throw ValidationError("Network \(network.name) is a physical interface")
			}
			
			let network = VZSharedNetwork(
				mode: network.mode == .shared ? .shared : .host,
				netmask: netmask.description,
				dhcpStart: dhcpStart.description,
				dhcpEnd: dhcpEnd.description,
				dhcpLease: nil,
				interfaceID: network.interfaceID,
				nat66Prefix: nil
			)

			try network.validate(runMode: .app)
			
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
			_ = try NetworksHandler.create(networkName: self.currentItem.name, network: self.vzNetwork!, runMode: .app)
		} catch {
			alertError(error)
		}
		dismiss()
	}
	
	static func getDhcpLease() -> String {
		guard let dhcpLease = try? NetworksHandler.getDHCPLease(runMode: .app) else {
			return ""
		}
		
		return "\(dhcpLease)"
	}
}

#Preview {
	NetworkWizard(appState: .constant(AppState.shared))
}
