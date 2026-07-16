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
	@State private var selectedImage: ImageInfo? = nil
	@State private var createVM: Bool = false

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
				List(self.images, id: \.self, selection: $selectedImage) { image in
					HStack(alignment: .center, spacing: 12) {
						let labelWidth = 80.0

						GeometryReader { geom in
							VStack(alignment: .leading, spacing: 2) {
								LabeledContent(content: {
									Text(image.aliases.joined(separator: ", "))
										.font(.system(size: 13, weight: .semibold))
										.lineLimit(1)
										.frame(width: geom.size.width - labelWidth, alignment: .leading)
								}, label: {
									Text("Aliases:")
										.font(.system(size: 13, weight: .semibold))
								})

								LabeledContent(content: {
									Text(image.fingerprint.substring(..<12))
										.font(.system(size: 11))
										.foregroundStyle(.secondary)
										.lineLimit(1)
										.frame(width: geom.size.width - labelWidth, alignment: .leading)
								}, label: {
									Text("Fingerprint:")
										.font(.system(size: 11, weight: .semibold))
										.foregroundStyle(.secondary)
								})

								LabeledContent(content: {
									Text(image.properties["description"] ?? "")
										.font(.system(size: 11))
										.foregroundStyle(.secondary)
										.lineLimit(1)
										.frame(width: geom.size.width - labelWidth, alignment: .leading)
								}, label: {
									Text("Description:")
										.font(.system(size: 11, weight: .semibold))
										.foregroundStyle(.secondary)
								})

								LabeledContent(content: {
									Text(image.uploaded ?? "")
										.font(.system(size: 11))
										.foregroundStyle(.secondary)
										.lineLimit(1)
										.frame(width: geom.size.width - labelWidth, alignment: .leading)
								}, label: {
									Text("Uploaded:")
										.font(.system(size: 11, weight: .semibold))
										.foregroundStyle(.secondary)
								})
							}
						}

						Spacer()

						if selectedImage == image {
							Button {
								self.createVM = true
							} label: {
								ZStack {
									RoundedRectangle(cornerRadius: 9)
										.fill(Color.orange.gradient)
										.frame(width: 30, height: 30)
									Image(systemName: "plus.square")
										.resizable()
										.aspectRatio(contentMode: .fit)
										.foregroundStyle(.white)
										.frame(width: 16, height: 16)
								}
							}
							.buttonStyle(.borderless)
							.controlSize(.small)
						} else {
							Text(ByteCountFormatter.string(fromByteCount: Int64(image.size), countStyle: .file))
								.font(.system(size: 11, design: .monospaced))
								.foregroundStyle(.secondary)
						}
					}
					.frame(height: 60.0)
					.padding(.vertical, 4)
					.contentShape(Rectangle())
					.contextMenu {
						Button("New Virtual Machine…") {
							self.createVM = true
						}
					}
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
			}
		}
		.task(id: self.remote.id) {
			await self.loadImages()
		}
		.sheet(isPresented: $createVM) {
			if let selectedImage {
				VirtualMachineWizard(sheet: true, presetRemoteImage: (remote: self.remote.name, image: selectedImage))
					.colorSchemeForColor()
					.restorationState(.disabled)
					.frame(minWidth: 700, minHeight: 670)
			}
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

