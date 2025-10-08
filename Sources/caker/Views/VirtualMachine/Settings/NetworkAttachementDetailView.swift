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
	private let names: [String] = try! NetworksHandler.networks(runMode: .app).map { $0.name }

	private class BridgeAttachementModel: ObservableObject, Observable {
		@Published var network: String
		@Published var mode: NetworkMode?
		@Published var macAddress: TextFieldStore<String?, OptionalMacAddressParseableFormatStyle>

		init(item: BridgeAttachement) {
			self.network = item.network
			self.mode = item.mode
			self.macAddress = .init(value: item.macAddress, type: .macAddress, maxLength: 18, allowNegative: false, formatter: OptionalMacAddressParseableFormatStyle())
		}
	}

	@Binding private var currentItem: BridgeAttachement
	@StateObject private var model: BridgeAttachementModel
	private var readOnly: Bool

	init(currentItem: Binding<BridgeAttachement>, readOnly: Bool = true) {
		_currentItem = currentItem

		self._model = StateObject(wrappedValue: BridgeAttachementModel(item: currentItem.wrappedValue))
		self.readOnly = readOnly
	}

	var body: some View {
		VStack {
			LabeledContent("Network name") {
				HStack {
					Spacer()
					Picker("Network name", selection: $currentItem.network) {
						ForEach(names, id: \.self) { name in
							Text(name).tag(name)
						}
					}
					.allowsHitTesting(readOnly == false)
					.labelsHidden()
				}.frame(width: 100)
			}

			LabeledContent("Mode") {
				HStack {
					Spacer()
					Picker("Mode", selection: $currentItem.mode) {
						Text("default").tag(nil as NetworkMode?)
						ForEach([NetworkMode.auto, NetworkMode.manual], id: \.self) { mode in
							Text(mode.description).tag(mode as NetworkMode?)
						}
					}
					.allowsHitTesting(readOnly == false)
					.labelsHidden()
				}.frame(width: 100)
			}

			LabeledContent("Mac address") {
				HStack {
					if readOnly == false {
						Button(action: {
							model.macAddress = .init(value: VZMACAddress.randomLocallyAdministered().string, type: .macAddress, maxLength: 18, allowNegative: false, formatter: OptionalMacAddressParseableFormatStyle())
						}) {
							Image(systemName: "arrow.trianglehead.clockwise")
						}.buttonStyle(.borderless)
					}

					TextField("", text: $model.macAddress.text)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.allowsHitTesting(readOnly == false)
						.clipShape(RoundedRectangle(cornerRadius: 6))
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
