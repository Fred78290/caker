//
//  ForwardedPortNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib
import CakeAgentLib
import NIOPortForwarding

struct ForwardedPortNewItemView: View {
	@Binding var forwardPorts: [TunnelAttachement]
	@State var newItem: TunnelAttachement = .init()

	var body: some View {
		EditableListNewItem(newItem: $newItem, $forwardPorts) {
			Section("New port forwarding") {
				ForwardedPortDetailView(currentItem: $newItem)
			}
		}
    }
}

#Preview {
	ForwardedPortNewItemView(forwardPorts: .constant([]))
}
