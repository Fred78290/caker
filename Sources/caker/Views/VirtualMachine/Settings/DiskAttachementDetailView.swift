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
	@Binding private var currentItem: DiskAttachement
	@State private var model: DiskAttachementModel

	private class DiskAttachementModel: ObservableObject {
		@Published var syncing: Bool
		@Published var readOnly: Bool
		@Published var diskPath: String
		@Published var cachingMode: String

		init(item: DiskAttachement) {
			self.cachingMode = item.diskOptions.cachingMode
			self.diskPath = item.diskPath
			self.readOnly = item.diskOptions.readOnly
			self.syncing = item.diskOptions.syncMode == "full"
		}
	}

	init(currentItem: Binding<DiskAttachement>) {
		self.model = .init(item: currentItem.wrappedValue)
		self._currentItem = currentItem
	}

	var body: some View {
		VStack {
			LabeledContent("Disk path") {
				HStack {
					TextField("Disk image path", text: $model.diskPath)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.onSubmit {
							currentItem.diskPath = model.diskPath
						}
					Button(action: {
						chooseDiskImage()
					}) {
						Image(systemName: "opticaldiscdrive")
					}.buttonStyle(.borderless)
				}.frame(width: 300)
			}
			
			LabeledContent("Syncing") {
				Toggle("Syncing", isOn: $model.syncing)
					.labelsHidden()
					.toggleStyle(.switch)
					.onChange(of: model.syncing) { newValue in
						self.currentItem.diskOptions.syncMode = newValue ? "full" : "none"
					}
			}

			LabeledContent("Read only") {
				Toggle("Read only", isOn: $model.readOnly)
					.labelsHidden()
					.toggleStyle(.switch)
					.onChange(of: model.readOnly) { newValue in
						currentItem.diskOptions.readOnly = newValue
					}
			}

			LabeledContent("Cache mode") {
				Picker("Cache mode", selection: $model.cachingMode) {
					ForEach(["automatic", "cached", "uncached"], id: \.self) { name in
						Text(name).tag(name).frame(width: 100)
					}
				}
				.onChange(of: model.cachingMode) { newValue in
					currentItem.diskOptions.cachingMode = newValue
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
