//
//  NetworkAttachementView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct NetworkAttachementView: View {
	@Binding var networks: [BridgeAttachement]

	var body: some View {
		EditableList($networks) { $item in
			Section {
				NetworkAttachementDetailView(currentItem: $item)
			}
		}.onAddItem(systemName: "badge.plus.radiowaves.right") {
			NetworkAttachementNewItemView(networks: $networks)
		}
	}
}

#Preview {
	NetworkAttachementView(networks: .constant([]))
}
