//
//  ImageCacheView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/09/2026.
//

import CakedLib
import GRPCLib
import SwiftUI

/// Lists the image cache (cloud images, ISO, IPSW, OCI, simple streams…) and creates a VM from a
/// cached entry — the native counterpart of the WebUI's `ImagesPage` "cache" mode.
///
/// The cache is fetched with the same `ListHandler.list(vmonly: false, …)` call the LXD REST layer
/// uses (`LXDImagesController.allCachedImages()`), keeping only the non-`vm` entries; through
/// `ListHandler.list(client:…)` it works both against a remote/local `caked` (gRPC) and in `.app`
/// mode (local `CakedLib` fallback). There is no push mechanism for the cache, so it's loaded on
/// appear and on demand via the refresh button. Selecting a row reveals an inline "create VM"
/// button (same selection-then-inline-action pattern as `TasksView`); it opens the regular
/// `VirtualMachineWizard` pre-filled with the entry (`presetCachedImage:`).
struct ImageCacheView: View {
	@Bindable var navigationModel: NavigationModel

	@State private var images: [VirtualMachineInfo] = []
	@State private var loadError: String? = nil
	@State private var isLoading: Bool = false
	@State private var filter: String = ""
	@State private var vmFromImage: VirtualMachineInfo? = nil

	private var filteredImages: [VirtualMachineInfo] {
		let filter = self.filter.trimmingCharacters(in: .whitespaces)

		guard filter.isEmpty == false else {
			return self.images
		}

		return self.images.filter { image in
			image.name.localizedCaseInsensitiveContains(filter)
				|| image.fqn.contains { $0.localizedCaseInsensitiveContains(filter) }
				|| (image.fingerprint?.localizedCaseInsensitiveContains(filter) ?? false)
				|| Self.kindLabel(CachedImageKind(cacheType: image.type)).localizedCaseInsensitiveContains(filter)
		}
	}

	static func kindLabel(_ kind: CachedImageKind) -> String {
		switch kind {
		case .cloudImage: return String(localized: "Cloud Image")
		case .rawImage: return String(localized: "Raw image")
		case .iso: return String(localized: "ISO")
		case .ipsw: return String(localized: "IPSW")
		case .oci: return String(localized: "OCI")
		case .ociLayers: return String(localized: "OCI layers")
		case .simpleStream: return String(localized: "Simple stream")
		case .template: return String(localized: "Template")
		case .unknown(let type): return type
		}
	}

