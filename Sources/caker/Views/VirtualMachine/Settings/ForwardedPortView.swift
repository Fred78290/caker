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
	@State var selectedItem: TunnelAttachement?

	var body: some View {
		EditableList($forwardPorts, selection: $selectedItem) { $item in
			ForwardedPortDetailView(currentItem: $item)
		}.onEditItem(selection: $selectedItem) {
			ForwardedPortNewItemView(forwardPorts: $forwardPorts)
		} deleteItem: {
			self.forwardPorts.removeAll {
				$0.id == selectedItem?.id
			}
		}
	}
}

#Preview {
	ForwardedPortView(forwardPorts: .constant([]))
}
