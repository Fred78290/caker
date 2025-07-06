//
//  EditableListNewItem.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct EditableListNewItem<Element, Content: View>: View where Element: Hashable & Identifiable & GRPCLib.Validatable {
	@Environment(\.dismiss) var dismiss
	@Binding var elements: [Element]
	@Binding var currentItem: Element
	@State var configChanged: Bool = false

	private var content: () -> Content
	private var editItem: Element.ID?

	init(_ elements: Binding<[Element]>, currentItem: Binding<Element>, editItem: Element.ID? = nil, content: @escaping () -> Content) {
		self._elements = elements
		self._currentItem = currentItem
		self.content = content
		self.editItem = editItem
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
					save()
				} label: {
					Text(self.editItem == nil ? "Add" : "Save").frame(width: 60)
				}.disabled(self.configChanged == false)
			}
		}.onChange(of: currentItem) { newValue in
			if newValue.validate() {
				if editItem != nil {
					self.configChanged = true
				} else {
					self.configChanged = self.elements.first(where: {$0.id == newValue.id}) == nil
				}
			} else {
				self.configChanged = false
			}
		}
    }
	
	func save() {
		if let editItem = editItem {
			self.elements = self.elements.map {
				if $0.id == editItem {
					return self.currentItem
				}
				
				return $0
			}
		} else {
			elements.append(currentItem)
		}

		dismiss()
	}
}
