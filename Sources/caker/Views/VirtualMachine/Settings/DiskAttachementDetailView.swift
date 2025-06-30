//
//  DiskAttachementDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib
import CakedLib

struct DiskAttachementDetailView: View {
	@Binding var currentItem: DiskAttachement
	@State private var syncing: Bool = false

	var body: some View {
		VStack {
			LabeledContent("Disk path") {
				HStack {
					TextField("", text: $currentItem.diskPath)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
					Button(action: {
						chooseDiskImage()
					}) {
						Image(systemName: "opticaldiscdrive")
					}.buttonStyle(.borderless)
				}.frame(width: 300)
			}
			
			LabeledContent("Syncing") {
				Toggle("Syncing", isOn: $syncing)
					.labelsHidden()
					.toggleStyle(.switch)
					.onChange(of: syncing) { newValue in
						self.currentItem.diskOptions.syncMode = newValue ? "full" : "none"
					}
			}

			LabeledContent("Read only") {
				Toggle("Read only", isOn: $currentItem.diskOptions.readOnly)
					.labelsHidden()
					.toggleStyle(.switch)
					.onChange(of: currentItem.diskOptions.readOnly) { newValue in
						currentItem.diskOptions.readOnly = newValue
					}
			}

			LabeledContent("Cache mode") {
				Picker("Cache mode", selection: $currentItem.diskOptions.cachingMode) {
					ForEach(["automatic", "cached", "uncached"], id: \.self) { name in
						Text(name).tag(name).frame(width: 100)
					}
				}
				.labelsHidden()
				.pickerStyle(.menu)
			}
		}
    }
	
	func chooseDiskImage() {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: [.diskImage, .iso9660], withTitle: "Select disk image", allowsOtherFileTypes: true) {
			currentItem.diskPath = diskImg.absoluteURL.path

			if currentItem.diskPath.lowercased().hasSuffix(".iso") {
				self.currentItem.diskOptions.readOnly = true
			}
		}
	}
}

#Preview {
	DiskAttachementDetailView(currentItem: .constant(DiskAttachement()))
}
