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

	init(onAddItem: @escaping () -> SomeView, onDeleteItem: EditableListDeleteItemAction?) {
		self.addItemClosure = onAddItem
		self.deleteItem = onDeleteItem
		self._selectedItems = .constant([])
	}

	init(selection: Binding<Set<Element>>, onAddItem: @escaping () -> SomeView, onDeleteItem: EditableListDeleteItemAction?) {
		self.addItemClosure = onAddItem
		self.deleteItem = onDeleteItem
		self._selectedItems = selection
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

struct EditableListCell<Data: TotalCollection, Content: View>: View where Data.Element: Hashable & Identifiable {
	@State private var isSelected: Bool = false
	@Binding private var selectedItems: Set<Data.Element.ID>
	@Binding private var item: Data.Element

	private var content: (Binding<Data.Element>) -> Content

	init(item: Binding<Data.Element>, selection: Binding<Set<Data.Element.ID>>, content: @escaping (Binding<Data.Element>) -> Content) {
		_selectedItems = selection
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

struct EditableList<Data: TotalCollection, Content: View>: View where Data.Element: Hashable & Identifiable {
	@Binding var data: Data
	@Binding private var selectedItems: Set<Data.Element.ID>
	private var content: (Binding<Data.Element>) -> Content

	init(_ data: Binding<Data>, selection: Binding<Set<Data.Element.ID>>, content: @escaping (Binding<Data.Element>) -> Content) {
		self._data = data
		self._selectedItems = selection
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
				List {
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
		EditableListCell(item: <#T##Hashable & Identifiable#>, selection: <#T##Binding<Set<Hashable>>#>, content: <#T##(Binding<Hashable & Identifiable>) -> View#>)
		HStack(alignment: .center) {
			@Bindable var isSelected: Bool = false

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
			self.content(item)
		}
	}

	func deleteItem(item: Binding<Data.Element>) {
		self.data.removeAll {
			$0.id == item.wrappedValue.id
		}
	}
}

typealias EditableListDeleteItemAction = () -> Void

extension View {
	func onEditItem<Element: Hashable>(selection: Binding<Set<Element>>, _ action: @escaping () -> some View, deleteItem: EditableListDeleteItemAction? = nil) -> some View {
		modifier(OnEditItemListViewModifier(selection: selection, onAddItem: action, onDeleteItem: deleteItem))
	}
}
