//
//  DiskAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib
import CakedLib

struct DiskAttachementNewItemView: View {
	@Binding var attachedDisks: [DiskAttachement]
	@State var newItem: DiskAttachement = .init()
	@State var syncing: Bool = false

	var body: some View {
		EditableListNewItem(newItem: $newItem, $attachedDisks) {
			Section("New disk attachement") {
				DiskAttachementDetailView(currentItem: $newItem)
			}
		}
    }
}

#Preview {
    DiskAttachementNewItemView(attachedDisks: .constant([]))
}
