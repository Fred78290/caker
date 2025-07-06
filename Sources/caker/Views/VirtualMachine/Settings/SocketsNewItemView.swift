//
//  SocketsNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

extension [SocketDevice] {
	func editItem(_ editItem: SocketDevice.ID?) -> SocketDevice {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init(mode: .bind, port: 0, bind: "")
		} else {
			return .init(mode: .bind, port: 0, bind: "")
		}
	}
}

struct SocketsNewItemView: View {
	@Binding private var sockets: [SocketDevice]
	@State private var newItem: SocketDevice
	private let editItem: SocketDevice.ID?

	init(_ sockets: Binding<[SocketDevice]>, editItem: SocketDevice.ID? = nil) {
		_sockets = sockets
		self.editItem = editItem
		self.newItem = sockets.wrappedValue.editItem(editItem)
	}

	var body: some View {
		EditableListNewItem($sockets, currentItem: $newItem, editItem: editItem) {
			Section("New socket endpoint") {
				SocketsDetailView(currentItem: $newItem, readOnly: false)
			}
		}
	}

}

#Preview {
    SocketsNewItemView(.constant([]))
}
