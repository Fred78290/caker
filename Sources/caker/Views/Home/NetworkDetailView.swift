//
//  NetworkDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/10/2025.
//

import GRPCLib
import SwiftUI
import CakedLib

struct NetworkDetailView: View {
	@Binding var currentItem: BridgedNetwork
	var forEditing: Bool = false
	@State var dhcpStart: TextFieldStore<String, RegexParseableFormatStyle>
	@State var dhcpEnd: TextFieldStore<String, RegexParseableFormatStyle>
	@State var netmask: TextFieldStore<String, RegexParseableFormatStyle>

	init(_ currentItem: Binding<BridgedNetwork>, forEditing: Bool = false) {
		self._currentItem = currentItem
		self.dhcpStart = .init(value: currentItem.wrappedValue.gateway.stringBefore(before: "/"), type: .none, maxLength: 16, formatter: .regex("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"))
		self.dhcpEnd = .init(value: currentItem.wrappedValue.dhcpEnd.stringBefore(before: "/"), type: .none, maxLength: 16, formatter: .regex("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"))
		self.netmask = .init(value: currentItem.wrappedValue.gateway.stringAfter(after: "/"), type: .none, maxLength: 16, formatter: .regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})$"))
	}

	var body: some View {
		GeometryReader { geometry in
			let contentWidth = geometry.size.width - 120

			Form {
				Section {
					LabeledContent("Mode") {
						HStack {
							Picker("Mode", selection: $currentItem.mode) {
								ForEach(BridgedNetworkMode.allCases, id: \.self) { mode in
									Text(mode.rawValue).tag(mode)
								}
							}
							.menuStyle(.button)
							.pickerStyle(.menu)
							.allowsHitTesting(forEditing)
							.labelsHidden()
							Spacer()
						}
					}
					
					LabeledContent("Name") {
						TextField("", text: $currentItem.name)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: contentWidth)
					}
					
					LabeledContent("DHCP Start") {
						TextField("", text: $dhcpStart.text)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: contentWidth)
					}
					.formatAndValidate($dhcpStart)
					.onChange(of: dhcpStart.value) { _, newValue in
						let cidr = self.netmask.value.netmaskToCidr()
						self.currentItem.gateway = "\(newValue)/\(cidr)"
					}
					
					LabeledContent("DHCP End") {
						TextField("", text: $dhcpEnd.text)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: contentWidth)
					}
					.formatAndValidate($dhcpEnd)
					.onChange(of: dhcpEnd.value) { _, newValue in
						let cidr = self.netmask.value.netmaskToCidr()
						self.currentItem.dhcpEnd = "\(newValue)/\(cidr)"
					}
					
					LabeledContent("DHCP Lease") {
						TextField("", text: $currentItem.dhcpLease)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: contentWidth)
					}
					
					LabeledContent("Netmask") {
						TextField("", text: $netmask.text)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: contentWidth)
					}
					.formatAndValidate($netmask)
					.onChange(of: netmask.value) { _, newValue in
						let cidr = newValue.netmaskToCidr()
						self.currentItem.gateway = "\(self.dhcpStart.value)/\(cidr)"
						self.currentItem.dhcpEnd = "\(self.dhcpEnd.value)/\(cidr)"
					}
					
					LabeledContent("Interface ID") {
						TextField("", text: $currentItem.interfaceID)
							.rounded(.leading)
							.allowsHitTesting(forEditing)
							.frame(width: contentWidth)
					}
				}
			}.padding()
		}
	}
}

#Preview {
	NetworkDetailView(.constant(BridgedNetwork(name: "nat", mode: .nat, description: "NAT shared network", gateway: "", dhcpEnd: "", dhcpLease: "", interfaceID: "nat", endpoint: "")), forEditing: true)
}
