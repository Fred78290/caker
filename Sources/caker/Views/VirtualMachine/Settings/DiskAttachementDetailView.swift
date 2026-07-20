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
		if readOnly {
			compactRow
		} else {
			fullForm
		}
	}

	@ViewBuilder
	var compactRow: some View {
		HStack(spacing: 10) {
			ZStack {
				RoundedRectangle(cornerRadius: 7)
					.fill(Color.gray.gradient)
					.frame(width: 28, height: 28)
				Image(systemName: currentItem.diskPath.hasSuffix(".iso") ? "opticaldiscdrive" : "internaldrive")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white)
			}

			Text(currentItem.diskPath.expandingTildeInPath)
				.font(.system(size: 12, design: .monospaced))
				.lineLimit(1)

			Spacer()

			HStack(spacing: 4) {
				if Utilities.isValidSharePoint(currentItem.diskPath.expandingTildeInPath, runMode: .current) {
					if currentItem.diskOptions.readOnly {
						Text("ro")
							.font(.system(size: 11, weight: .medium))
							.foregroundStyle(.secondary)
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(Capsule().fill(.secondary.opacity(0.10)))
					}
					Text(currentItem.diskOptions.cachingMode)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				} else {
					Image(systemName: "exclamationmark.shield.fill")
						.font(.system(size: 16, weight: .semibold))
						.foregroundStyle(.red)
						.help("Attached disk is not in the sandbox or is not in Public Documents Download user folder")
				}
			}
		}
		.padding(.vertical, 4)
	}

	@ViewBuilder
	var fullForm: some View {
		VStack {
			LabeledContent("Disk path") {
				HStack {
					TextField("Disk image path", text: $currentItem.diskPath)
						.rounded(.leading)
					Button(action: chooseDiskImage) {
						Image(systemName: "opticaldiscdrive")
					}.buttonStyle(.borderless)
				}.frame(width: 350)
			}

			LabeledContent("Syncing") {
				Toggle("Syncing", isOn: $syncing)
					.labelsHidden()
					.toggleStyle(.switch)
					.onChange(of: syncing) { _, newValue in
						self.currentItem.diskOptions.syncMode = newValue ? "full" : "none"
					}
			}

			LabeledContent("Read only") {
				Toggle("Read only", isOn: $currentItem.diskOptions.readOnly)
					.labelsHidden()
					.toggleStyle(.switch)
			}

			LabeledContent("Cache mode") {
				Picker("Cache mode", selection: $currentItem.diskOptions.cachingMode) {
					ForEach(["automatic", "cached", "uncached"], id: \.self) { name in
						Text(LocalizedStringKey(stringLiteral: name)).tag(name).frame(width: 100)
					}
				}
				.labelsHidden()
				.pickerStyle(.menu)
			}
		}
	}

	func chooseDiskImage() {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: [.diskImage, .iso9660], withTitle: String(localized: "Choose an image disk"), allowsOtherFileTypes: true) {
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
