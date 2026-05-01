//
//  RemotesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import SwiftUI

struct RemotesView: View {
	@StateObject var navigationModel: NavigationModel

	var body: some View {
		Text( /*@START_MENU_TOKEN@*/"Hello, World!" /*@END_MENU_TOKEN@*/)
	}
}

#Preview {
	RemotesView(navigationModel: .init(selectedCategory: .templates))
}
