//
//  DiskAttachementView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct DiskAttachementView: View {
	@Binding var attachedDisks: [DiskAttachement]
	@State private var selectedItems: Set<DiskAttachement.ID> = []
	@State private var selection: DiskAttachement.ID? = nil

	var body: some View {
		EditableList($attachedDisks, selection: $selection, selectedItems: $selectedItems) { $item in
			DiskAttachementDetailView(currentItem: $item)
		}.onEditItem(selection: $selection, selectedItems: $selectedItems) {
			DiskAttachementNewItemView(attachedDisks: $attachedDisks)
		} deleteItem: {
			selectedItems.forEach { selectedItem in
				self.attachedDisks.removeAll {
					$0.id == selectedItem
				}
			}
		}
	}
}

#Preview {
	DiskAttachementView(attachedDisks: .constant([]))
}
