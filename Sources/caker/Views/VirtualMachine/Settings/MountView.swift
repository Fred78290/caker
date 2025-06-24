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
	@State var displaySheet: Bool = false

	var body: some View {
		EditableList($mounts) { $item in
			Text(item.description)
		}.onAddItem(systemName: "folder.badge.plus") {
			MountNewItemView(mounts: $mounts)
		}
	}
}

#Preview {
	MountView(mounts: .constant([]))
}
