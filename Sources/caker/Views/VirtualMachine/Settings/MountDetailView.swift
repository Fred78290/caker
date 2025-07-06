//
//  MountDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct MountDetailView: View {
	@Binding private var currentItem: DirectorySharingAttachment
	private var readOnly: Bool

	init(currentItem: Binding<DirectorySharingAttachment>, readOnly: Bool = true) {
		_currentItem = currentItem
		self.readOnly = readOnly
	}

	var body: some View {
		VStack {
			LabeledContent("Name") {
				TextField("Name", text: $currentItem.name)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.allowsHitTesting(readOnly == false)
			}
			
			LabeledContent("Host path") {
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
			}
			
			LabeledContent("Guest path") {
				TextField("Guest path", value: $currentItem.destination, format: .optional)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.allowsHitTesting(readOnly == false)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
			
			LabeledContent("Read only") {
				Toggle("Read only", isOn: $currentItem.readOnly)
					.toggleStyle(.switch)
					.labelsHidden()
					.allowsHitTesting(readOnly == false)
			}
			
			LabeledContent("Guest user ID mount") {
				TextField("uid", value: $currentItem.uid, format: .number)
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 80)
					.allowsHitTesting(readOnly == false)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
			
			LabeledContent("Guest group ID mount") {
				TextField("gid", value: $currentItem.gid, format: .number)
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
