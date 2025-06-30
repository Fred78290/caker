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
	@State var selectedItem: DiskAttachement?
	@State var displaySheet: Bool = false

	var body: some View {
		EditableList($attachedDisks, selection: $selectedItem) { $item in
			DiskAttachementDetailView(currentItem: $item)
		}.onEditItem(selection: $selectedItem) {
			DiskAttachementNewItemView(attachedDisks: $attachedDisks)
		} deleteItem: {
			self.attachedDisks.removeAll {
				$0.id == selectedItem?.id
			}
		}
	}
}

#Preview {
	DiskAttachementView(attachedDisks: .constant([]))
}
