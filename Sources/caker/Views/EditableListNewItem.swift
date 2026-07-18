//
//  EditableListNewItem.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import GRPCLib
import SwiftUI

struct EditableListNewItem<Element, Content: View>: View where Element: Hashable & Identifiable & GRPCLib.Validatable {
	@Environment(\.dismiss) var dismiss
	@Binding var elements: [Element]
	@Binding var currentItem: Element
	@State var configChanged: Bool
	@State var errorMessage: String? = nil
	private var content: () -> Content
	private var validateItem: (Element) -> (valid: Bool, reason: String?)
	private var editItem: Element.ID?

	init(
		_ elements: Binding<[Element]>, currentItem: Binding<Element>, editItem: Element.ID? = nil, content: @escaping () -> Content,
		validateItem: @escaping (_ item: Element) -> (valid: Bool, reason: String?) = {
			if $0.validate() {
				return (true, nil)
			} else {
				return (false, String(localized: "Invalid input"))
			}
		}
	) {

		self._elements = elements
		self._currentItem = currentItem
		self.content = content
		self.editItem = editItem
		self.validateItem = validateItem

		let currentItem = currentItem.wrappedValue
		let result = validateItem(currentItem)

		if result.valid {
			if editItem != nil {
				self.configChanged = true
			} else if elements.first(where: { $0.id == currentItem.id }) == nil {
				self.configChanged = true
			} else {
				self.configChanged = false
			}
		} else {
			self.errorMessage = result.reason
			self.configChanged = false
		}
	}

	var body: some View {
		VStack {
			Form {
				content()
			}.formStyle(.grouped)

			HStack {
				if let errorMessage {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundStyle(.red)
						.font(.callout)
					Text(errorMessage)
						.font(.callout)
						.foregroundStyle(.red)
						.lineLimit(nil)
						.fixedSize(horizontal: false, vertical: true)
				}
			}.frame(height: 10.0)
			Divider()

			HStack(spacing: 8) {
				Spacer()
				Button {
					dismiss()
				} label: {
					Text("Cancel").frame(width: 80)
				}
				.buttonStyle(.bordered)
				Button {
					save()
				} label: {
					Text(self.editItem == nil ? "Add" : "Save").frame(width: 80)
				}
				.buttonStyle(.borderedProminent)
				.disabled(self.configChanged == false)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)
		}.onChange(of: currentItem) { _, newValue in
			self.configChanged = validate(newValue)
		}
	}

	func validate(_ newValue: Element) -> Bool {
		let result = self.validateItem(newValue)

		if result.valid {
			self.errorMessage = nil

			if editItem != nil {
				return true
			} else if self.elements.first(where: { $0.id == newValue.id }) == nil {
				return true
			}
		} else {
			self.errorMessage = result.reason
		}

		return false
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
