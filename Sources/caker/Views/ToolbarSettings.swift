//
//  ToolbarSettings.swift
//  Caker
//
//  Created by Frederic BOLTZ on 24/10/2025.
//

import SwiftUI

protocol ToolbarSettingItem<ID>: Identifiable where ID: Hashable {
	var id: ID { get }
	var title: String { get }
	var systemName: String { get }
}

struct ToolbarSettings<Item: ToolbarSettingItem<ID>, ID>: ToolbarContent {
	@Binding private var currentItem: ID

	private let placement: ToolbarItemPlacement
	private let items: [Item]
	@State private var hoveredItem: ID? = nil
	@State private var pressedItem: ID? = nil

	init(_ items: [Item], placement: ToolbarItemPlacement, currentItem: Binding<Item.ID>) {
		self._currentItem = currentItem
		self.items = items
		self.placement = placement
	}

	private func fillToolbarColor(_ item: Item.ID) -> Color {
		if item == self.pressedItem {
			return Color.secondary.opacity(0.30)
		}

		if item == self.currentItem || item == self.hoveredItem {
			return Color.secondary.opacity(0.10)
		}

		return Color.white.opacity(0.0)
	}

	private func foregroundToolbarColor(_ item: Item.ID) -> Color {
		if item == self.currentItem {
			return Color.accentColor
		}

		return Color.toolbarForegroundColor
	}

	var body: some ToolbarContent {
		ToolbarItemGroup(placement: self.placement) {
			ForEach(self.items) { item in
				let foregroundColor = self.foregroundToolbarColor(item.id)

				VStack(alignment: .center) {
					Image(systemName: item.systemName)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.foregroundStyle(foregroundColor)
						.frame(width: 24, height: 24, alignment: .center)
					Text(item.title)
						.font(.footnote)
						.foregroundStyle(foregroundColor)
				}.overlay {
					RoundedRectangle(cornerRadius: 6)
						.fill(self.fillToolbarColor(item.id))
						.frame(minWidth: 65, maxWidth: .infinity, minHeight: 45, maxHeight: 45)
				}
				.frame(minWidth: 65, maxWidth: .infinity, minHeight: 45, maxHeight: 45)
				.padding(0)
				.cornerRadius(6)
				.fixedSize(horizontal: false, vertical: true)
				.onHover { hover in
					self.hoveredItem = hover ? item.id : nil
				}
				.gesture(
					DragGesture(minimumDistance: 0)
						.onChanged({ _ in
							self.pressedItem = item.id
						})
						.onEnded({ _ in
							self.pressedItem = nil
							self.currentItem = item.id
						})
				)
			}
		}
	}
}
