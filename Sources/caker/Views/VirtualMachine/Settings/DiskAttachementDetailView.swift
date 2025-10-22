//
//  DiskAttachementDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

struct DiskAttachementDetailView: View {
	@Binding private var currentItem: DiskAttachement
	@State private var syncing: Bool

	private var readOnly: Bool

	init(currentItem: Binding<DiskAttachement>, readOnly: Bool = true) {
		self._currentItem = currentItem
		self.readOnly = readOnly
		self.syncing = currentItem.wrappedValue.diskOptions.syncMode == "full"
	}

	var body: some View {
		VStack {
			LabeledContent("Disk path") {
				HStack {
					TextField("Disk image path", text: $currentItem.diskPath)
						.rounded(.leading)
						.allowsHitTesting(readOnly == false)

					if readOnly == false {
						Button(action: {
							chooseDiskImage()
						}) {
							Image(systemName: "opticaldiscdrive")
						}.buttonStyle(.borderless)
					}
				}.frame(width: readOnly ? 500 : 350)
			}

			LabeledContent("Syncing") {
				Toggle("Syncing", isOn: $syncing)
					.labelsHidden()
					.toggleStyle(.switch)
					.allowsHitTesting(readOnly == false)
					.onChange(of: syncing) { _, newValue in
						self.currentItem.diskOptions.syncMode = newValue ? "full" : "none"
					}
			}

			LabeledContent("Read only") {
				Toggle("Read only", isOn: $currentItem.diskOptions.readOnly)
					.labelsHidden()
					.toggleStyle(.switch)
					.allowsHitTesting(readOnly == false)
			}

			LabeledContent("Cache mode") {
				Picker("Cache mode", selection: $currentItem.diskOptions.cachingMode) {
					ForEach(["automatic", "cached", "uncached"], id: \.self) { name in
						Text(name).tag(name).frame(width: 100)
					}
				}
				.allowsHitTesting(readOnly == false)
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
