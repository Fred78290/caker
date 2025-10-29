//
//  SideBarView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/07/2025.
//

import SwiftUI

struct SideBarView: View {
	@Binding var navigationModel: NavigationModel

	var body: some View {
		List(selection: $navigationModel.selectedCategory) {
			ForEach(navigationModel.categories) { category in
				NavigationLink(value: category) {
					Label(category.title, systemImage: category.iconName)
				}
			}
		}
		.listStyle(.sidebar)
		.navigationTitle("Explore")
	}
}

#Preview {
	SideBarView(navigationModel: .constant(.init()))
}
