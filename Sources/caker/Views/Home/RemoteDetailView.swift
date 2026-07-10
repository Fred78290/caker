//
//  RemoteDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

struct RemoteDetailView: View {
	let remote: RemoteEntry

	@State private var images: [ImageInfo] = []
	@State private var loading = false
	@State private var vmFromImage: ImageInfo? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			self.header

			Divider()

			if self.loading {
				VStack {
					Spacer()
					ProgressView()
					Spacer()
				}.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if self.images.isEmpty {
				VStack {
					Spacer()
					ContentUnavailableView("No images", systemImage: "square.stack.3d.up.slash")
					Spacer()
				}.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				List(self.images) { image in
					HStack(spacing: 12) {
						VStack(alignment: .leading, spacing: 2) {
							Text(image.aliases.description.isEmpty ? image.fingerprint : image.aliases.description)
								.font(.system(size: 13, weight: .semibold))
								.lineLimit(1)

							Text(image.properties["description"] ?? image.fingerprint)
								.font(.system(size: 11))
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}

						Spacer()

						Text(ByteCountFormatter.string(fromByteCount: Int64(image.size), countStyle: .file))
							.font(.system(size: 11, design: .monospaced))
							.foregroundStyle(.secondary)
					}
					.padding(.vertical, 4)
					.contentShape(Rectangle())
					.contextMenu {
						Button("New Virtual Machine…") {
							self.vmFromImage = image
						}
					}
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
			}
		}
		.task(id: self.remote.id) {
			await self.loadImages()
		}
		.sheet(item: self.$vmFromImage) { image in
			VirtualMachineWizard(sheet: true, presetRemoteImage: (remote: self.remote.name, image: image))
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(minWidth: 700, minHeight: 670)
		}
	}

	private var header: some View {
		HStack(spacing: 14) {
			ZStack {
				RoundedRectangle(cornerRadius: 14)
					.fill(Color.orange.gradient)
					.frame(width: 56, height: 56)
				Image(systemName: "icloud")
					.resizable()
					.aspectRatio(contentMode: .fit)
					.foregroundStyle(.white)
					.frame(width: 26, height: 26)
			}

			VStack(alignment: .leading, spacing: 4) {
				Text(self.remote.name)
					.font(.system(size: 20, weight: .semibold))
				Text(self.remote.url)
					.font(.system(size: 12))
					.foregroundStyle(.secondary)
					.lineLimit(1)
					.truncationMode(.middle)
			}

			Spacer()
		}
		.padding(20)
	}

	private func loadImages() async {
		self.loading = true
		self.images = await AppState.shared.loadImages(remote: self.remote.name)
		self.loading = false
	}
}

#Preview {
	RemoteDetailView(remote: RemoteEntry(name: "ubuntu", url: "https://cloud-images.ubuntu.com/releases"))
}
