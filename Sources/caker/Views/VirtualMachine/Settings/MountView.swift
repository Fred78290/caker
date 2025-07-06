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
	@State private var selection: DirectorySharingAttachment.ID? = nil

	var body: some View {
		EditableList($mounts, selection: $selection) { $item in
			MountDetailView(currentItem: $item)
		}.onEditItem(selection: $selection) { editItem in
			MountNewItemView($mounts, editItem: editItem)
		} deleteItem: {
			self.mounts.removeAll {
				$0.id == selection
			}
		}
	}
}

#Preview {
	MountView(mounts: .constant([]))
}
