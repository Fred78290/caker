//
//  ForwardedPortView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct ForwardedPortView: View {
	@Binding var forwardPorts: [TunnelAttachement]
	@State private var selection: TunnelAttachement.ID? = nil

	var body: some View {
		EditableList($forwardPorts, selection: $selection) { $item in
			ForwardedPortDetailView(currentItem: $item)
		}.onEditItem(selection: $selection) {
			ForwardedPortNewItemView($forwardPorts, editItem: $0)
		} deleteItem: {
			self.forwardPorts.removeAll {
				$0.id == selection
			}
		}
	}
}

#Preview {
	ForwardedPortView(forwardPorts: .constant([]))
}
