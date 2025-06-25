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
	@State var displaySheet: Bool = false

	var body: some View {
		EditableList($attachedDisks) { $item in
			Section {
				DiskAttachementDetailView(currentItem: $item)
			}
		}.onAddItem(systemName: "externaldrive.badge.plus") {
			DiskAttachementNewItemView(attachedDisks: $attachedDisks)
		}
	}
}

#Preview {
	DiskAttachementView(attachedDisks: .constant([]))
}
