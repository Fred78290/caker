//
//  NetworkDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/10/2025.
//

import GRPCLib
import SwiftUI

struct NetworkDetailView: View {
	@State var currentItem: BridgedNetwork
	var forEditing: Bool = false

	init(_ currentItem: State<BridgedNetwork>, forEditing: Bool = false) {
		self._currentItem = currentItem
	}

	var body: some View {
		GeometryReader { geometry in
				VStack {
					LabeledContent("Mode") {
						Picker("Mode", selection: $currentItem.mode) {
							ForEach(BridgedNetworkMode.allCases, id: \.self) { mode in
								Text(mode.rawValue).tag(mode)
							}
						}
						.allowsHitTesting(forEditing)
						.labelsHidden()
						.frame(width: 100)
					}.frame(width: geometry.size.width)
					
					LabeledContent("Name") {
						TextField("", text: $currentItem.name)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: 200)
					}.frame(width: geometry.size.width)
					
					LabeledContent("Gateway") {
						TextField("", text: $currentItem.gateway)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: 200)
					}.frame(width: geometry.size.width)
					
					LabeledContent("DHCP End") {
						TextField("", text: $currentItem.dhcpEnd)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: 200)
					}.frame(width: geometry.size.width)
					
					LabeledContent("Interface ID") {
						TextField("", text: $currentItem.interfaceID)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: 200)
					}.frame(width: geometry.size.width)
					Spacer()
				}
				.frame(width: geometry.size.width)
				.background(.green)
		}
	}
}

#Preview {
	NetworkDetailView(State(wrappedValue: BridgedNetwork(name: "nat", mode: .nat, description: "NAT shared network", gateway: "", interfaceID: "nat", endpoint: "")))
}
