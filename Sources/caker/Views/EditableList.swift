//
//  EditableList.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//
import SwiftUI

typealias TotalCollection = RandomAccessCollection & MutableCollection & RangeReplaceableCollection & Hashable

struct OnEditItemListViewModifier<Element: Hashable, SomeView: View>: ViewModifier {
	private var addItemClosure: () -> SomeView
	private var deleteItem: EditableListDeleteItemAction?

	@Environment(\.dismiss) private var dismiss
	@State private var displayAddItemView: Bool = false
	@Binding private var selectedItems: Set<Element>
	@State private var selection: Element? = nil

	init(onAddItem: @escaping () -> SomeView, onDeleteItem: EditableListDeleteItemAction?) {
		self.addItemClosure = onAddItem
		self.deleteItem = onDeleteItem
		self._selectedItems = .constant([])
		//self._selection = .constant(nil)
	}

	init(selection: Binding<Element?>, selectedItems: Binding<Set<Element>>, onAddItem: @escaping () -> SomeView, onDeleteItem: EditableListDeleteItemAction?) {
		self.addItemClosure = onAddItem
		self.deleteItem = onDeleteItem
		//self._selection = selection
		self._selectedItems = selectedItems
	}

	func body(content: Content) -> some View {
		VStack {
			content
			Spacer()
			HStack(alignment: .center) {
				Button(action: {
					displayAddItemView = true
				}) {
					Image(systemName: "plus")
				}.buttonStyle(.borderless).font(.headline)
				
				if let deleteItem = deleteItem {
					Button(action: {
						deleteItem()
					}) {
						Image(systemName: "minus")
					}.buttonStyle(.borderless).font(.headline).disabled(selectedItems.isEmpty)
				}
				Spacer()
			}
		}.sheet(isPresented: $displayAddItemView, onDismiss: nil) {
			HStack {
				self.addItemClosure()
			}.frame(maxWidth: 800).padding()
		}
	}
}

struct EditableList<Data: TotalCollection, Content: View>: View where Data.Element: Hashable & Identifiable {
	@Binding var data: Data
	@Binding private var selectedItems: Set<Data.Element.ID>
	private var content: (Binding<Data.Element>) -> Content
	@Binding private var selection: Data.Element.ID?

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

		var body : some View {
			HStack(alignment: .center) {
				Toggle("Select", isOn: $isSelected)
					.toggleStyle(.checkbox)
					.labelsHidden()
					.onChange(of: isSelected) { newValue in
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

	init(_ data: Binding<Data>, selection: Binding<Data.Element.ID?>, selectedItems: Binding<Set<Data.Element.ID>>, content: @escaping (Binding<Data.Element>) -> Content) {
		self._data = data
		self._selectedItems = selectedItems
		self._selection = selection
		self.content = content
	}

	var body: some View {
		VStack {
			if data.isEmpty {
				if #available(macOS 14, *) {
					ContentUnavailableView(
						"List empty",
						systemImage: "tray"
					)
				} else {
					VStack(alignment: .center) {
						Image(systemName: "tray").resizable().scaledToFit().frame(width: 48, height: 48).foregroundStyle(.gray)
						Text("List empty").font(.largeTitle).foregroundStyle(.gray).multilineTextAlignment(.center)
					}
				}
			} else {
				List/*(selection: $selection)*/ {
					ForEach($data, content: listItem)
						.onMove { indexSet, offset in
							data.move(fromOffsets: indexSet, toOffset: offset)
						}
						.onDelete { indexSet in
							data.remove(atOffsets: indexSet)
						}
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				.listStyle(.bordered(alternatesRowBackgrounds: true))
				.clipShape(RoundedRectangle(cornerRadius: 6))
				.overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(CGColor.init(gray: 0.8, alpha: 0.4)), lineWidth: 1))
			}
		}
	}

	func listItem(item: Binding<Data.Element>) -> some View {
		EditableListCell(item: item, selectedItems: $selectedItems, content: self.content)
	}

	func deleteItem(item: Binding<Data.Element>) {
		self.data.removeAll {
			$0.id == item.wrappedValue.id
		}
	}
}

typealias EditableListDeleteItemAction = () -> Void

extension View {
	func onEditItem<Element: Hashable>(selection: Binding<Element?>, selectedItems: Binding<Set<Element>>, _ action: @escaping () -> some View, deleteItem: EditableListDeleteItemAction? = nil) -> some View {
		modifier(OnEditItemListViewModifier(selection: selection, selectedItems: selectedItems, onAddItem: action, onDeleteItem: deleteItem))
	}
}
