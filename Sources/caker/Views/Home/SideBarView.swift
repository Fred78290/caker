//
//  SideBarView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/07/2025.
//

import SwiftUI

struct SideBarView: View {
	@Environment(\.appearsActive) var appearsActive
	@Binding var navigationModel: NavigationModel

	var fillColor: Color {
		self.appearsActive ? Color.primary.opacity(0.80) : Color.secondary
	}

	var body: some View {
		let foregroundColor = self.fillColor

		List(selection: $navigationModel.selectedCategory) {
			ForEach(navigationModel.categories) { category in
				NavigationLink(value: category) {
					Label {
						Text(category.title)
							.foregroundStyle(foregroundColor)
							.font(.system(size: 14, weight: .regular, design: .default))
							.padding(4)
					} icon: {
						Image(systemName: category.iconName)
							.symbolRenderingMode(.hierarchical)
							.font(.system(size: 14, weight: .regular, design: .default))
							.foregroundStyle(Color.primary.opacity(0.80))
							.padding(4)
					}
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
