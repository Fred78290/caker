//
//  ProvisionVariablesView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/09/2026.
//
import CakedLib
import SwiftUI

struct ProvisionVariablesView: View {
	@Binding var variables: ProvisionVariables
	@Binding var disabled: Bool
	@State private var selection: ProvisionVariable.ID? = nil

	var body: some View {
		GeometryReader { geometry in
			EditableList($variables, selection: $selection) { $item in
				ProvisionVariableDetailView(currentItem: $item)
			}.onEditItem(selection: $selection, disabled: $disabled) { editItem in
				ProvisionVariableNewItemView($variables, editItem: editItem)
			} deleteItem: {
				self.variables.removeAll {
					$0.id == selection
				}
			}.frame(height: geometry.size.height)
		}
	}
}

#Preview {
	ProvisionVariablesView(variables: .constant([]), disabled: .constant(false))
}
