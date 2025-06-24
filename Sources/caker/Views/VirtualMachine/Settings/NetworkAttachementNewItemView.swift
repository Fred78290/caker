//
//  NetworkAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct NetworkAttachementNewItemView: View {
	@Environment(\.dismiss) var dismiss
	@Binding var networks: [BridgeAttachement]
	@State var configChanged = false

	var body: some View {
		VStack {
			Text("NetworkAttachementView: Add network")
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
    NetworkAttachementNewItemView(networks: .constant([]))
}
