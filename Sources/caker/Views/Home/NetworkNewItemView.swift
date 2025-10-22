//
//  NetworkNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/10/2025.
//

import GRPCLib
import SwiftUI

extension [BridgedNetwork] {
	func editItem(_ editItem: BridgedNetwork.ID?) -> BridgedNetwork {
		if let editItem = editItem {
			return self.first(where: { $0.id == editItem }) ?? .init(name: "", mode: .shared, description: "", gateway: "", interfaceID: UUID().uuidString, endpoint: "")
		} else {
			return .init(name: "", mode: .shared, description: "", gateway: "", interfaceID: UUID().uuidString, endpoint: "")
		}
	}
}

struct NetworkNewItemView: View {
	@Binding var networks: [BridgedNetwork]
	@State private var newItem: BridgedNetwork
	private let editItem: BridgeAttachement.ID?

	init(_ networks: Binding<[BridgedNetwork]>, editItem: BridgedNetwork.ID? = nil) {
		self._networks = networks
		self.editItem = editItem
		self.newItem = networks.wrappedValue.editItem(editItem)
	}

	var body: some View {
    }
}

#Preview {
	NetworkNewItemView(.constant([.init(name: "nat", mode: .nat, description: "NAT shared network", gateway: "", interfaceID: "nat", endpoint: "")]))
}
