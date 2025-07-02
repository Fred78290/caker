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

	@Binding var currentItem: BridgeAttachement

	var body: some View {
		VStack {
			LabeledContent("Network name") {
				HStack {
					Picker("Network name", selection: $currentItem.network) {
						ForEach(names, id: \.self) { name in
							Text(name).tag(name)
						}
					}.labelsHidden()
				}.frame(width: 100)
			}
			
			LabeledContent("Mode") {
				HStack {
					Picker("Mode", selection: $currentItem.mode) {
						Text("default").tag(nil as NetworkMode?)
						ForEach([NetworkMode.auto, NetworkMode.manual], id: \.self) { mode in
							Text(mode.description).tag(mode as NetworkMode?)
						}
					}.labelsHidden()
				}.frame(width: 100)
			}

			LabeledContent("Mac address") {
				HStack {
					Button(action: {
						currentItem.macAddress = VZMACAddress.randomLocallyAdministered().string
					}) {
						Image(systemName: "arrow.trianglehead.clockwise")
					}.buttonStyle(.borderless)
					TextField("", value: $currentItem.macAddress, format: .optionalMacAddress)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
				}.frame(width: 200)
			}
		}
    }
}

#Preview {
	NetworkAttachementDetailView(currentItem: .constant(.init(network: "nat", mode: .auto)))
}
