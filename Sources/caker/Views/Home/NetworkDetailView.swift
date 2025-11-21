//
//  NetworkDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/10/2025.
//

import GRPCLib
import SwiftUI
import CakedLib

class NetworkDetailViewModel: ObservableObject, Observable {
	static var dhcpLeaseRange = RangeIntegerStyle(range: 60...86400)

	@Published var dhcpStart: TextFieldStore<String, RegexParseableFormatStyle>
	@Published var dhcpEnd: TextFieldStore<String, RegexParseableFormatStyle>
	@Published var netmask: TextFieldStore<String, RegexParseableFormatStyle>
	@Published var dhcpLease: TextFieldStore<Int, RangeIntegerStyle>
	
	init(network: BridgedNetwork) {
		self.dhcpLease = TextFieldStore(value: Int(network.dhcpLease) ?? 86400, text: network.dhcpLease, type: .int, maxLength: 5, allowNegative: false, formatter: Self.dhcpLeaseRange)
		self.dhcpStart = .init(value: network.gateway.stringBefore(before: "/"), type: .none, maxLength: 16, formatter: .regex("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"))
		self.dhcpEnd = .init(value: network.dhcpEnd.stringBefore(before: "/"), type: .none, maxLength: 16, formatter: .regex("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$"))
		self.netmask = .init(value: network.gateway.stringAfter(after: "/").cidrToNetmask(), type: .none, maxLength: 16, formatter: .regex("^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})$"))
	}
}

struct NetworkDetailView: View {
	@Binding private var currentItem: BridgedNetwork
	@Binding private var reloadNetwork: Bool
	private var model: NetworkDetailViewModel
	private var forEditing: Bool

	init(_ currentItem: Binding<BridgedNetwork>, reloadNetwork: Binding<Bool>, forEditing: Bool = false) {
		self.forEditing = forEditing
		self._currentItem = currentItem
		self._reloadNetwork = reloadNetwork
		self.model = NetworkDetailViewModel(network: currentItem.wrappedValue)
	}

	private var allowNetworkManagement: Bool {
		let disabled: Bool
		
		if #available(macOS 26.0, *) {
			disabled = currentItem.mode == .host || currentItem.mode == .shared || currentItem.mode == .nat
		} else {
			disabled = currentItem.mode == .nat
		}

		return disabled == false
	}

	var body: some View {
		@Bindable var model = self.model

		GeometryReader { geometry in
			let contentWidth = geometry.size.width - 160

			VStack {
				Form {
					Section {
						LabeledContent("Network mode") {
							let modes = self.forEditing ? [BridgedNetworkMode.shared, BridgedNetworkMode.host] : BridgedNetworkMode.allCases
							
							HStack {
								Picker("Mode", selection: $currentItem.mode) {
									ForEach(modes, id: \.self) { mode in
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
						
						LabeledContent("Network name") {
							TextField("", text: $currentItem.name)
								.rounded(.leading)
								.allowsHitTesting(forEditing)
								.frame(width: contentWidth)
						}
						
						LabeledContent("DHCP Lease") {
							TextField("", text: $model.dhcpLease.text)
								.rounded(.leading)
								.allowsHitTesting(forEditing)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.dhcpLease) {
							NetworkDetailViewModel.dhcpLeaseRange.outside($0)
						}
						.onChange(of: model.dhcpLease.value) { _, newValue in
							self.currentItem.dhcpLease = "\(newValue)"
						}
						
						LabeledContent("Network start") {
							TextField("", text: $model.dhcpStart.text)
								.rounded(.leading)
								.allowsHitTesting(forEditing)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.dhcpStart) { value in
							value.isValidIP() == false
						}
						.onChange(of: model.dhcpStart.value) { _, newValue in
							let cidr = model.netmask.value.netmaskToCidr()
							self.currentItem.gateway = "\(newValue)/\(cidr)"
						}
						
						LabeledContent("Network end") {
							TextField("", text: $model.dhcpEnd.text)
								.rounded(.leading)
								.allowsHitTesting(forEditing)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.dhcpEnd) { value in
							value.isValidIP() == false
						}
						.onChange(of: model.dhcpEnd.value) { _, newValue in
							let cidr = self.model.netmask.value.netmaskToCidr()
							self.currentItem.dhcpEnd = "\(newValue)/\(cidr)"
						}
						
						LabeledContent("Netmask") {
							TextField("", text: $model.netmask.text)
								.rounded(.leading)
								.allowsHitTesting(forEditing)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.netmask){ value in
							value.isValidNetmask() == false
						}
						.onChange(of: model.netmask.value) { _, newValue in
							let cidr = newValue.netmaskToCidr()
							self.currentItem.gateway = "\(self.model.dhcpStart.value)/\(cidr)"
							self.currentItem.dhcpEnd = "\(self.model.dhcpEnd.value)/\(cidr)"
						}
						
						LabeledContent("Interface ID") {
							TextField("", text: $currentItem.interfaceID)
								.rounded(.leading)
								.allowsHitTesting(forEditing)
								.frame(width: contentWidth)
						}

						if forEditing == false {
							LabeledContent("Used by") {
								Text("\(currentItem.usedBy) instances")
							}
						}
					}
					
				}.padding()

				if forEditing == false && self.allowNetworkManagement {
					Divider()

					if currentItem.endpoint.isEmpty {
						Button("Start network") {
							let result = NetworksHandler.start(networkName: self.currentItem.name, runMode: .app)
							
							if result.started == false {
								alertError(ServiceError(result.reason))
							} else {
								self.currentItem.endpoint = result.reason
								self.reloadNetwork = true
							}
						}
					} else {
						Button("Stop network") {
							let result = NetworksHandler.stop(networkName: self.currentItem.name, runMode: .app)
							
							if result.stopped == false {
								alertError(ServiceError(result.reason))
							} else {
								self.currentItem.endpoint = ""
								self.reloadNetwork = true
							}
						}
					}
				}
			}
		}
	}
}

#Preview {
	NetworkDetailView(.constant(BridgedNetwork(name: "nat", mode: .nat, description: "NAT shared network", gateway: "", dhcpEnd: "", dhcpLease: "", interfaceID: "nat", endpoint: "", usedBy: 0)), reloadNetwork: .constant(false), forEditing: true)
}
