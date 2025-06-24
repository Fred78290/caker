//
//  MountNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct MountNewItemView: View {
	@Binding var mounts: [DirectorySharingAttachment]
	@State var newItem: DirectorySharingAttachment = .init(source: "~".expandingTildeInPath)

	var body: some View {
		EditableListNewItem(newItem: $newItem, $mounts) {
			Text("")
		}
    }
}

#Preview {
	MountNewItemView(mounts: .constant([]))
}
