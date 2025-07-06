//
//  DiskAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib
import CakedLib

extension [DiskAttachement] {
	func editItem(_ editItem: DiskAttachement.ID?) -> DiskAttachement {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init()
		} else {
			return .init()
		}
	}
}

struct DiskAttachementNewItemView: View {
	@Binding private var attachedDisks: [DiskAttachement]
	@State private var newItem: DiskAttachement
	@State private var syncing: Bool = false

	private let editItem: DiskAttachement.ID?

	init(_ attachedDisks: Binding<[DiskAttachement]>, editItem: DiskAttachement.ID? = nil) {
		self._attachedDisks = attachedDisks
		self.editItem = editItem
		self.newItem = attachedDisks.wrappedValue.editItem(editItem)
	}

	var body: some View {
		EditableListNewItem($attachedDisks, currentItem: $newItem, editItem: editItem) {
			Section("New disk attachement") {
				DiskAttachementDetailView(currentItem: $newItem, readOnly: false)
			}
		}
    }
}

#Preview {
    DiskAttachementNewItemView(.constant([]))
}
