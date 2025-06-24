//
//  DiskAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct DiskAttachementNewItemView: View {
	@Binding var attachedDisks: [DiskAttachement]
	@State var newItem: DiskAttachement = .init()

	var body: some View {
		EditableListNewItem(newItem: $newItem, $attachedDisks) {
			Text("")
		}
    }
}

#Preview {
    DiskAttachementNewItemView(attachedDisks: .constant([]))
}
