//
//  NetworksView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import GRPCLib
import SwiftUI

struct NetworksView: View {
	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel
	@State private var selection: BridgedNetwork.ID? = nil
	@State private var disabled: Bool = false

	var body: some View {
		GeometryReader { geometry in
			EditableList($appState.networks, selection: $selection) { $item in
				NetworkDetailView(currentItem: $item).padding(5)
			}.onEditItem(selection: $selection, disabled: $disabled) { editItem in
				NetworkNewItemView($appState.networks, editItem: editItem)
			} deleteItem: {
				appState.networks.removeAll {
					$0.id == selection
				}
			}.frame(size: geometry.size)
		}
	}
}

#Preview {
	NetworksView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
