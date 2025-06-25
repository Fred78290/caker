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
			HStack {
				Text("Name")
				Spacer()
				HStack {
					TextField("", value: $currentItem._name, format: .optional)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
				}.frame(width: 300)
			}

			HStack {
				Text("Host path")
				Spacer()
				HStack {
					TextField("Host path", text: $currentItem.source)
						.multilineTextAlignment(.leading)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
					Button(action: {
						chooseFolder()
					}) {
						Image(systemName: "folder")
					}.buttonStyle(.borderless)
				}.frame(width: 300)
			}

			HStack {
				Text("Guest path")
				Spacer()
				HStack {
					TextField("Guest path", value: $currentItem._destination, format: .optional)
						.multilineTextAlignment(.leading)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
				}.frame(width: 300)
			}

			HStack {
				Text("Read only")
				Spacer()
				HStack {
					Spacer()
					Toggle("Read only", isOn: $currentItem.readOnly)
						.toggleStyle(.switch)
						.labelsHidden()
				}.frame(width: 300)
			}

			HStack {
				Text("Guest user ID mount")
				Spacer()
				TextField("uid", value: $currentItem._uid, format: .number)
					.multilineTextAlignment(.center)
					.textFieldStyle(SquareBorderTextFieldStyle())
					.labelsHidden()
					.frame(width: 80)
			}

			HStack {
				Text("Guest group ID mount")
				Spacer()
				TextField("gid", value: $currentItem._gid, format: .number)
					.multilineTextAlignment(.center)
					.textFieldStyle(SquareBorderTextFieldStyle())
					.labelsHidden()
					.frame(width: 80)
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
