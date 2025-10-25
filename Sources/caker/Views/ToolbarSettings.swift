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
		if item == self.currentItem || item == self.hoveredItem {
			return Color.toolbarFillColor
		}

		return Color.red.opacity(0.0)
	}

	private func foregroundToolbarColor(_ item: Item.ID) -> Color {
		if item == self.pressedItem && item == self.currentItem {
			return Color.accentColor.withBrightnessValue(20)
		}

		if item == self.pressedItem {
			return Color.toolbarPressedColor
		}
		
		if item == self.currentItem {
			return Color.accentColor
		}

		return Color.toolbarForegroundColor
	}

	var body: some ToolbarContent {
		ToolbarItemGroup(placement: self.placement) {
			ForEach(self.items) { item in
				let foregroundColor = self.foregroundToolbarColor(item.id)

				RoundedRectangle(cornerRadius: 10)
					.fill(self.fillToolbarColor(item.id))
				.overlay(
					VStack {
						Image(systemName: item.systemName)
							.resizable()
							.aspectRatio(contentMode: .fit)
							.foregroundStyle(foregroundColor)
							.frame(width: 24, height: 24, alignment: .center)

						Text(item.title)
							.font(.footnote)
							.foregroundStyle(foregroundColor)
					}
					.background(Color.red.opacity(0.0))
				)
				.frame(minWidth: 65, maxWidth: .infinity, minHeight: 65)
				.padding(0)
				.foregroundColor(foregroundColor)
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
