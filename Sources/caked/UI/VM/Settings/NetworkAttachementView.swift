//
//  NetworkAttachementView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import SwiftUI
import GRPCLib

struct NetworkAttachementView: View {
	@Binding var networks: [BridgeAttachement]

	var body: some View {
		EditableList($networks) { $item in
			Text(item.description)
		}
    }
}

#Preview {
	NetworkAttachementView(networks: .constant([]))
}
