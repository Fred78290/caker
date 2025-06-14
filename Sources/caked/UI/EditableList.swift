//
//  EditableList.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/06/2025.
//
import SwiftUI

struct EditableList<Element: Hashable, Content: View>: View {
	@Binding var data: [Element]
	@State var selectedItem: Element?

	var content: (Binding<Element>) -> Content

	init(_ data: Binding<[Element]>, content: @escaping (Binding<Element>) -> Content) {
		self._data = data
		self.content = content
	}

	var body: some View {
		List(selection: $selectedItem) {
			ForEach($data, id: \.self, content: content)
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
