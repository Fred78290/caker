//
//  EditableListNewItem.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI

struct EditableListNewItem<Data: RandomAccessCollection & MutableCollection & RangeReplaceableCollection, Content: View>: View where Data.Element: Hashable & Identifiable {
	@Environment(\.dismiss) var dismiss
	@Binding var data: Data
	@State var newItem: Data.Element
	@State var configChanged: Bool = false

	private var content: () -> Content

	init(newItem: Data.Element, _ data: Binding<Data>, content: @escaping () -> Content) {
		self._data = data
		self.content = content
		self.newItem = newItem
	}

	var body: some View {
		VStack {
			content()
			Spacer()
			Divider()

			HStack(alignment: .bottom) {
				Spacer()
				Button("Cancel") {
					// Cancel saving and dismiss.
					dismiss()
				}
				Spacer()
				Button("Add") {
					// Save the article and dismiss.
					dismiss()
				}.disabled(self.configChanged == false)
				Spacer()
			}.frame(width: 200).padding(.bottom)
		}
    }
}
