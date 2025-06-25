//
//  NetworkAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//
import ArgumentParser
import SwiftUI
import GRPCLib
import CakedLib
import Virtualization

struct NetworkAttachementNewItemView: View {
	@Binding var networks: [BridgeAttachement]
	@State var newItem: BridgeAttachement = .init(network: "nat", mode: .auto)

	let names: [String] = try! NetworksHandler.networks(runMode: .app).map { $0.name }

	var body: some View {
		EditableListNewItem(newItem: $newItem, $networks) {
			Section("New network attachment") {
				NetworkAttachementDetailView(currentItem: $newItem)
			}
		}
    }
}

#Preview {
    NetworkAttachementNewItemView(networks: .constant([]))
}
