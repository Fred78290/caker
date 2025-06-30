//
//  MountDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct MountDetailView: View {
	@Binding var currentItem: DirectorySharingAttachment

	var body: some View {
		VStack {
			LabeledContent("Name") {
				TextField("", value: $currentItem._name, format: .optional)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
			
			LabeledContent("Host path") {
				Button(action: {
					chooseFolder()
				}) {
					Image(systemName: "folder")
				}.buttonStyle(.borderless)
				TextField("Host path", text: $currentItem.source)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
			
			LabeledContent("Guest path") {
				TextField("Guest path", value: $currentItem._destination, format: .optional)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
			
			LabeledContent("Read only") {
				Toggle("Read only", isOn: $currentItem.readOnly)
					.toggleStyle(.switch)
					.labelsHidden()
			}
			
			LabeledContent("Guest user ID mount") {
				TextField("uid", value: $currentItem._uid, format: .number)
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 80)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
			
			LabeledContent("Guest group ID mount") {
				TextField("gid", value: $currentItem._gid, format: .number)
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 80)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
    }
	
	func chooseFolder() {
		if let folder = FileHelpers.selectFolder(withTitle: "Choose folder to mount inside VM") {
			currentItem._source = folder.absoluteURL.path
		}
	}
}

#Preview {
	MountDetailView(currentItem: .constant(.init(source: "~".expandingTildeInPath)))
}
