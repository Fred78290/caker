//
//  MountView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct MountView: View {
	@Binding var mounts: [DirectorySharingAttachment]
	@State private var selectedItems: Set<DirectorySharingAttachment.ID> = []
	@State private var selection: DirectorySharingAttachment.ID? = nil

	var body: some View {
		EditableList($mounts, selection: $selection, selectedItems: $selectedItems) { $item in
			MountDetailView(currentItem: $item)
		}.onEditItem(selection: $selection, selectedItems: $selectedItems) {
			MountNewItemView(mounts: $mounts)
		} deleteItem: {
			selectedItems.forEach { selectedItem in
				self.mounts.removeAll {
					$0.id == selectedItem
				}
			}
		}
	}
}

#Preview {
	MountView(mounts: .constant([]))
}
