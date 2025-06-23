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

	var body: some View {
		EditableList($attachedDisks) { $item in
			Text(item.description)
		}.onAddItem(systemName: "externaldrive.badge.plus") {
			print("DiskAttachementView: Add disk")
		}
	}
}

#Preview {
	DiskAttachementView(attachedDisks: .constant([]))
}
