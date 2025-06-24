//
//  EditableList.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//
import SwiftUI

struct OnAddItemListViewModifier<SomeView: View>: ViewModifier {

	private var addItemClosure: () -> SomeView
	private var systemName: String
	@Environment(\.dismiss) var dismiss
	@State var displayAddItemView: Bool = false

	init(systemName: String, _ onAddItem: @escaping () -> SomeView) {
		self.addItemClosure = onAddItem
		self.systemName = systemName
	}

	func body(content: Content) -> some View {
		VStack {
			content
			HStack {
				Spacer()
				Button(action: {
					displayAddItemView = true
				}) {
					Image(systemName: "plus")
				}.buttonStyle(.borderless).font(.title)
				Spacer()
			}
		}.sheet(isPresented: $displayAddItemView, onDismiss: nil) {
			HStack {
				self.addItemClosure()
			}.frame(maxWidth: 600).padding()
		}
	}
}

struct EditableList<Data: RandomAccessCollection & MutableCollection & RangeReplaceableCollection, Content: View>: View where Data.Element: Hashable & Identifiable {
	@Binding var data: Data
	@State var selectedItem: Data.Element?

	private var content: (Binding<Data.Element>) -> Content

	init(_ data: Binding<Data>, content: @escaping (Binding<Data.Element>) -> Content) {
		self._data = data
		self.content = content
	}

	var body: some View {
		VStack {
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
		}
	}

	func listItem(item: Binding<Data.Element>) -> some View {
		HStack {
			self.content(item)
			Spacer()
			Button(action: {
				self.deleteItem(item: item)
			}) {
				Image(systemName: "trash")
			}.buttonStyle(.borderless)
		}
	}

	func deleteItem(item: Binding<Data.Element>) {
		self.data.removeAll {
			$0.id == item.wrappedValue.id
		}
	}
}

extension View {
	func onAddItem(systemName: String,_ action: @escaping () -> some View) -> some View {
		modifier(OnAddItemListViewModifier(systemName: systemName, action))
	}
}
