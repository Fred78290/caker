//
//  SideBarView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/07/2025.
//

import SwiftUI

struct SideBarView: View {
	@Environment(\.appearsActive) var appearsActive
	let categories: [Category]
	@Binding var selectedCategory: Category

	var fillColor: Color {
		self.appearsActive ? Color.primary.opacity(0.90) : Color.secondary
	}

	private func iconColor(for category: Category) -> Color {
		switch category {
		case .virtualMachine: return .blue
		case .networks: return .green
		case .images: return .orange
		case .templates: return .purple
		}
	}

	var body: some View {
		let foregroundColor = self.fillColor

		List(self.categories, id: \.self, selection: $selectedCategory) { category in
			NavigationLink(value: category) {
				Label {
					Text(category.title)
						.foregroundStyle(foregroundColor)
						.font(.system(size: 13, weight: .medium))
				} icon: {
					ZStack {
						RoundedRectangle(cornerRadius: 7)
							.fill(iconColor(for: category).gradient)
							.frame(width: 28, height: 28)
						Image(systemName: category.iconName)
							.symbolRenderingMode(.hierarchical)
							.font(.system(size: 13, weight: .semibold))
							.foregroundStyle(.white)
					}
				}
			}
		}
		.listStyle(.sidebar)
		.navigationTitle("Explore")
	}
}

#Preview {
	SideBarView(categories: [.virtualMachine, .networks], selectedCategory: .constant(.virtualMachine))
}
