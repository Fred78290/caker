//
//  SocketsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//

import SwiftUI
import GRPCLib

struct SocketsView: View {
	@Binding var sockets: [SocketDevice]

	var body: some View {
		EditableList($sockets) { $item in
			Text(item.description)
		}
    }
}

#Preview {
	SocketsView(sockets: .constant([]))
}
