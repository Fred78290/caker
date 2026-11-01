//
//  NetworkDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/10/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

@Observable class NetworkDetailViewModel {
	static var dhcpLeaseRange = RangeIntegerStyle(range: 60...86400)

	var dhcpStart: TextFieldStore<String, RegexParseableFormatStyle>
	var dhcpEnd: TextFieldStore<String, RegexParseableFormatStyle>
	var netmask: TextFieldStore<String, RegexParseableFormatStyle>
	var dhcpLease: TextFieldStore<Int, RangeIntegerStyle>

	/// Last usable host address (broadcast - 1) of the network containing `start`, or nil when it would not follow `start`.
	static func defaultDhcpEnd(start: String, netmask: String) -> String? {
		func octets(_ value: String) -> UInt32? {
			let parts = value.split(separator: ".").compactMap { UInt8($0) }

			guard parts.count == 4 else {
				return nil
			}

			return parts.reduce(0) { ($0 << 8) | UInt32($1) }
		}

		guard let address = octets(start), let mask = octets(netmask), mask != 0xFFFF_FFFF else {
			return nil
		}

		let end = ((address & mask) | ~mask) - 1

		guard end > address else {
			return nil
		}

		return "\(end >> 24 & 0xFF).\(end >> 16 & 0xFF).\(end >> 8 & 0xFF).\(end & 0xFF)"
	}

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
	@State private var networkActionRunning = false
	// Kept in @State so text being typed survives the parent re-evaluating its body.
	@State private var model: NetworkDetailViewModel
	private var forEditing: Bool
	private var allowEdit: Bool

	/// Name and mode are only editable when creating; the other fields are also editable
	/// on an existing network when `allowEdit` is set.
	private var fieldsEditable: Bool {
		forEditing || allowEdit
	}

	init(_ currentItem: Binding<BridgedNetwork>, reloadNetwork: Binding<Bool>, forEditing: Bool = false, allowEdit: Bool = false) {
		self.forEditing = forEditing
		self.allowEdit = allowEdit
		self._currentItem = currentItem
		self._reloadNetwork = reloadNetwork
		self._model = State(initialValue: NetworkDetailViewModel(network: currentItem.wrappedValue))
	}

	private var allowNetworkManagement: Bool {
		return currentItem.managed
	}

