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
			HStack {
				Text("Network name")
				Spacer()
				HStack {
					Spacer()
					Picker("Network name", selection: $currentItem.network) {
						ForEach(names, id: \.self) { name in
							Text(name).tag(name)
						}
					}.labelsHidden().frame(width: 80)
				}.frame(width: 300)
			}
			
			HStack {
				Text("Mode")
				Spacer()
				HStack {
					Spacer()
					Picker("Mode", selection: $currentItem.mode) {
						ForEach([NetworkMode.auto, NetworkMode.manual], id: \.self) { mode in
							Text(mode.description).tag(mode).frame(width: 80)
						}
					}.labelsHidden().frame(width: 80)
				}.frame(width: 300)
			}

			HStack {
				Text("Mac address")
				Spacer()
				HStack {
					Spacer()
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
				}.frame(width: 300)
			}
		}
    }
}

#Preview {
	NetworkAttachementDetailView(currentItem: .constant(.init(network: "nat", mode: .auto)))
}
