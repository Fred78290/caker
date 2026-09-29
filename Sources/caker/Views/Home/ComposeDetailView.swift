//
//  ComposeDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 27/09/2026.
//

import CakedLib
import GRPCLib
import SwiftUI

/// Detail pane for a selected compose project — a compose project can have several services with
/// independent status, so a plain list row ("3/5 running") isn't enough to see what's actually
/// running. Fetches the live per-service breakdown via `ps` and shows it, modeled on
/// `TemplateDetailView.swift`'s header/section/row visual style.
struct ComposeDetailView: View {
	let project: ComposeReplyList.ComposeInfo

	@State private var services: [ComposeServiceInfo] = []
	@State private var loading = false
	@State private var errorMessage: String? = nil

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
				} else if self.services.isEmpty == false {
					self.section(title: "Services", systemImage: "square.stack.3d.up") {
						self.rows(self.services, id: \.name) { service in
							self.row(service)
						}
					}
				}
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		// Keyed on the running count too, not just the name: `ComposeView` swaps in a fresh `project`
		// value on every poll, and keying on the name alone loaded the per-service rows once — a VM
		// stopping (or starting) elsewhere updated the header's "n/m running" but left these dots stale.
		.task(id: "\(self.project.name)#\(self.project.runningServiceCount)") {
			await self.loadServices()
		}
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 14) {
				ZStack {
					RoundedRectangle(cornerRadius: 12)
						.fill(Color.pink.gradient)
						.frame(width: 56, height: 56)
					Image(systemName: "square.stack.3d.up")
						.resizable()
						.aspectRatio(contentMode: .fit)
						.foregroundStyle(.white)
						.frame(width: 28, height: 28)
				}

				VStack(alignment: .leading, spacing: 4) {
					Text(self.project.name)
						.font(.system(size: 20, weight: .semibold))
					Text(self.project.statusSummary)
						.font(.system(size: 12))
						.foregroundStyle(.secondary)
				}

				Spacer()

				Button {
					if self.project.primaryAction == .start {
						ComposeView.start(self.project) {
							Task { await self.loadServices() }
						}
					} else {
						ComposeView.confirmAndStop(self.project) {
							Task { await self.loadServices() }
						}
					}
				} label: {
					Image(systemName: self.project.primaryAction == .start ? "play.circle.fill" : "stop.circle.fill")
						.font(.system(size: 22))
						.foregroundStyle(self.project.primaryAction == .start ? .green : .orange)
				}
				.withButtonStyle(.borderless)
				.help(
					self.project.primaryAction == .start
						? String(localized: "Start this project's services")
						: String(localized: "Stop this project's services"))
			}

			HStack(spacing: 10) {
				self.statBadge(systemImage: "square.stack.3d.up", value: "\(self.project.totalServiceCount)")
				self.statBadge(systemImage: "bolt.fill", value: "\(self.project.runningServiceCount)")

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

	private func row(_ service: ComposeServiceInfo) -> some View {
		HStack(spacing: 10) {
			GlossyCircle(color: service.running ? .green : .gray)
				.frame(width: 10, height: 10)

			Text(service.name)
				.font(.system(size: 12, weight: .medium))
				.lineLimit(1)
				.truncationMode(.middle)

			Spacer()

			Text(service.image)
				.font(.system(size: 11, design: .monospaced))
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.middle)

			Text(service.status)
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
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

	private func loadServices() async {
		self.loading = true
		self.errorMessage = nil

		let client = AppState.shared.connectionManager.serviceClient
		let runMode = AppState.shared.connectionManager.connectionMode.runMode
		let projectName = self.project.name

		do {
			let reply = try await Task.detached(priority: .userInitiated) {
				try ComposeHandler.ps(client: client, name: projectName, runMode: runMode)
			}.value

			guard !Task.isCancelled else { return }

			self.loading = false

			if reply.success {
				self.services = reply.services
			} else {
				self.services = []
				self.errorMessage = reply.reason
			}
		} catch {
			guard !Task.isCancelled else { return }

			self.loading = false
			self.services = []
			self.errorMessage = error.localizedDescription
		}
	}
}

#Preview {
	ComposeDetailView(
		project: ComposeReplyList.ComposeInfo(
			name: "demo",
			services: [
				ComposeServiceInfo(name: "app", image: "ubuntu:24.04", status: "provisioned", running: true),
				ComposeServiceInfo(name: "database", image: "ubuntu:24.04", status: "not found", running: false),
			]))
}
