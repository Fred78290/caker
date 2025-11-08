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
	@State private var vzNetwork: VZSharedNetwork? = nil
	@State private var currentItem = BridgedNetwork(name: "New hosted network", mode: .host, description: "Hosted network", gateway: "192.168.1.1/24", dhcpEnd: "192.168.1.254/24", dhcpLease: Self.getDhcpLease(), interfaceID: UUID().uuidString, endpoint: "")

	var body: some View {
		VStack {
			NetworkDetailView($currentItem, forEditing: true)
			Spacer()
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
		.onChange(of: currentItem) {
			self.vzNetwork = self.validate()
		}
    }
	
	func validate() -> VZSharedNetwork? {
		do {
			let gateway = self.currentItem.gateway.toIPV4()
			let dhcpEnd = self.currentItem.dhcpEnd.toIPV4()

			guard let dhcpStart = gateway.address, let netmask = gateway.netmask else {
				throw ValidationError("Invalid address \(self.currentItem.gateway)")
			}

			guard let dhcpEnd = dhcpEnd.address else {
				throw ValidationError("Invalid address \(self.currentItem.dhcpEnd)")
			}

			let home: Home = try Home(runMode: .app)
			let networkConfig = try home.sharedNetworks()

			if networkConfig.sharedNetworks[self.currentItem.name] != nil {
				throw ValidationError("Network \(self.currentItem.name) already exist")
			}

			if CakedLib.NetworksHandler.isPhysicalInterface(name: self.currentItem.name) {
				throw ValidationError("Network \(self.currentItem.name) is a physical interface")
			}
			
			let network = VZSharedNetwork(
				mode: self.currentItem.mode == .shared ? .shared : .host,
				netmask: netmask.description,
				dhcpStart: dhcpStart.description,
				dhcpEnd: dhcpEnd.description,
				dhcpLease: nil,
				interfaceID: self.currentItem.interfaceID,
				nat66Prefix: nil
			)

			try network.validate()
			
			return network
		} catch {
			return nil
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
