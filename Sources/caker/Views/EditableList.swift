//
//  EditableList.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//
import SwiftUI

typealias TotalCollection = RandomAccessCollection & MutableCollection & RangeReplaceableCollection & Hashable
typealias DeleteItemAction = () -> Void

struct OnEditItemListViewModifier<Element: Hashable, SomeView: View>: ViewModifier {
	private var editItemClosure: (Element?) -> SomeView
	private var deleteItem: DeleteItemAction?

	@Environment(\.dismiss) private var dismiss
	@State private var displayAddItemView: Bool = false
	@State private var displayEditItemView: Bool = false
	@Binding private var selection: Element?
	@Binding private var disabled: Bool

	private let advisory: LocalizedStringKey?

	init(_ advisory: LocalizedStringKey? = nil, selection: Binding<Element?>, disabled: Binding<Bool>, onEditItem: @escaping (Element?) -> SomeView, onDeleteItem: DeleteItemAction?) {
		self.editItemClosure = onEditItem
		self.deleteItem = onDeleteItem
		self.advisory = advisory
		self._selection = selection
		self._disabled = disabled
	}

	func body(content: Content) -> some View {
		VStack(spacing: 0) {
			if let advisory = advisory, Bundle.isApplicationSandboxed {
				Text(advisory)
					.font(.caption)
					.foregroundStyle(.secondary)
				Spacer()
			}

			content
			Divider()
			HStack(spacing: 0) {
				Button(action: {
					displayAddItemView = true
				}) {
					Image(systemName: "plus")
						.frame(width: 28, height: 22)
				}
				.buttonStyle(.borderless)
				.font(.system(size: 13))
				.disabled(self.disabled)

				if let deleteItem = deleteItem {
					Divider().frame(height: 14)
					Button(action: {
						deleteItem()
					}) {
						Image(systemName: "minus")
							.frame(width: 28, height: 22)
					}
					.buttonStyle(.borderless)
					.font(.system(size: 13))
					.disabled(self.selection == nil || self.disabled)
				}

				Divider().frame(height: 14)

				Button(action: {
					displayEditItemView = true
				}) {
					Image(systemName: "pencil")
						.frame(width: 28, height: 22)
				}
				.buttonStyle(.borderless)
				.font(.system(size: 13))
				.disabled(self.selection == nil || self.disabled)

				Spacer()
			}
			.padding(.horizontal, 4)
			.padding(.vertical, 3)
			.background(Color(NSColor.controlBackgroundColor))
		}
		.sheet(isPresented: $displayAddItemView, onDismiss: { displayAddItemView = false }) {
			Group {
				self.editItemClosure(nil)
			}.frame(width: 550).padding()
		}.sheet(isPresented: $displayEditItemView, onDismiss: { displayEditItemView = false }) {
			Group {
				self.editItemClosure(selection)
			}.frame(width: 550).padding()
		}
	}
}

struct EditableList<Data: TotalCollection, Content: View>: View where Data.Element: Hashable & Identifiable {
	@Binding private var data: Data
	@Binding private var selection: Data.Element.ID?
	@Binding private var moveable: Bool

	private var content: (Binding<Data.Element>) -> Content

	struct EditableListCell: View {
		@State private var isSelected: Bool = false
		@Binding private var selectedItems: Set<Data.Element.ID>
		@Binding private var item: Data.Element

		private var content: (Binding<Data.Element>) -> Content

		init(item: Binding<Data.Element>, selectedItems: Binding<Set<Data.Element.ID>>, content: @escaping (Binding<Data.Element>) -> Content) {
			_selectedItems = selectedItems
			_item = item
			self.content = content
		}

		var body: some View {
			HStack(alignment: .center) {
				Toggle("Select", isOn: $isSelected)
					.toggleStyle(.checkbox)
					.labelsHidden()
					.onChange(of: isSelected) { _, newValue in
						if newValue {
							selectedItems.insert(item.id)
						} else {
							selectedItems.remove(item.id)
						}
					}

				self.content($item)
			}
		}
	}

	init(_ data: Binding<Data>, selection: Binding<Data.Element.ID?>, moveable: Binding<Bool> = .constant(true), content: @escaping (Binding<Data.Element>) -> Content) {
		self._data = data
		self._selection = selection
		self._moveable = moveable
		self.content = content
	}

	var body: some View {
		GeometryReader { geom in
			ScrollView {
				VStack(alignment: .center) {
					if data.isEmpty {
						VStack(alignment: .center) {
							ContentUnavailableView("List empty", systemImage: "tray")
						}.frame(width: geom.size.width)
					} else {
						List(selection: $selection) {
							ForEach($data, content: listItem)
								.onMove { indexSet, offset in
									data.move(fromOffsets: indexSet, toOffset: offset)
								}
								.onDelete { indexSet in
									data.remove(atOffsets: indexSet)
								}
						}
						.frame(height: geom.size.height)
						.alternatingRowBackgrounds()
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(CGColor.init(gray: 0.8, alpha: 0.4)), lineWidth: 1))
					}
				}
			}.frame(height: geom.size.height)
		}
	}

	func listItem(item: Binding<Data.Element>) -> some View {
		self.content(item)
		// EditableListCell(item: item, content: self.content)
	}

	func deleteItem(item: Binding<Data.Element>) {
		self.data.removeAll {
			$0.id == item.wrappedValue.id
		}
	}
}

extension View {
	func onEditItem<Element: Hashable>(_ advisory: LocalizedStringKey? = nil, selection: Binding<Element?>, disabled: Binding<Bool>, @ViewBuilder _ action: @escaping (Element?) -> some View, deleteItem: DeleteItemAction? = nil) -> some View {
		modifier(OnEditItemListViewModifier(advisory, selection: selection, disabled: disabled, onEditItem: action, onDeleteItem: deleteItem))
	}
}
