//
//  NetworkAttachementDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//
import ArgumentParser
import SwiftUI
import GRPCLib
import CakedLib
import Virtualization

struct NetworkAttachementDetailView: View {
	private let names: [String] = try! NetworksHandler.networks(runMode: .app).map { $0.name }

	@Binding private var currentItem: BridgeAttachement
	@State private var model: BridgeAttachementModel

	private class BridgeAttachementModel: ObservableObject {
		@Published var network: String
		@Published var mode: NetworkMode?
		@Published var macAddress: String?
		
		init(item: BridgeAttachement) {
			self.network = item.network
			self.mode = item.mode
			self.macAddress = item.macAddress
		}
	}

	init(currentItem: Binding<BridgeAttachement>) {
		_currentItem = currentItem
		self.model = .init(item: currentItem.wrappedValue)
	}

	var body: some View {
		VStack {
			LabeledContent("Network name") {
				HStack {
					Picker("Network name", selection: $model.network) {
						ForEach(names, id: \.self) { name in
							Text(name).tag(name)
						}
					}
					.labelsHidden()
					.onChange(of: model.network) { newValue in
						currentItem.network = newValue
					}
				}.frame(width: 100)
			}
			
			LabeledContent("Mode") {
				HStack {
					Picker("Mode", selection: $model.mode) {
						Text("default").tag(nil as NetworkMode?)
						ForEach([NetworkMode.auto, NetworkMode.manual], id: \.self) { mode in
							Text(mode.description).tag(mode as NetworkMode?)
						}
					}
					.labelsHidden()
					.onChange(of: model.mode) { newValue in
						currentItem.mode = newValue
					}
				}.frame(width: 100)
			}

			LabeledContent("Mac address") {
				HStack {
					Button(action: {
						model.macAddress = VZMACAddress.randomLocallyAdministered().string
					}) {
						Image(systemName: "arrow.trianglehead.clockwise")
					}.buttonStyle(.borderless)
					TextField("", value: $model.macAddress, format: .optionalMacAddress)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.onSubmit {
							currentItem.macAddress = model.macAddress
						}
				}.frame(width: 200)
			}
		}
    }
}

#Preview {
	NetworkAttachementDetailView(currentItem: .constant(.init(network: "nat", mode: .auto)))
}
