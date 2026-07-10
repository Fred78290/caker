//
//  TemplateDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 13/07/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

struct TemplateDetailView: View {
	let template: TemplateEntry

	@State private var infos: VMInformations? = nil
	@State private var errorMessage: String? = nil
	@State private var loading = false
	@State private var vmFromTemplate: TemplateEntry? = nil

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				self.header

				if self.loading {
					HStack {
						Spacer()
						ProgressView()
						Spacer()
					}
					.padding(.top, 40)
				} else if let errorMessage {
					ContentUnavailableView(errorMessage, systemImage: "exclamationmark.triangle")
						.padding(.top, 40)
				} else if let infos {
					if infos.diskInfos.isEmpty == false {
						self.section(title: "Disks", systemImage: "internaldrive") {
							self.rows(infos.diskInfos, id: \.device) { disk in
								self.row(icon: "internaldrive", title: disk.device, value: ByteCountFormatter.string(fromByteCount: Int64(disk.total), countStyle: .file))
							}
						}
					}

					if let networks = infos.attachedNetworks, networks.isEmpty == false {
						self.section(title: "Networks", systemImage: "network") {
							self.rows(networks, id: \.network) { network in
								self.row(icon: "network", title: network.network, value: network.mode ?? String.empty)
							}
						}
					}

					if let mounts = infos.mounts, mounts.isEmpty == false {
						self.section(title: "Shared folders", systemImage: "folder") {
							self.rows(mounts, id: \.self) { mount in
								self.row(icon: "folder", title: mount, value: String.empty)
							}
						}
					}
				}
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.task(id: template.id) {
			await self.loadInfos()
		}
		.sheet(item: self.$vmFromTemplate) { template in
			VirtualMachineWizard(sheet: true, presetTemplate: template)
				.colorSchemeForColor()
				.restorationState(.disabled)
				.frame(minWidth: 700, minHeight: 670)
		}
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 14) {
				osIconImage(for: self.infos?.osname ?? "linux")
					.frame(width: 56, height: 56)

				VStack(alignment: .leading, spacing: 4) {
					Text(self.template.name)
						.font(.system(size: 20, weight: .semibold))
					Text(self.template.fqn)
						.font(.system(size: 12))
						.foregroundStyle(.secondary)
				}

				Spacer()

				Menu {
					Button("New Virtual Machine…") {
						self.vmFromTemplate = self.template
					}
					Divider()
					Button("Clone…") {
						AppState.shared.duplicateTemplate(name: self.template.name)
					}
					Divider()
					Button("Delete", role: .destructive) {
						AppState.shared.deleteTemplate(name: self.template.name)
					}
				} label: {
					Image(systemName: "ellipsis.circle")
				}
				.menuStyle(.borderlessButton)
				.frame(width: 24)
			}

			HStack(spacing: 10) {
				self.statBadge(systemImage: "cpu", value: self.infos.map { "\($0.cpuCount) vCPU" } ?? "—")
				self.statBadge(systemImage: "memorychip", value: self.infos?.memory?.total.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .memory) } ?? "—")
				self.statBadge(systemImage: "internaldrive", value: ByteCountFormatter.string(fromByteCount: Int64(self.template.diskSize), countStyle: .file))
				self.statBadge(systemImage: "shippingbox", value: ByteCountFormatter.string(fromByteCount: Int64(self.template.totalSize), countStyle: .file))

				Spacer()
			}
		}
	}

	@ViewBuilder
	private func section<Content: View>(title: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Label(title, systemImage: systemImage)
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(.secondary)

			VStack(spacing: 0) {
				content()
			}
			.background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.secondarySystemFill)))
			.clipShape(RoundedRectangle(cornerRadius: 10))
		}
	}

	@ViewBuilder
	private func rows<Item, ID: Hashable, Content: View>(_ items: [Item], id: KeyPath<Item, ID>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
		ForEach(Array(items.enumerated()), id: \.offset) { index, item in
			content(item)

			if index != items.count - 1 {
				Divider()
					.padding(.leading, 38)
			}
		}
	}

	private func row(icon: String, title: String, value: String) -> some View {
		HStack(spacing: 10) {
			Image(systemName: icon)
				.font(.system(size: 12))
				.foregroundStyle(.secondary)
				.frame(width: 16)

			Text(title)
				.font(.system(size: 12))
				.lineLimit(1)
				.truncationMode(.middle)

			Spacer()

			if value.isEmpty == false {
				Text(value)
					.font(.system(size: 12, design: .monospaced))
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
	}

	private func statBadge(systemImage: String, value: String) -> some View {
		HStack(spacing: 4) {
			Image(systemName: systemImage)
				.font(.system(size: 10, weight: .medium))
			Text(value)
				.font(.system(size: 11, weight: .medium, design: .monospaced))
		}
		.foregroundStyle(.secondary)
		.padding(.horizontal, 8)
		.padding(.vertical, 3)
		.background(Capsule().fill(.secondary.opacity(0.12)))
	}

	private func loadInfos() async {
		self.loading = true
		self.errorMessage = nil

		let result = await AppState.shared.templateInfos(name: self.template.name)

		self.loading = false

		if result.success, let infos = result.infos {
			self.infos = infos
		} else {
			self.infos = nil
			self.errorMessage = result.reason
		}
	}
}

#Preview {
	TemplateDetailView(template: TemplateEntry(name: "ubuntu", fqn: "template://ubuntu", diskSize: 20_000_000_000, totalSize: 3_260_000_000))
}
