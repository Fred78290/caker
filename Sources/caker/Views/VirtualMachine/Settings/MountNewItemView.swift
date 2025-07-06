//
//  MountNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

extension [DirectorySharingAttachment] {
	func editItem(_ editItem: DirectorySharingAttachment.ID?) -> DirectorySharingAttachment {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init()
		} else {
			return .init()
		}
	}
}

struct MountNewItemView: View {
	@Binding private var mounts: [DirectorySharingAttachment]
	@State private var newItem: DirectorySharingAttachment
	private let editItem: SocketDevice.ID?

	init(_ mounts: Binding<[DirectorySharingAttachment]>, editItem: DirectorySharingAttachment.ID? = nil) {
		self._mounts = mounts
		self.editItem = editItem
		self.newItem = mounts.wrappedValue.editItem(editItem)
	}

	var body: some View {
		EditableListNewItem($mounts, currentItem: $newItem, editItem: editItem) {
			Section("New mount point") {
				MountDetailView(currentItem: $newItem, readOnly: false)
			}
		}
    }
}

#Preview {
	MountNewItemView(.constant([]))
}
