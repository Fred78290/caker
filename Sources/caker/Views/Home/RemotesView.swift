//
//  RemotesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

struct RemotesView: View {
	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel

	var body: some View {
		Text( /*@START_MENU_TOKEN@*/"Hello, World!" /*@END_MENU_TOKEN@*/)
	}
}

#Preview {
	RemotesView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