	static func kindIcon(_ kind: CachedImageKind) -> String {
		switch kind {
		case .cloudImage, .simpleStream: return "cloud"
		case .rawImage: return "internaldrive"
		case .iso: return "opticaldisc"
		case .ipsw: return "apple.logo"
		case .oci, .ociLayers: return "shippingbox"
		case .template: return "books.vertical.fill"
		case .unknown: return "questionmark.folder"
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				TextField("Filter", text: $filter)
					.textFieldStyle(.roundedBorder)

				Button {
					self.refresh()
				} label: {
					Image(systemName: "arrow.clockwise")
				}
				.help(String(localized: "Refresh"))
				.disabled(self.isLoading)
			}
			.padding(8)

			Divider()

			self.list
		}
		.task(id: AppState.shared.connectionMode) {
			self.refresh()
		}
		// Not `sheet(item:)`: cache entries have no `instanceID`, so `VirtualMachineInfo.id` (`instanceID ?? name`) isn't a reliable identity.
		.sheet(isPresented: Binding(get: { self.vmFromImage != nil }, set: { if $0 == false { self.vmFromImage = nil } })) {
			if let image = self.vmFromImage {
				VirtualMachineWizard(connectionManager: AppState.shared.connectionManager, sheet: true, presetCachedImage: image)
					.colorSchemeForColor()
					.restorationState(.disabled)
					.frame(minWidth: 700, minHeight: 670)
			}
		}
	}

	@ViewBuilder
	private var list: some View {
		GeometryReader { geom in
			if self.filteredImages.isEmpty {
				VStack(alignment: .center) {
					if let loadError {
						ContentUnavailableView("Unable to load the image cache", systemImage: "exclamationmark.triangle", description: Text(loadError))
					} else {
						ContentUnavailableView("List empty", systemImage: "tray")
					}
				}.frame(width: geom.size.width, height: geom.size.height)
			} else {
				List(self.filteredImages, id: \.self, selection: $navigationModel.selectedCachedImage) { image in
					self.row(image)
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
				.frame(size: geom.size)
			}
		}
	}

	@ViewBuilder
	private func row(_ image: VirtualMachineInfo) -> some View {
		let kind = CachedImageKind(cacheType: image.type)

		HStack(spacing: 12) {
			ZStack {
				RoundedRectangle(cornerRadius: 9)
					.fill(Color.teal.gradient)
					.frame(width: 38, height: 38)
				Image(systemName: Self.kindIcon(kind))
					.resizable()
					.aspectRatio(contentMode: .fit)
					.foregroundStyle(.white)
					.frame(width: 20, height: 20)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(image.fqn.first ?? image.name)
					.font(.system(size: 13, weight: .semibold))
					.lineLimit(1)
					.truncationMode(.middle)

				HStack(spacing: 6) {
					Text(Self.kindLabel(kind))
					Text(ByteCountFormatter.string(fromByteCount: Int64(image.diskSize), countStyle: .file))

					if let date = image.lastUsed ?? image.created {
						Text(date.formatted(date: .abbreviated, time: .omitted))
					}
				}
				.font(.system(size: 11))
				.foregroundStyle(.secondary)

				if let fingerprint = image.fingerprint, fingerprint.isEmpty == false {
					Text(fingerprint)
						.font(.system(size: 10, design: .monospaced))
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
				}
			}

			Spacer()

			if image == navigationModel.selectedCachedImage {
				Button {
					self.deleteCachedImage(image)
				} label: {
					ZStack {
						RoundedRectangle(cornerRadius: 9)
							.fill(Color.red.gradient)
							.frame(width: 30, height: 30)
						Image(systemName: "trash")
							.resizable()
							.aspectRatio(contentMode: .fit)
							.foregroundStyle(.white)
							.frame(width: 16, height: 16)
					}
				}
				.withButtonStyle(.borderless)
				.controlSize(.small)
				.help(String(localized: "Delete this cached image"))

				Button {
					self.vmFromImage = image
				} label: {
					ZStack {
						RoundedRectangle(cornerRadius: 9)
							.fill((kind.canCreateVirtualMachine ? Color.green : Color.gray).gradient)
							.frame(width: 30, height: 30)
						Image(systemName: "plus")
							.resizable()
							.aspectRatio(contentMode: .fit)
							.foregroundStyle(.white)
							.frame(width: 16, height: 16)
					}
				}
				.withButtonStyle(.borderless)
				.controlSize(.small)
				.disabled(kind.canCreateVirtualMachine == false)
				.help(kind.canCreateVirtualMachine ? String(localized: "Create a virtual machine from this image") : String(localized: "A virtual machine can't be created from this kind of cached image"))
			}
		}
		.padding(.vertical, 4)
		.contentShape(Rectangle())
		.contextMenu {
			Button("New Virtual Machine…") {
				self.vmFromImage = image
			}
			.disabled(kind.canCreateVirtualMachine == false)

			Button("Delete…") {
				self.deleteCachedImage(image)
			}
		}
	}

	private func deleteCachedImage(_ image: VirtualMachineInfo) {
		guard let fqn = image.fqn.first else {
			alertError(String(localized: "Delete failed"), String(localized: "This cached image has no identifier to delete it with"))
			return
		}

		// NSAlert.runModal() must run on the main thread.
		DispatchQueue.main.async {
			let alert = NSGlassEffectAlert()

			alert.messageText = String(localized: "Delete cached image")
			alert.informativeText = String(format: String(localized: "Are you sure you want to delete the cached image %@? This action cannot be undone."), fqn)
			alert.alertStyle = .critical
			alert.addButton(withTitle: String(localized: "Delete"))
			alert.addButton(withTitle: String(localized: "Cancel"))

			guard alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn else {
				return
			}

			let client = AppState.shared.connectionManager.serviceClient
			let runMode = AppState.shared.connectionManager.connectionMode.runMode

			DispatchQueue.global(qos: .utility).async {
				do {
					let reply = try DeleteHandler.deleteCachedImage(client: client, fqn: fqn, runMode: runMode)

					DispatchQueue.main.async {
						if reply.success && reply.objects.allSatisfy({ $0.deleted }) {
							if self.navigationModel.selectedCachedImage == image {
								self.navigationModel.selectedCachedImage = nil
							}

							self.refresh()
						} else {
							alertError(String(localized: "Delete failed"), reply.objects.first(where: { $0.deleted == false })?.reason ?? reply.reason)
						}
					}
				} catch {
					DispatchQueue.main.async {
						alertError(error)
					}
				}
			}
		}
	}

	private func refresh() {
		self.isLoading = true

		let client = AppState.shared.connectionManager.serviceClient
		let runMode = AppState.shared.connectionManager.connectionMode.runMode

		DispatchQueue.global(qos: .utility).async {
			do {
				let reply = try ListHandler.list(client: client, vmonly: false, includeConfig: false, runMode: runMode)

				DispatchQueue.main.async {
					self.isLoading = false

					guard reply.success else {
						self.loadError = reply.reason
						alertError(String(localized: "Unable to load the image cache"), reply.reason)
						return
					}

					self.images = reply.infos.filter { $0.type != "vm" && CachedImageKind(cacheType: $0.type).isListed }
					self.loadError = nil

					if let selected = self.navigationModel.selectedCachedImage, self.images.contains(selected) == false {
						self.navigationModel.selectedCachedImage = nil
					}
				}
			} catch {
				DispatchQueue.main.async {
					self.isLoading = false
					self.loadError = error.localizedDescription
					alertError(error)
				}
			}
		}
	}
}

#Preview {
	ImageCacheView(navigationModel: .init(selectedCategory: .cache))
}
