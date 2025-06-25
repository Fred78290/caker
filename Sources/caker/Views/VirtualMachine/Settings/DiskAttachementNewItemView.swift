//
//  DiskAttachementNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct DiskAttachementNewItemView: View {
	@Binding var attachedDisks: [DiskAttachement]
	@State var newItem: DiskAttachement = .init()
	@State var diskPath: String = ""
	@State var readOnly: Bool = false
	@State var syncing: Bool = false
	@State var cacheMode: String = "automatic"

	var body: some View {
		EditableListNewItem(newItem: $newItem, $attachedDisks) {
			Section("New disk attachement") {
				HStack {
					Text("Disk path")
					Spacer()
					HStack {
						TextField("", text: $diskPath)
							.multilineTextAlignment(.leading)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.onChange(of: diskPath) {
								newItem.diskPath = diskPath
							}
						Button(action: {
							chooseDiskImage()
						}) {
							Image(systemName: "folder")
						}.buttonStyle(.borderless)
					}.frame(width: 300)
				}
				
				Toggle("Syncing", isOn: $syncing).onChange(of: syncing) {
					if syncing {
						newItem.diskOptions.syncMode = "full"
					} else {
						newItem.diskOptions.syncMode = "none"
					}
				}

				Toggle("Read only", isOn: $readOnly).onChange(of: readOnly) {
					newItem.diskOptions.readOnly = readOnly
				}

				Picker("Cache mode", selection: $cacheMode) {
					ForEach(["automatic", "cached", "uncached"], id: \.self) { name in
						Text(name).tag(name)
					}
				}
				.onChange(of: cacheMode) {
					newItem.diskOptions.cachingMode = cacheMode
				}
			}
		}
    }
	
	func chooseDiskImage() {
		
	}
}

#Preview {
    DiskAttachementNewItemView(attachedDisks: .constant([]))
}
