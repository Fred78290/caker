//
//  CakedServerView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 21/04/2026.
//

import SwiftUI

struct CakedServerView: View {
	@Binding var appState: AppState

	var body: some View {
		ServiceListView()
    }
}

#Preview {
	CakedServerView(appState: .constant(AppState.shared))
}
