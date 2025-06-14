//
//  ForwardedPortView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import SwiftUI
import GRPCLib

struct ForwardedPortView: View {
	@Binding var forwardPorts: [TunnelAttachement]

	var body: some View {
		EditableList($forwardPorts) { $item in
			Text(item.description)
		}
    }
}

#Preview {
	ForwardedPortView(forwardPorts: .constant([]))
}
