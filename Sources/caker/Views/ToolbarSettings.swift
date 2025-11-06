//
//  ToolbarSettings.swift
//  Caker
//
//  Created by Frederic BOLTZ on 24/10/2025.
//

import SwiftUI

protocol ToolbarSettingItem<ID>: Identifiable where ID: Hashable {
	var title: String { get }
	var systemImage: String { get }
}

struct ToolbarSettingLabelStyle: LabelStyle {
	enum State {
		case none
		case pressed
		case hovered
		case selected
		case hoveredAndSelected
		case pressedAndSelected
	}

	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.appearsActive) private var appearsActive
	private var state: State = .none

	init(_ state: State) {
		self.state = state
	}

	private var foregroundColor: Color {
		if case .selected = state {
			return appearsActive ? .accentColor : .secondary
		}
		
		if case .hoveredAndSelected = state {
			return .accentColor
		}

		if case .pressedAndSelected = state {
			return .accentColor
		}

		return Color.gray
	}

	private var fillColor: Color {
		if self.colorScheme == .dark {
			switch state {
			case .pressed, .pressedAndSelected:
				return Color.white.opacity(0.30)
			case .hovered:
				return Color.white.opacity(0.10)
			case .hoveredAndSelected:
				return Color.white.opacity(0.40)
			case .selected:
				return Color.white.opacity(0.10)
			default:
				return Color.white.opacity(0.0)
			}
		} else {
			switch state {
			case .pressed, .pressedAndSelected:
				return Color.secondary.opacity(0.30)
			case .hovered:
				return Color.secondary.opacity(0.10)
			case .hoveredAndSelected:
				return Color.secondary.opacity(0.40)
			case .selected:
				return Color.secondary.opacity(0.10)
			default:
				return Color.secondary.opacity(0.0)
			}
		}
	}

#if compiler(>=6.2)
	@available(macOS 26.0, *)
	private var glassEffect: Glass {
		guard self.appearsActive else { return .identity }
		switch state {
		case .selected, .pressed, .pressedAndSelected, .hoveredAndSelected, .hovered:
			return .regular.interactive(true).tint(self.fillColor)
		default:
			return .identity
		}
	}
#endif

	func makeBody(configuration: Configuration) -> some View {
		let content: () -> some View = {
			VStack(alignment: .center, spacing: 2) {
				configuration.icon
					.aspectRatio(contentMode: .fit)
					.foregroundStyle(self.foregroundColor)
					.frame(width: 24, height: 24, alignment: .center)

				configuration.title
					.foregroundStyle(appearsActive ? self.foregroundColor : .gray.opacity(0.50))
					.font(.subheadline)
			}.overlay {
				RoundedRectangle(cornerRadius: 6)
					.fill(self.fillColor)
					.frame(minWidth: 65, maxWidth: .infinity, minHeight: 45, maxHeight: 45)
			}
			.frame(minWidth: 65, maxWidth: .infinity, minHeight: 45, maxHeight: 45)
			.padding(0)
			.cornerRadius(6)
			.fixedSize(horizontal: false, vertical: true)
		}

#if compiler(>=6.2)
		if #available(macOS 26.0, *) {
			GlassEffectContainer {
				VStack(alignment: .center, spacing: 2) {
					configuration.icon
						.aspectRatio(contentMode: .fit)
						.foregroundStyle(self.foregroundColor)
						.frame(width: 24, height: 24, alignment: .center)

					configuration.title
						.foregroundStyle(appearsActive ? self.foregroundColor : .gray.opacity(0.50))
						.font(.subheadline)
				}
				.frame(minWidth: 65, maxWidth: .infinity, minHeight: 45, maxHeight: 45)
				.padding(0)
				.cornerRadius(6)
				.fixedSize(horizontal: false, vertical: true)
					.glassEffect(self.glassEffect, in: RoundedRectangle(cornerRadius: 6))
			}
		} else {
			content()
		}
#else
		content()
#endif
	}
}

extension ToolbarContent {
	func backgroundVisibility(_ visible: Bool) -> some ToolbarContent {
#if compiler(>=6.2)
		if #available(macOS 26.0, *) {
			return self.sharedBackgroundVisibility(visible ? .visible : .hidden)
		} else {
			return self
		}
#else
		return self
#endif
	}
}

/// A reusable ToolbarContent that renders a collection of toolbar setting items
struct ToolbarSettings<Item: ToolbarSettingItem<ID>, ID>: ToolbarContent where Item.ID == ID {
	@Environment(\.appearsActive) var appearsActive

	private let items: [Item]
	private let maps: [ID:Item]
	private let placement: ToolbarItemPlacement
	private let id: String
	@State var hoveredItem: ID?
	@State var pressedItem: ID?
	@Binding var selectedItem: ID
	
	init(_ selection: Binding<ID>, items: [Item], placement: ToolbarItemPlacement = .automatic) {
		self.init(selection, id: UUID().uuidString, items: items, placement: placement)
	}
	
	init(_ selection: Binding<ID>, id: String, items: [Item], placement: ToolbarItemPlacement = .automatic) {
		self.items = items
		self.id = id
		self.placement = placement
		self._selectedItem = selection
		self.maps = items.reduce(into: [:]) { (result, item) in
			result[item.id] = item
		}
	}
	
	func buttonState(for id: ID) -> ToolbarSettingLabelStyle.State {
		if self.selectedItem == id && self.pressedItem == id {
			return .pressedAndSelected
		} else if self.selectedItem == id && self.hoveredItem == id {
			return .hoveredAndSelected
		} else if self.pressedItem == id {
			return .pressed
		} else if self.hoveredItem == id {
			return .hovered
		} else if self.selectedItem == id {
			return .selected
		} else {
			return .none
		}
	}
	
	var body: some ToolbarContent {
		ToolbarItem(id: id, placement: self.placement) {
			ControlGroup {
				ForEach(self.items) { item in
					Label{
						Text(item.title)
					} icon: {
						Image(systemName: item.systemImage).resizable()
					}
					.labelStyle(ToolbarSettingLabelStyle(self.buttonState(for: item.id)))
					.onContinuousHover { phase in
						if case .active = phase {
							self.hoveredItem = item.id
						} else {
							self.hoveredItem = nil
						}
					}
					.gesture(
						DragGesture(minimumDistance: 0)
							.onChanged({ _ in
								self.pressedItem = item.id
							})
							.onEnded({ _ in
								self.pressedItem = nil
								self.selectedItem = item.id
							})
					)
				}
			}
			.padding(0)
			.navigationTitle(self.maps[self.selectedItem]?.title ?? "")
			//.onAppear {
			//   if let window = NSApp.mainWindow {
				   // Set the desired position of the window
			//	   window.setFrameOrigin(NSPoint(x: desiredX, y: desiredY))
			//   }
			//}
		}.backgroundVisibility(false)
	}
}
