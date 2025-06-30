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
	@State var selectedItem: DirectorySharingAttachment? = nil
	@State var displaySheet: Bool = false

	var body: some View {
		EditableList($mounts, selection: $selectedItem) { $item in
			MountDetailView(currentItem: $item)
		}.onEditItem(selection: $selectedItem) {
			MountNewItemView(mounts: $mounts)
		} deleteItem: {
			self.mounts.removeAll {
				$0.id == selectedItem?.id
			}
		}
	}
}

#Preview {
	MountView(mounts: .constant([]))
}
