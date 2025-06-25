//
//  MountNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct MountNewItemView: View {
	@Binding var mounts: [DirectorySharingAttachment]
	@State var newItem: DirectorySharingAttachment = .init(source: "~".expandingTildeInPath)
	@State var userID: Int? = nil
	@State var groupID: Int? = nil
	@State var name: String = ""
	@State var destination: String = ""
	@State var source: String = "~".expandingTildeInPath
	@State var readOnly: Bool = false

	var body: some View {
		EditableListNewItem(newItem: $newItem, $mounts) {
			Section("New mount point") {
				HStack {
					Text("Name")
					Spacer()
					HStack {
						TextField("", text: $name)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.onChange(of: name) {
								newItem.name = name
							}
					}.frame(width: 300)
				}

				HStack {
					Text("Host path")
					Spacer()
					HStack {
						TextField("", text: $source)
							.multilineTextAlignment(.leading)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.onChange(of: source) {
								newItem.source = source
							}
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
						TextField("Guest path", text: $destination)
							.multilineTextAlignment(.leading)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.onChange(of: destination) {
								if destination.isEmpty {
									newItem.destination = nil
								} else {
									newItem.destination = destination
								}
							}
					}.frame(width: 300)
				}

				Toggle("Read only", isOn: $readOnly).onChange(of: readOnly) {
					newItem.readOnly = readOnly
				}

				HStack {
					Text("Guest user ID mount")
					Spacer()
					TextField("", value: $userID, format: .number)
						.multilineTextAlignment(.center)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
						.frame(width: 50)
						.onChange(of: userID) {
							if let uid = userID {
								newItem.uid = uid
							} else {
								newItem.resetUID()
							}
						}
				}

				HStack {
					Text("Guest group ID mount")
					Spacer()
					TextField("", value: $groupID, format: .number)
						.multilineTextAlignment(.center)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
						.frame(width: 50)
						.onChange(of: groupID) {
							if let gid = groupID {
								newItem.gid = gid
							} else {
								newItem.resetGID()
							}
						}
				}
			}
		}
    }
	
	func chooseFolder() {
		
	}
}

#Preview {
	MountNewItemView(mounts: .constant([]))
}
