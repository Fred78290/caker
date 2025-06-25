//
//  EditableListNewItem.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct EditableListNewItem<Data: RandomAccessCollection & MutableCollection & RangeReplaceableCollection, Content: View>: View where Data.Element: Hashable & Identifiable & GRPCLib.Validatable {
	@Environment(\.dismiss) var dismiss
	@Binding var data: Data
	@Binding var newItem: Data.Element
	@State var configChanged: Bool = false

	private var content: () -> Content

	init(newItem: Binding<Data.Element>, _ data: Binding<Data>, content: @escaping () -> Content) {
		self._newItem = newItem
		self._data = data
		self.content = content
	}

	var body: some View {
		VStack {
			Form {
				content()
			}.formStyle(.grouped)

			Spacer()
			Divider()

			HStack(alignment: .bottom) {
				Spacer()
				Button {
					dismiss()
				} label: {
					Text("Cancel").frame(width: 60)
				}
				Button {
					data.append(newItem)
					dismiss()
				} label: {
					Text("Add").frame(width: 60)
				}.disabled(self.configChanged == false)
			}
		}.onChange(of: newItem) { newValue in
			if newValue.validate() {
				self.configChanged = self.data.first {
					$0.id == newValue.id
				} == nil
			} else {
				self.configChanged = false
			}
		}
    }
}
