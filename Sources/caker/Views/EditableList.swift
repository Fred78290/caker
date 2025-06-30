//
//  EditableList.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//
import SwiftUI

struct OnEditItemListViewModifier<Element: Identifiable, SomeView: View>: ViewModifier {

	private var addItemClosure: () -> SomeView
	private var deleteItem: EditableListDeleteItemAction?
	@Environment(\.dismiss) var dismiss
	@State var displayAddItemView: Bool = false
	@Binding var selection: Element?

	init(onAddItem: @escaping () -> SomeView, onDeleteItem: EditableListDeleteItemAction?) {
		self.addItemClosure = onAddItem
		self.deleteItem = onDeleteItem
		self._selection = .constant(nil)
	}

	init(selection: Binding<Element?>?, onAddItem: @escaping () -> SomeView, onDeleteItem: EditableListDeleteItemAction?) {
		self.addItemClosure = onAddItem
		self.deleteItem = onDeleteItem
		self._selection = selection ?? .constant(nil)
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
					}.buttonStyle(.borderless).font(.headline).disabled(selection == nil)
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

struct EditableList<Data: RandomAccessCollection & MutableCollection & RangeReplaceableCollection & Hashable, Content: View>: View where Data.Element: Hashable & Identifiable {
	@Binding var data: Data
	@Binding var selection: Data.Element?
	@State private var selectedItem: Data.Element.ID?
	private var content: (Binding<Data.Element>) -> Content

	init(_ data: Binding<Data>, selection: Binding<Data.Element?>, content: @escaping (Binding<Data.Element>) -> Content) {
		self._data = data
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
				List(selection: $selectedItem) {
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
		}.onChange(of: selectedItem) { selectedItem in
			self.selection = self.data.first(where: { $0.id == selectedItem })
		}
	}

	func listItem(item: Binding<Data.Element>) -> some View {
		HStack {
			self.content(item)
		}.clipShape(RoundedRectangle(cornerRadius: 4))
	}

	func deleteItem(item: Binding<Data.Element>) {
		self.data.removeAll {
			$0.id == item.wrappedValue.id
		}
	}
}

typealias EditableListDeleteItemAction = () -> Void

extension View {
	func onEditItem<Element: Identifiable>(selection: Binding<Element?>? = nil, _ action: @escaping () -> some View, deleteItem: EditableListDeleteItemAction? = nil) -> some View {
		modifier(OnEditItemListViewModifier(selection: selection, onAddItem: action, onDeleteItem: deleteItem))
	}
}
