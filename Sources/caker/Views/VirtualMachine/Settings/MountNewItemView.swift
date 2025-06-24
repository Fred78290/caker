//
//  MountNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct MountNewItemView: View {
	@Environment(\.dismiss) var dismiss
	@Binding var mounts: [DirectorySharingAttachment]
	@State var configChanged = false

	var body: some View {
		VStack {
			Text("MountView: Add mount")
			Spacer()
			Divider()

			HStack(alignment: .bottom) {
				Spacer()
				Button("Cancel") {
					// Cancel saving and dismiss.
					dismiss()
				}
				Spacer()
				Button("Save") {
					dismiss()
				}.disabled(self.configChanged == false)
				Spacer()
			}.frame(width: 200).padding(.bottom)
		}
    }
}

#Preview {
	MountNewItemView(mounts: .constant([]))
}
