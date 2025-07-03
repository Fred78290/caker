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
	@State private var model: DirectorySharingAttachmentModel

	private class DirectorySharingAttachmentModel: ObservableObject {
		@Published var readOnly: Bool
		@Published var name: String? = nil
		@Published var source: String = ""
		@Published var destination: String? = nil
		@Published var uid: Int? = nil
		@Published var gid: Int? = nil
		
		init(item: DirectorySharingAttachment) {
			self.readOnly = item.readOnly
			self.name = item._name
			self.source = item.source
			self.destination = item._destination
			self.uid = item._uid
			self.gid = item._gid
		}
	}

	init(currentItem: Binding<DirectorySharingAttachment>) {
		_currentItem = currentItem
		self.model = .init(item: currentItem.wrappedValue)
	}

	var body: some View {
		VStack {
			LabeledContent("Name") {
				TextField("Name", value: $model.name, format: .optional)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.onSubmit {
						currentItem._name = model.name
					}
			}
			
			LabeledContent("Host path") {
				Button(action: {
					chooseFolder()
				}) {
					Image(systemName: "folder")
				}.buttonStyle(.borderless)
				TextField("Host path", text: $model.source)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.onSubmit {
						currentItem.source = model.source
					}
			}
			
			LabeledContent("Guest path") {
				TextField("Guest path", value: $model.destination, format: .optional)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.onSubmit {
						currentItem._destination = model.destination
					}
			}
			
			LabeledContent("Read only") {
				Toggle("Read only", isOn: $model.readOnly)
					.toggleStyle(.switch)
					.labelsHidden()
					.onChange(of: model.readOnly) { newValue in
						currentItem.readOnly = newValue
					}
			}
			
			LabeledContent("Guest user ID mount") {
				TextField("uid", value: $model.uid, format: .number)
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 80)
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.onSubmit {
						currentItem._uid = model.uid
					}
			}
			
			LabeledContent("Guest group ID mount") {
				TextField("gid", value: $model.gid, format: .number)
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 80)
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.onSubmit {
						currentItem._gid = model.gid
					}
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
