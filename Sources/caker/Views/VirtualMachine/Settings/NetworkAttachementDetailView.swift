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
				Picker("Network name", selection: $currentItem.network) {
					ForEach(names, id: \.self) { name in
						Text(name).tag(name).frame(width: 100)
					}
				}.labelsHidden()
			}
			
			LabeledContent("Mode") {
				Picker("Mode", selection: $currentItem.mode) {
					Text("default").tag(nil as NetworkMode?).frame(width: 100)
					ForEach([NetworkMode.auto, NetworkMode.manual], id: \.self) { mode in
						Text(mode.description).tag(mode as NetworkMode?).frame(width: 100)
					}
				}.labelsHidden()
			}

			LabeledContent("Mac address") {
				Button(action: {
					currentItem.macAddress = VZMACAddress.randomLocallyAdministered().string
				}) {
					Image(systemName: "arrow.trianglehead.clockwise")
				}.buttonStyle(.borderless)
				TextField("", value: $currentItem.macAddress, format: .optionalMacAddress)
					.multilineTextAlignment(.center)
					.textFieldStyle(SquareBorderTextFieldStyle())
					.labelsHidden()
					.frame(width: 150)
			}
		}
    }
}

#Preview {
	NetworkAttachementDetailView(currentItem: .constant(.init(network: "nat", mode: .auto)))
}
