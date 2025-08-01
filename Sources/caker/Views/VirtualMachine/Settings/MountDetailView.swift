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

	init(currentItem: Binding<DirectorySharingAttachment>, readOnly: Bool = true) {
		_currentItem = currentItem
		self.readOnly = readOnly
		self.name = currentItem.wrappedValue._name ?? ""
	}

	var body: some View {
		VStack {
			LabeledContent("Name") {
				HStack {
					TextField("Name", text: $name, prompt: Text(currentItem.name))
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.allowsHitTesting(readOnly == false)
						.onChange(of: name) { newValue in
							currentItem.name = newValue
						}
				}.frame(width: readOnly ? 500 : 350)
			}

			LabeledContent("Host path") {
				HStack {
					if readOnly == false {
						Button(action: {
							chooseFolder()
						}) {
							Image(systemName: "folder")
						}.buttonStyle(.borderless)
					}

					TextField("Host path", text: $currentItem.source)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.allowsHitTesting(readOnly == false)
				}.frame(width: readOnly ? 500 : 350)
			}

			LabeledContent("Guest path") {
				HStack {
					TextField("Guest path", value: $currentItem.destination, format: .optional)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.allowsHitTesting(readOnly == false)
						.clipShape(RoundedRectangle(cornerRadius: 6))
				}.frame(width: readOnly ? 500 : 350)
			}

			LabeledContent("Read only") {
				Toggle("Read only", isOn: $currentItem.readOnly)
					.toggleStyle(.switch)
					.labelsHidden()
					.allowsHitTesting(readOnly == false)
			}

			LabeledContent("Guest user ID mount") {
				TextField("uid", value: $currentItem.uid, format: .ranged(0...65535))
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 80)
					.allowsHitTesting(readOnly == false)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}

			LabeledContent("Guest group ID mount") {
				TextField("gid", value: $currentItem.gid, format: .ranged(0...65535))
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 80)
					.allowsHitTesting(readOnly == false)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}

	func chooseFolder() {
		if let folder = FileHelpers.selectFolder(withTitle: "Choose folder to mount inside VM") {
			currentItem.source = folder.absoluteURL.path
		}
	}
}

#Preview {
	MountDetailView(currentItem: .constant(.init(source: "~".expandingTildeInPath)))
}
