//
//  MountNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import GRPCLib
import SwiftUI

extension MountPoints {
	func editItem(_ editItem: MountPoint.ID?) -> MountPoint {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init()
		} else {
			return .init()
		}
	}
}

struct MountNewItemView: View {
	@Binding private var mounts: MountPoints
	@State private var newItem: MountPoint
	private let editItem: MountPoint.ID?

	init(_ mounts: Binding<MountPoints>, editItem: MountPoint.ID? = nil) {
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
