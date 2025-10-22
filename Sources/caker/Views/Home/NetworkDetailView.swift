//
//  NetworkDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/10/2025.
//

import GRPCLib
import SwiftUI

struct NetworkDetailView: View {
	@Binding var currentItem: BridgedNetwork
	@State var model: BridgedNetwork
	var forEditing: Bool = false

	init(currentItem: Binding<BridgedNetwork>) {
		self._currentItem = currentItem
		self.model = currentItem.wrappedValue
	}

	var body: some View {
		Section(currentItem.name) {
			LabeledContent("Name") {
				TextField("", text: $currentItem.name)
					.rounded(.leading)
					.allowsHitTesting(forEditing)
					.frame(width: 200)
					.onChange(of: currentItem.gateway) { _, newValue in
						currentItem.gateway = newValue
					}
			}
			
			LabeledContent("Mode") {
				Picker("Mode", selection: $model.mode) {
					ForEach(BridgedNetworkMode.allCases, id: \.self) { mode in
						Text(mode.rawValue).tag(mode)
					}
				}
				.allowsHitTesting(forEditing)
				.labelsHidden()
				.frame(width: 100)
			}
			
			LabeledContent("Gateway") {
				TextField("", text: $currentItem.gateway)
					.rounded(.leading)
					.allowsHitTesting(forEditing)
					.frame(width: 200)
					.onChange(of: currentItem.gateway) { _, newValue in
						currentItem.gateway = newValue
					}
			}
			
			LabeledContent("DHCP End") {
				TextField("", text: $currentItem.dhcpEnd)
					.rounded(.leading)
					.allowsHitTesting(forEditing)
					.frame(width: 200)
					.onChange(of: currentItem.dhcpEnd) { _, newValue in
						currentItem.dhcpEnd = newValue
					}
			}
			
			LabeledContent("Interface ID") {
				TextField("", text: $currentItem.interfaceID)
					.rounded(.leading)
					.allowsHitTesting(forEditing)
					.frame(width: 200)
					.onChange(of: currentItem.interfaceID) { _, newValue in
						currentItem.interfaceID = newValue
					}
			}
		}.padding(25)
	}
}

#Preview {
	NetworkDetailView(currentItem: .constant(.init(name: "nat", mode: .nat, description: "NAT shared network", gateway: "", interfaceID: "nat", endpoint: "")))
}
