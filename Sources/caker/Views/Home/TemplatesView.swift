//
//  TemplatesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

struct TemplatesView: View {
	@Binding var appState: AppState
	@Binding var navigationModel: NavigationModel

	var body: some View {
		Text( /*@START_MENU_TOKEN@*/"Hello, World!" /*@END_MENU_TOKEN@*/)
	}
}

#Preview {
	TemplatesView(appState: .constant(.init()), navigationModel: .constant(.init()))
}
