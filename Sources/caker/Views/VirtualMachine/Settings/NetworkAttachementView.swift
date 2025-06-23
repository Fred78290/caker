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
			Text(item.description)
		}.onAddItem(systemName: "badge.plus.radiowaves.right") {
			print("NetworkAttachementView: Add network")
		}
	}
}

#Preview {
	NetworkAttachementView(networks: .constant([]))
}
