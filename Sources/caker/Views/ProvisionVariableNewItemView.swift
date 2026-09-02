//
//  ProvisionVariableNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/09/2026.
//

import SwiftUI

struct ProvisionVariableNewItemView: View {
	@Binding private var variables: ProvisionVariables
	@State private var newItem: ProvisionVariable
	private let editItem: ProvisionVariable.ID?

	init(_ variables: Binding<ProvisionVariables>, editItem: ProvisionVariable.ID? = nil) {
		self._variables = variables
		self.editItem = editItem
		self.newItem = variables.wrappedValue.editItem(editItem)
	}

	var body: some View {
		EditableListNewItem($variables, currentItem: $newItem, editItem: editItem) {
			Section("New provisioning variable") {
				ProvisionVariableDetailView(currentItem: $newItem, readOnly: false)
			}
		} validateItem: { item in
			let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
			let value = item.value

			if key.isEmpty {
				return (false, String(localized: "Please specify a variable name"))
			}

			if key.contains("=") {
				return (false, String(localized: "Variable names can't contain '='"))
			}

			if key.contains("|") || value.contains("|") {
				return (false, String(localized: "Variables can't contain '|'"))
			}

			if variables.contains(where: { $0.id != item.id && $0.key.trimmingCharacters(in: .whitespacesAndNewlines) == key }) {
				return (false, String(localized: "A variable with this name already exists"))
			}

			return (true, nil)
		}
	}
}

#Preview {
	ProvisionVariableNewItemView(.constant([]))
}
