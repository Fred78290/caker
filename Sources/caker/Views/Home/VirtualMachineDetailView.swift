//
//  VirtualMachineDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 09/09/2026.
//
//  Shown in HomeView's detail column when VirtualMachinesView is in `.list` mode and a VM is
//  selected — the mosaic mode already shows a live screenshot/status on every tile, so this exists
//  specifically to give list mode the same at-a-glance information without switching layouts.
//  Modeled on TemplateDetailView's header/section/row structure for visual consistency, but
//  everything it shows already lives on VirtualMachineDocumentState (no async fetch needed, unlike
//  TemplateDetailView's remote disk/network/mount lookup).

import CakedLib
import GRPCLib
import SwiftUI

struct VirtualMachineDetailView: View {
	let vm: VirtualMachineDocumentState

	@State private var screenshot: NSImage?

	init(vm: VirtualMachineDocumentState) {
		self.vm = vm
		self.screenshot = vm.lastScreenshot
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 24) {
				self.screenshotView

				self.header

				self.section(title: "Information", systemImage: "info.circle") {
					self.row(icon: "power", title: "Status", value: self.vm.status.description.capitalized)
					Divider().padding(.leading, 38)
					self.row(icon: "number", title: "Instance ID", value: self.vm.instanceID)
				}
			}
			.padding(20)
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.onReceive(VirtualMachineDocument.NewScreenshot) { notification in
			if let screenshot: Data = self.vm.issuedNotificationFromDocument(notification) {
				self.screenshot = NSImage(data: screenshot)
			}
		}
	}

	@ViewBuilder
	private var screenshotView: some View {
		ZStack {
			if let screenshot = self.screenshot {
				Image(nsImage: screenshot)
					.resizable()
					.aspectRatio(contentMode: .fill)
			} else {
				LinearGradient(colors: [Color(white: 0.12), Color(white: 0.05)], startPoint: .top, endPoint: .bottom)

				self.vm.osImage
					.frame(width: 56, height: 56)
			}
		}
		.frame(maxWidth: .infinity)
		.aspectRatio(16.0 / 10.0, contentMode: .fit)
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.15)))
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 14) {
				self.vm.osImage
					.frame(width: 44, height: 44)

				VStack(alignment: .leading, spacing: 4) {
					Text(self.vm.name)
						.font(.system(size: 20, weight: .semibold))

					HStack(spacing: 6) {
						GlossyCircle(color: HostVirtualMachineView.vmStatusColor(self.vm.status))
							.frame(width: 8, height: 8)
						Text(self.vm.status.description.capitalized)
							.font(.system(size: 12))
							.foregroundStyle(.secondary)
					}
				}

				Spacer()

				Button(action: { self.vm.toggleAction() }) {
					Image(systemName: HostVirtualMachineView.vmActionIcon(self.vm.status))
						.font(.system(size: 14, weight: .medium))
				}
				.buttonStyle(.borderless)
				.labelsHidden()

				Menu {
					Button("Open") {
						self.open()
					}
					Divider()

					if self.vm.status == .paused {
						Button("Resume") {
							self.vm.resumeFromUI()
						}
					} else if self.vm.canStart {
						Button("Start") {
							self.vm.startFromUI()
						}.disabled(self.vm.status.isRunning)
					}

					Button("Stop") {
						self.vm.stopFromUI(force: self.vm.status != .running || NSEvent.modifierFlags.contains(.option))
					}.disabled(self.vm.canStop == false)

					Button("Pause") {
						self.vm.suspendFromUI()
					}.disabled(self.vm.canPause == false)

					Divider()

					Button("Duplicate") {
						self.vm.duplicateVirtualMachine()
					}.disabled(self.vm.status.isRunning)

					Button("Rename") {
						self.vm.renameVirtualMachine()
					}.disabled(self.vm.status.isStopped == false)

					Button("Delete VM", role: .destructive) {
						self.vm.deleteVirtualMachine()
					}.disabled(self.vm.status.isRunning)
				} label: {
					Image(systemName: "ellipsis.circle")
				}
				.menuStyle(.borderlessButton)
				.frame(width: 24)
			}

			HStack(spacing: 10) {
				Spacer()
				self.statBadge(systemImage: "cpu", value: "\(self.vm.cpuCount) vCPU")
				self.statBadge(systemImage: "memorychip", value: self.vm.humanReadableMemorySize)
				self.statBadge(systemImage: "internaldrive", value: self.vm.humanReadableDiskSize)
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

	private func row(icon: String, title: LocalizedStringKey, value: String) -> some View {
		HStack(spacing: 10) {
			Image(systemName: icon)
				.font(.system(size: 12))
				.foregroundStyle(.secondary)
				.frame(width: 16)

			Text(title)
				.font(.system(size: 12))
				.lineLimit(1)

			Spacer()

			Text(value)
				.font(.system(size: 12, design: .monospaced))
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.middle)
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

	private func open() {
		func showError(error: Error) {
			_ = Utilities.group.next().makeFutureWithTask {
				await alertError(error)
			}
		}

		let result = Utilities.group.next().makeFutureWithTask {
			await MainApp.app.openVirtualMachine(self.vm.url)
		}

		result.whenFailure { error in
			showError(error: error)
		}
	}
}

#Preview {
	VirtualMachineDetailView(vm: .init(AppState.shared.documents.first!))
}
