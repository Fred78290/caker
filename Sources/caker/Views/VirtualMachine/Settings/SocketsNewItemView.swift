//
//  SocketsNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct SocketsNewItemView: View {
	@Binding var sockets: [SocketDevice]

	var body: some View {
		VStack {
			Text("SocketsView: Add socket")
		}
    }
}

#Preview {
    SocketsNewItemView(sockets: .constant([]))
}
