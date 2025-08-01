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
	@Binding var disabled: Bool
	@State private var selectedItems: Set<DiskAttachement.ID> = []
	@State private var selection: DiskAttachement.ID? = nil

	var body: some View {
		GeometryReader { geometry in
			EditableList($attachedDisks, selection: $selection) { $item in
				DiskAttachementDetailView(currentItem: $item)
			}.onEditItem(selection: $selection, disabled: $disabled) { editItem in
				DiskAttachementNewItemView($attachedDisks, editItem: editItem)
			} deleteItem: {
				self.attachedDisks.removeAll {
					$0.id == selection
				}
			}.frame(height: geometry.size.height)
		}
	}
}

#Preview {
	DiskAttachementView(attachedDisks: .constant([]), disabled: .constant(false))
}
