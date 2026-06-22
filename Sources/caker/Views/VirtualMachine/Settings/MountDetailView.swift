//
//  MountDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import GRPCLib
import SwiftUI

struct MountDetailView: View {
	@Binding private var currentItem: DirectorySharingAttachment
	private var readOnly: Bool
	@State private var name: String
	@State private var shared: Bool

	init(currentItem: Binding<DirectorySharingAttachment>, readOnly: Bool = true) {
		_currentItem = currentItem
		let name = currentItem.wrappedValue._name ?? String.empty
		let destination = currentItem.wrappedValue.destination ?? String.empty
		let shared = name.isEmpty && destination.isEmpty

		self.readOnly = readOnly
		self.name = name
		self.shared = shared
	}

	var body: some View {
		if readOnly {
			compactRow
		} else {
			fullForm
				.onChange(of: shared) {
					if self.shared {
						currentItem.destination = String.empty
						currentItem.name = String.empty
					}
				}
		}
	}

	@ViewBuilder
	var compactRow: some View {
		HStack(spacing: 10) {
			ZStack {
				RoundedRectangle(cornerRadius: 7)
					.fill(Color.orange.gradient)
					.frame(width: 28, height: 28)
				Image(systemName: "folder")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(currentItem.source)
					.font(.system(size: 12, design: .monospaced))
					.lineLimit(1)
				Text(currentItem.destination ?? currentItem.name)
					.font(.system(size: 11, design: .monospaced))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer()

			if currentItem.readOnly {
				Text("ro")
					.font(.system(size: 11, weight: .medium))
					.foregroundStyle(.secondary)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(Capsule().fill(.secondary.opacity(0.10)))
			}
		}
		.padding(.vertical, 4)
	}

	@ViewBuilder
	var fullForm: some View {
		VStack {
			LabeledContent("Host path") {
				HStack {
					Button(action: chooseFolder) {
						Image(systemName: "folder")
					}.buttonStyle(.borderless)

					TextField("Host path", text: $currentItem.source)
						.rounded(.leading)
				}.frame(width: 350)
			}

			if shared == false {
				LabeledContent("Name") {
					TextField("Name", text: $name, prompt: Text(currentItem.name))
						.rounded(.leading)
						.onChange(of: name) { _, newValue in
							currentItem.name = newValue
						}
						.frame(width: 350)
				}

				LabeledContent("Guest path") {
					TextField("Guest path", value: $currentItem.destination, format: .optional)
						.rounded(.leading)
						.frame(width: 350)
				}
			}

			LabeledContent("Shared mount") {
				Toggle("Shared mount", isOn: $shared)
					.toggleStyle(.switch)
					.labelsHidden()
			}

			LabeledContent("Read only") {
				Toggle("Read only", isOn: $currentItem.readOnly)
					.toggleStyle(.switch)
					.labelsHidden()
			}

			LabeledContent("Guest user ID") {
				TextField("uid", value: $currentItem.uid, format: .ranged(0...65535))
					.rounded(.center)
					.frame(width: 80)
			}

			LabeledContent("Guest group ID") {
				TextField("gid", value: $currentItem.gid, format: .ranged(0...65535))
					.rounded(.center)
					.frame(width: 80)
			}
		}
	}

	func chooseFolder() {
		if let folder = FileHelpers.selectFolder(withTitle: String(localized: "Choose folder to mount inside VM")) {
			currentItem.source = folder.absoluteURL.path
		}
	}
}

#Preview {
	MountDetailView(currentItem: .constant(.init(source: "~".expandingTildeInPath)))
}
