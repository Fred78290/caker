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

	var body: some View {
		EditableList($mounts) { $item in
			Text(item.description)
		}.onAddItem(systemName: "folder.badge.plus") {
			print("MountView: Add mount")
		}
	}
}

#Preview {
	MountView(mounts: .constant([]))
}
