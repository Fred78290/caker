//
//  ForwardedPortNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct ForwardedPortNewItemView: View {
	@Environment(\.dismiss) var dismiss
	@Binding var forwardPorts: [TunnelAttachement]
	@State var configChanged = false

	var body: some View {
		VStack {
			Text("ForwardedPortView: Add port")
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
	ForwardedPortNewItemView(forwardPorts: .constant([]))
}
