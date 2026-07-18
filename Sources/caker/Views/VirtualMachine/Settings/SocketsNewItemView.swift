//
//  SocketsNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import GRPCLib
import SwiftUI

extension [SocketDevice] {
	func editItem(_ editItem: SocketDevice.ID?) -> SocketDevice {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init(mode: .bind, port: 0, bind: String.empty)
		} else {
			return .init(mode: .bind, port: 0, bind: String.empty)
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
		} validateItem: { item in
			if Bundle.isApplicationSandboxed && AppState.shared.connectionMode != .remote && item.bind.isEmpty == false {
				if let home = try? Utils.getHome(runMode: AppState.shared.connectionMode.runMode) {
					if (item.bind as NSString).expandingTildeInPath.starts(with: home.path(percentEncoded: false)) == false {
						return (false, String(localized: "Host path is not in the sandbox"))
					}
				}
			}
			
			if item.validate() == false {
				if item.port == -1 {
					return (false, String(localized: "Port must be defined"))
				}

				if item.bind.isEmpty {
					return (false, String(localized: "Path must be defined"))
				}

				if item.bind.count > URL.maxSocketPathLength {
					return (false, String(localized: "Path is too long"))
				}
			}
			
			return (true, nil)
		}
	}

}

#Preview {
	SocketsNewItemView(.constant([]))
}
