//
//  ForwardedPortView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI
import CakeAgentLib

struct ForwardedPortView: View {
	@Binding var forwardPorts: [TunnelAttachement]
	@Binding var disabled: Bool
	@State private var selection: TunnelAttachement.ID? = nil

	var body: some View {
		GeometryReader { geometry in
			EditableList($forwardPorts, selection: $selection) { $item in
				ForwardedPortDetailView(currentItem: $item)
			}.onEditItem("Socket path must be in the sandbox folder and must be less than 103 characters to be usable with caked command", selection: $selection, disabled: $disabled) {
				ForwardedPortNewItemView($forwardPorts, editItem: $0)
			} deleteItem: {
				self.forwardPorts.removeAll {
					$0.id == selection
				}
			}.frame(height: geometry.size.height)
		}
	}
}

#Preview {
	ForwardedPortView(forwardPorts: .constant([]), disabled: .constant(false))
}