	var body: some View {
		@Bindable var model = self.model

		GeometryReader { geometry in
			let contentWidth = max(0, geometry.size.width - 160)

			VStack {
				Form {
					Section {
						LabeledContent {
							TextField(String.empty, text: $currentItem.name)
								.rounded(.leading)
								.allowsHitTesting(forEditing)
								.frame(width: contentWidth)
						} label: {
							VStack {
								HStack {
									Spacer()
									Text("Network name")
								}
								HStack {
									Spacer()
									Text("\(currentItem.name.count)/\(URL.maxNetworkNameLength)")
										.font(.caption)
										.foregroundStyle(currentItem.name.count > URL.maxNetworkNameLength ? .red : .secondary)
								}
							}
						}

						LabeledContent("Network mode") {
							let modes = self.forEditing ? [BridgedNetworkMode.shared, BridgedNetworkMode.host] : BridgedNetworkMode.allCases

							HStack {
								Picker("Mode", selection: $currentItem.mode) {
									ForEach(modes, id: \.self) { mode in
										Text(LocalizedStringKey(stringLiteral: mode.rawValue)).tag(mode)
									}
								}
								.menuStyle(.button)
								.pickerStyle(.menu)
								.allowsHitTesting(forEditing)
								.labelsHidden()

								Spacer()
								Toggle("Enable DNS", isOn: $currentItem.dns)
									.allowsHitTesting(fieldsEditable)
								Spacer()
							}
						}

						LabeledContent("DHCP Lease") {
							TextField(String.empty, text: $model.dhcpLease.text)
								.rounded(.leading)
								.allowsHitTesting(fieldsEditable)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.dhcpLease) {
							NetworkDetailViewModel.dhcpLeaseRange.outside($0)
						}
						.onChange(of: model.dhcpLease.value) { _, newValue in
							if NetworkDetailViewModel.dhcpLeaseRange.inRange(newValue) {
								self.currentItem.dhcpLease = "\(newValue)"
							}
						}

						LabeledContent("Network start") {
							TextField(String.empty, text: $model.dhcpStart.text)
								.rounded(.leading)
								.allowsHitTesting(fieldsEditable)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.dhcpStart) { value in
							value.isValidIP() == false
						}
						.onChange(of: model.dhcpStart.value) { _, newValue in
							if newValue.isValidIP() {
								let cidr = model.netmask.value.netmaskToCidr()
								self.currentItem.gateway = "\(newValue)/\(cidr)"

								// A new start address moves the DHCP range: default the end to the last usable address of the network.
								if let dhcpEnd = NetworkDetailViewModel.defaultDhcpEnd(start: newValue, netmask: model.netmask.value) {
									model.dhcpEnd.text = dhcpEnd
									model.dhcpEnd.value = dhcpEnd
									self.currentItem.dhcpEnd = "\(dhcpEnd)/\(cidr)"
								}
							}
						}

						LabeledContent("Network end") {
							TextField(String.empty, text: $model.dhcpEnd.text)
								.rounded(.leading)
								.allowsHitTesting(fieldsEditable)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.dhcpEnd) { value in
							value.isValidIP() == false
						}
						.onChange(of: model.dhcpEnd.value) { _, newValue in
							if newValue.isValidIP() {
								let cidr = self.model.netmask.value.netmaskToCidr()
								self.currentItem.dhcpEnd = "\(newValue)/\(cidr)"
							}
						}

						LabeledContent("Netmask") {
							TextField(String.empty, text: $model.netmask.text)
								.rounded(.leading)
								.allowsHitTesting(fieldsEditable)
								.frame(width: contentWidth)
						}
						.formatAndValidate($model.netmask) { value in
							value.isValidNetmask() == false
						}
						.onChange(of: model.netmask.value) { _, newValue in
							if newValue.isValidNetmask() {
								let cidr = newValue.netmaskToCidr()
								self.currentItem.gateway = "\(self.model.dhcpStart.value)/\(cidr)"
								self.currentItem.dhcpEnd = "\(self.model.dhcpEnd.value)/\(cidr)"
							}
						}

						LabeledContent("Interface ID") {
							TextField(String.empty, text: $currentItem.interfaceID)
								.rounded(.leading)
								.allowsHitTesting(fieldsEditable)
								.frame(width: contentWidth)
						}

						if forEditing == false {
							LabeledContent("Referenced by") {
								Text("\(currentItem.usedBy.used) instances")
							}
							LabeledContent("Used by") {
								Text("\(currentItem.usedBy.active) instances")
							}
						}
					}

				}.padding()

				if forEditing == false && self.allowNetworkManagement {
					Divider()

					if currentItem.running == false {
						AsyncButton("Start network") { done in
							let name = currentItem.name

							networkActionRunning = true

							Task.detached {
								let result = AppState.shared.startNetwork(networkName: name)

								await MainActor.run {
									defer {
										networkActionRunning = false
										done()
									}

									if result.started == false {
										alertError(String(localized: "Start network failed"), result.reason)
									} else {
										self.currentItem.endpoint = result.reason
										self.currentItem.running = true
										self.reloadNetwork = true
									}
								}
							}
						}
						.disabled(networkActionRunning)
						.withButtonStyle(.bordered)
					} else if currentItem.usedBy.active == 0 {
						AsyncButton("Stop network") { done in
							let name = currentItem.name

							networkActionRunning = true

							Task.detached {
								let result = AppState.shared.stopNetwork(networkName: name)

								await MainActor.run {
									defer {
										networkActionRunning = false
										done()
									}

									if result.stopped == false {
										alertError(String(localized: "Stop network failed"), result.reason)
									} else {
										self.currentItem.endpoint = String.empty
										self.currentItem.running = false
										self.reloadNetwork = true
									}
								}
							}
						}
						.disabled(networkActionRunning)
						.withButtonStyle(.bordered)
					}
				}
			}
		}
	}
}

extension BridgedNetwork {
	/// Everything `networks configure` can change.
	func sameConfiguration(as other: BridgedNetwork) -> Bool {
		self.gateway == other.gateway && self.dhcpEnd == other.dhcpEnd && self.dhcpLease == other.dhcpLease && self.interfaceID == other.interfaceID && self.dns == other.dns
	}

	/// Identity of the configuration, to rebuild the editor when it changes behind its back.
	var configurationRevision: String {
		"\(self.id)|\(self.gateway)|\(self.dhcpEnd)|\(self.dhcpLease)|\(self.interfaceID)|\(self.dns)"
	}

