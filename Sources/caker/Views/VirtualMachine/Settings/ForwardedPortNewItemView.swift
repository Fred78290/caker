//
//  ForwardedPortNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct ForwardedPortNewItemView: View {
	@Binding var forwardPorts: [TunnelAttachement]
	@State var newItem: TunnelAttachement = .init()

	var body: some View {
		EditableListNewItem(newItem: $newItem, $forwardPorts) {
			Section("New port forwarding") {
				Text("")
			}
		}
    }
}

#Preview {
	ForwardedPortNewItemView(forwardPorts: .constant([]))
}
