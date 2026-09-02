//
//  ProvisionVariableDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/09/2026.
//

import SwiftUI

struct ProvisionVariableDetailView: View {
	@Binding private var currentItem: ProvisionVariable
	private var readOnly: Bool

	init(currentItem: Binding<ProvisionVariable>, readOnly: Bool = true) {
		_currentItem = currentItem

		self.readOnly = readOnly
	}

	var body: some View {
		if readOnly {
			compactRow
		} else {
			fullForm
		}
	}

	@ViewBuilder
	var compactRow: some View {
		HStack(spacing: 10) {
			ZStack {
				RoundedRectangle(cornerRadius: 7)
					.fill(Color.purple.gradient)
					.frame(width: 28, height: 28)
				Image(systemName: "curlybraces")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(currentItem.key)
					.font(.system(size: 12, design: .monospaced))
					.lineLimit(1)
				Text(currentItem.value)
					.font(.system(size: 11, design: .monospaced))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer()
		}
		.padding(.vertical, 4)
	}

	@ViewBuilder
	var fullForm: some View {
		VStack {
			LabeledContent("Variable name") {
				TextField("key", text: $currentItem.key)
					.rounded(.leading)
					.frame(width: 300)
			}

			LabeledContent("Value") {
				TextField("value", text: $currentItem.value)
					.rounded(.leading)
					.frame(width: 300)
			}
		}
	}
}

#Preview {
	ProvisionVariableDetailView(currentItem: .constant(.init(key: "greeting", value: "hello")))
}
