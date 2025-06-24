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
	@State var newItem: SocketDevice = .init(mode: .bind, port: 0, bind: "")

	var body: some View {
		EditableListNewItem(newItem: $newItem, $sockets) {
			Text("")
		}
    }
}

#Preview {
    SocketsNewItemView(sockets: .constant([]))
}
