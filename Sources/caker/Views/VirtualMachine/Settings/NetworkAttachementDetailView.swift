//
//  NetworkAttachementDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//
import ArgumentParser
import CakedLib
import GRPCLib
import SwiftUI
import Virtualization

struct NetworkAttachementDetailView: View {
	private let names: [String] = AppState.shared.networks.compactMap {
		$0.mode != .nat ? $0.name : nil
	}

	@Observable class BridgeAttachementModel {
		var network: String
		var mode: NetworkMode?
		var macAddress: TextFieldStore<String?, OptionalMacAddressParseableFormatStyle>

		init(item: BridgeAttachement) {
			self.network = item.network
			self.mode = item.mode
			self.macAddress = .init(value: item.macAddress, type: .macAddress, maxLength: 18, allowNegative: false, formatter: OptionalMacAddressParseableFormatStyle())
		}
	}

	@Binding private var currentItem: BridgeAttachement
	@State private var model: BridgeAttachementModel
	private var readOnly: Bool

	init(currentItem: Binding<BridgeAttachement>, readOnly: Bool = true) {
		_currentItem = currentItem

		self._model = State(initialValue: BridgeAttachementModel(item: currentItem.wrappedValue))
		self.readOnly = readOnly
	}

	var body: some View {
		if readOnly {
			compactRow
		} else {
			fullForm
		}
	}

	@ViewBuilder
	var compactRow: some View {
		HStack(spacing: 10) {
			ZStack {
				RoundedRectangle(cornerRadius: 7)
					.fill(Color.green.gradient)
					.frame(width: 28, height: 28)
				Image(systemName: "network")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(currentItem.network)
					.font(.system(size: 13, weight: .semibold))
				HStack(spacing: 6) {
					Text(currentItem.mode?.description ?? "default")
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
					if let mac = currentItem.macAddress {
						Text(mac)
							.font(.system(size: 11, design: .monospaced))
							.foregroundStyle(.secondary)
					}
				}
			}

			Spacer()
		}
		.padding(.vertical, 4)
	}

	@ViewBuilder
	var fullForm: some View {
		@Bindable var model = self.model

		VStack {
			LabeledContent("Network name") {
				HStack {
					Spacer()
					Picker("Network name", selection: $currentItem.network) {
						ForEach(names, id: \.self) { name in
							Text(name).tag(name)
						}
					}
					.labelsHidden()
				}.frame(width: 200)
			}

			LabeledContent("Mode") {
				HStack {
					Spacer()
					Picker("Mode", selection: $currentItem.mode) {
						Text("default").tag(nil as NetworkMode?)
						ForEach([NetworkMode.auto, NetworkMode.manual], id: \.self) { mode in
							Text(LocalizedStringKey(stringLiteral: mode.description)).tag(mode as NetworkMode?)
						}
					}
					.labelsHidden()
				}.frame(width: 200)
			}

			LabeledContent("Mac address") {
				HStack {
					Button(action: {
						model.macAddress = .init(value: VZMACAddress.randomLocallyAdministered().string, type: .macAddress, maxLength: 18, allowNegative: false, formatter: OptionalMacAddressParseableFormatStyle())
					}) {
						Image(systemName: "arrow.trianglehead.clockwise")
					}.buttonStyle(.borderless)

					TextField(String.empty, text: $model.macAddress.text)
						.rounded(.center)
						.formatAndValidate($model.macAddress)
						.onChange(of: model.macAddress.value) { _, newValue in
							self.currentItem.macAddress = newValue
						}
				}.frame(width: 200)
			}
		}
	}
}

#Preview {
	NetworkAttachementDetailView(currentItem: .constant(.init(network: "nat", mode: .auto)))
}
