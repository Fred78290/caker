//
//  MountView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct MountView: View {
	@Binding var mounts: DirectorySharingAttachments
	@Binding var disabled: Bool
	@State private var selection: DirectorySharingAttachment.ID? = nil

	var body: some View {
		GeometryReader { geometry in
			EditableList($mounts, selection: $selection) { $item in
				MountDetailView(currentItem: $item)
			}.onEditItem(selection: $selection, disabled: $disabled) { editItem in
				MountNewItemView($mounts, editItem: editItem)
			} deleteItem: {
				self.mounts.removeAll {
					$0.id == selection
				}
			}.frame(height: geometry.size.height)
		}
	}
}

#Preview {
	MountView(mounts: .constant([]), disabled: .constant(false))
}
