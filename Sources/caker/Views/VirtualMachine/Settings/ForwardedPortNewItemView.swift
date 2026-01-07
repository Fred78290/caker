//
//  ForwardedPortNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import CakeAgentLib
import GRPCLib
import NIOPortForwarding
import SwiftUI
import CakeAgentLib

extension [TunnelAttachement] {
	func editItem(_ editItem: TunnelAttachement.ID?) -> TunnelAttachement {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init()
		} else {
			return .init()
		}
	}
}

struct ForwardedPortNewItemView: View {
	@Binding private var forwardPorts: [TunnelAttachement]
	@State private var newItem: TunnelAttachement
	private let editItem: TunnelAttachement.ID?

	init(_ forwardPorts: Binding<[TunnelAttachement]>, editItem: TunnelAttachement.ID? = nil) {
		self._forwardPorts = forwardPorts
		self.editItem = editItem
		self.newItem = forwardPorts.wrappedValue.editItem(editItem)
	}

	var body: some View {
		EditableListNewItem($forwardPorts, currentItem: $newItem, editItem: editItem) {
			Section("New port forwarding") {
				ForwardedPortDetailView(currentItem: $newItem, readOnly: false)
			}
		}
	}
}

#Preview {
	ForwardedPortNewItemView(.constant([]))
}
