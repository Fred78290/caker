//
//  ForwardedPortView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import GRPCLib
import SwiftUI

struct ForwardedPortView: View {
	@Binding var forwardPorts: [TunnelAttachement]
	@State var displaySheet: Bool = false

	var body: some View {
		EditableList($forwardPorts) { $item in
			Text(item.description)
		}.onAddItem(systemName: "link.badge.plus") {
			displaySheet = true
		}.sheet(isPresented: $displaySheet) {
			Text("ForwardedPortView: Add port")
		}
	}
}

#Preview {
	ForwardedPortView(forwardPorts: .constant([]))
}
