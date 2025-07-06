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
	private var readOnly: Bool

	init(currentItem: Binding<BridgeAttachement>, readOnly: Bool = true) {
		_currentItem = currentItem
		self.readOnly = readOnly
	}

	var body: some View {
		VStack {
			LabeledContent("Network name") {
				HStack {
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
							currentItem.macAddress = VZMACAddress.randomLocallyAdministered().string
						}) {
							Image(systemName: "arrow.trianglehead.clockwise")
						}.buttonStyle(.borderless)
					}

					TextField("", value: $currentItem.macAddress, format: .optionalMacAddress)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.allowsHitTesting(readOnly == false)
						.clipShape(RoundedRectangle(cornerRadius: 6))
				}.frame(width: 200)
			}
		}
    }
}

#Preview {
	NetworkAttachementDetailView(currentItem: .constant(.init(network: "nat", mode: .auto)))
}