	/// A managed shared/host network can be reconfigured while no active VM uses it.
	var canBeEdited: Bool {
		self.managed && [.shared, .host].contains(self.mode) && self.name != BridgeAttachement.defaultNetworkName && self.usedBy.active == 0
	}
}

/// Detail of an existing network: editable (with Save/Revert) while no active VM uses it.
struct EditableNetworkDetailView: View {
	private let network: BridgedNetwork
	@Binding private var reloadNetwork: Bool
	@State private var draft: BridgedNetwork
	@State private var saving = false
	@State private var resetToken = UUID()

	init(network: BridgedNetwork, reloadNetwork: Binding<Bool>) {
		self.network = network
		self._reloadNetwork = reloadNetwork
		self._draft = State(initialValue: network)
	}

	private var canEdit: Bool {
		self.network.canBeEdited
	}

	private var dirty: Bool {
		self.draft.sameConfiguration(as: self.network) == false
	}

	/// Runtime state always comes from the live network; only the configuration comes from the draft.
	private var binding: Binding<BridgedNetwork> {
		Binding<BridgedNetwork>(
			get: {
				var item = self.draft

				item.running = self.network.running
				item.endpoint = self.network.endpoint
				item.usedBy = self.network.usedBy

				return item
			},
			set: { newValue in
				self.draft.gateway = newValue.gateway
				self.draft.dhcpEnd = newValue.dhcpEnd
				self.draft.dhcpLease = newValue.dhcpLease
				self.draft.interfaceID = newValue.interfaceID
				self.draft.dns = newValue.dns
			}
		)
	}

	private var invalidReason: String? {
		guard let gateway = draft.gateway.toIPV4().address, draft.gateway.toIPV4().netmask != nil else {
			return String(localized: "Invalid address \(draft.gateway)")
		}

		guard let dhcpEnd = draft.dhcpEnd.toIPV4().address else {
			return String(localized: "Invalid address \(draft.dhcpEnd)")
		}

		guard let inet = draft.gateway.toNetwork(), inet.contains(dhcpEnd) else {
			return String(localized: "dhcp end \(String(dhcpEnd)) is not in the range of the network \(draft.gateway)")
		}

		if draft.dhcpLease.isEmpty == false, NetworkDetailViewModel.dhcpLeaseRange.inRange(Int(draft.dhcpLease) ?? 0) == false {
			return String(localized: "Invalid dhcp lease \(draft.dhcpLease)")
		}

		_ = gateway

		return nil
	}

	var body: some View {
		VStack(spacing: 0) {
			NetworkDetailView(self.binding, reloadNetwork: self.$reloadNetwork, allowEdit: self.canEdit)
				.id(self.resetToken)

			if self.canEdit && self.dirty {
				Divider()

				if let reason = self.invalidReason {
					Text(reason)
						.font(.callout)
						.foregroundStyle(.red)
						.padding(.top, 8)
				}

				HStack {
					Spacer()

					Button("Revert") {
						self.draft = self.network
						self.resetToken = UUID()
					}
					.withButtonStyle(.bordered)
					.disabled(self.saving)

					Button("Save") {
						self.save()
					}
					.withButtonStyle(.borderedProminent)
					.disabled(self.saving || self.invalidReason != nil)

					Spacer()
				}
				.padding()
			}
		}
	}

	private func save() {
		let item = self.binding.wrappedValue

		self.saving = true

		Task.detached {
			let result = AppState.shared.configureNetwork(network: item)

			await MainActor.run {
				self.saving = false

				if result.configured {
					self.reloadNetwork = true
				} else {
					alertError(String(localized: "Configure network failed"), result.reason)
				}
			}
		}
	}
}

#Preview {
	NetworkDetailView(
		.constant(
			BridgedNetwork(
				name: BridgeAttachement.defaultNetworkName,
				mode: .nat,
				description: BridgeAttachement.defaultNetworkDescription,
				gateway: BridgeAttachement.defaultNetworkGateway,
				dhcpEnd: String.empty,
				dhcpLease: String.empty,
				interfaceID: BridgeAttachement.defaultNetworkUUID,
				endpoint: String.empty,
				running: false,
				managed: true,
				dns: true,
				usedBy: BridgedNetwork.NetworkUsage(used: 0, active: 0))),
		reloadNetwork: .constant(false), forEditing: true)
}
