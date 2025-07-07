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

	init(selection: Binding<Element?>, onEditItem: @escaping (Element?) -> SomeView, onDeleteItem: DeleteItemAction?) {
		self.editItemClosure = onEditItem
		self.deleteItem = onDeleteItem
		self._selection = selection
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
					}.buttonStyle(.borderless).font(.headline).disabled(self.selection == nil)
				}

				Button(action: {
					displayEditItemView = true
				}) {
					Image(systemName: "pencil")
				}.buttonStyle(.borderless).font(.headline).disabled(self.selection == nil)

				Spacer()
			}
		}.sheet(isPresented: $displayAddItemView, onDismiss: { displayAddItemView = false }) {
			Group {
				self.editItemClosure(nil)
			}.frame(width: 500).padding()
		}.sheet(isPresented: $displayEditItemView, onDismiss: { displayEditItemView = false }) {
			Group {
				self.editItemClosure(selection)
			}.frame(width: 500).padding()
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

	init(_ data: Binding<Data>, selection: Binding<Data.Element.ID?>, moveable: Binding<Bool> = .constant(true), content: @escaping (Binding<Data.Element>) -> Content) {
		self._data = data
		self._selection = selection
		self._moveable = moveable
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
				List(selection: $selection) {
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
	func onEditItem<Element: Hashable>(selection: Binding<Element?>, _ action: @escaping (Element?) -> some View, deleteItem: DeleteItemAction? = nil) -> some View {
		modifier(OnEditItemListViewModifier(selection: selection, onEditItem: action, onDeleteItem: deleteItem))
	}
}
