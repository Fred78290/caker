//
//  VirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/07/2025.
//

import SwiftUI
import GRPCLib
import CakedLib

extension Shape {
	func fill<Fill: ShapeStyle, Stroke: ShapeStyle>(_ fillStyle: Fill, strokeBorder strokeStyle: Stroke, lineWidth: Double = 1) -> some View {
		if #available(macOS 26.0, *) {
			return
				self
				.fill(fillStyle)
				.background(fillStyle)
		} else {
			return
				self
				.fill(fillStyle)
				.stroke(strokeStyle, lineWidth: lineWidth)
				.background(fillStyle)
		}
	}
}

struct VirtualMachineView: View {
	@Environment(\.appearsActive) var appearsActive
	@Environment(\.materialActiveAppearance) var materialActiveAppearance

	private var selected: Bool
	private let radius: CGFloat = 12
	private let selectedSystemFill = Color(NSColor.secondarySystemFill)
	private let secondarySystemFill = Color(NSColor.tertiarySystemFill)
	private var vm: VirtualMachineDocumentState
	@State private var screenshot: NSImage?

#if DEBUG
	let tracker: TrackDealloc
#endif

	init(_ vm: VirtualMachineDocumentState, selected: Bool) {
		self.vm = vm
		self.selected = selected
		self.screenshot = vm.lastScreenshot
#if DEBUG
		self.tracker = TrackDealloc(from: "VirtualMachineView \(vm.url.absoluteString)")
#endif
	}

	var body: some View {
		let lightColor = self.lightColor(vm.status)
		let imageName = self.imageName(vm.status)

		GeometryReader { geometry in
			RoundedRectangle(cornerRadius: radius)
				.fill(self.selected ? selectedSystemFill : secondarySystemFill, strokeBorder: .white, lineWidth: 0.2)
				.overlay {
					VStack(spacing: 0) {
						VStack(spacing: 6) {
							HStack(alignment: .center, spacing: 8) {
								GlossyCircle(color: lightColor)
									.frame(width: 12, height: 12)

								Text(vm.name)
									.font(.system(size: 14, weight: .semibold))
									.lineLimit(1)
								Spacer()

								Button(action: action) {
									Image(systemName: imageName)
										.font(.system(size: 14, weight: .medium))
								}
								.buttonStyle(.borderless)
								.labelsHidden()
							}
							.padding(.horizontal, 12)
							.padding(.top, 10)

							HStack(spacing: 10) {
								Spacer()
								statBadge(systemImage: "cpu", value: "\(vm.cpuCount) vCPU")
								statBadge(systemImage: "internaldrive", value: vm.humanReadableDiskSize)
								statBadge(systemImage: "memorychip", value: vm.humanReadableMemorySize)
								Spacer()
							}
							.padding(.bottom, 8)
						}
						.background(
							UnevenRoundedRectangle(
								topLeadingRadius: radius,
								bottomLeadingRadius: 0,
								bottomTrailingRadius: 0,
								topTrailingRadius: radius
							)
							.fill(lightColor.opacity(0.10))
						)

						GeometryReader { geom in
							ZStack {
								Group {
									if let screenshot = self.screenshot {
										Image(nsImage: screenshot)
											.resizable()
											.blur(radius: 8)
											.aspectRatio(contentMode: .fill)
									} else {
										LinearGradient(
											colors: [Color(white: 0.12), Color(white: 0.05)],
											startPoint: .top,
											endPoint: .bottom
										)
									}
								}
								.frame(size: geom.size)
								.clipped()

								vm.osImage.frame(width: 72, height: 72)
							}
							.frame(size: geom.size)
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity)
						.clipShape(
							UnevenRoundedRectangle(
								topLeadingRadius: 0,
								bottomLeadingRadius: radius,
								bottomTrailingRadius: radius,
								topTrailingRadius: 0
							)
						)
					}
					.frame(size: geometry.size)
				}
				.clipShape(RoundedRectangle(cornerRadius: radius))
				.frame(size: geometry.size)
				.withGlassEffect(GlassEffect.regular(nil, nil), in: RoundedRectangle(cornerRadius: radius))
				.onReceive(VirtualMachineDocument.NewScreenshot) { notification in
					if let screenshot: Data = self.vm.issuedNotificationFromDocument(notification) {
						self.screenshot = NSImage(data: screenshot)
					}
				}
		}
		.contextMenu {
			Button("Open") {
				self.open()
			}
			Divider()
			
			if self.vm.status == .paused {
				Button("Resume") {
					self.vm.resumeFromUI()
				}
			} else {
				Button("Start") {
					self.vm.startFromUI()
				}.disabled(self.vm.status.isRunning)
			}

			Button("Stop") {
				self.vm.stopFromUI(force: vm.status != .running || NSEvent.modifierFlags.contains(.option))
			}.disabled(self.vm.status.isStopped)

			Button("Pause") {
				self.vm.suspendFromUI()
			}.disabled(self.vm.status != .running)

			Divider()
			Button("Duplicate") {
				self.vm.duplicateVirtualMachine()
			}.disabled(self.vm.status.isRunning)

			Button("Delete VM") {
				self.vm.deleteVirtualMachine()
			}.disabled(vm.status.isRunning)
		}

	}

	@ViewBuilder
	func statBadge(systemImage: String, value: String) -> some View {
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

	func open() {
		func showError(error: Error) {
			_ = Utilities.group.next().makeFutureWithTask {
				await alertError(error)
			}
		}

		let result = Utilities.group.next().makeFutureWithTask {
			await MainApp.app.openVirtualMachine(vm.url)
		}
		
		result.whenFailure { error in
			showError(error: error)
		}
	}

	func action() {
		switch vm.status {
		case .running, .starting, .stopping, .pausing:
			self.vm.stopFromUI(force: vm.status != .running || NSEvent.modifierFlags.contains(.option))
		case .stopped, .paused:
			self.vm.startFromUI()
		default:
			break
		}
	}

	func imageName(_ status: VirtualMachineDocument.Status) -> String {
		switch status {
		case .starting:
			return "memories"
		case .running:
			return "stop.fill"
		case .stopping:
			return "play.fill"
		case .stopped:
			return "play.fill"
		case .pausing:
			return "arrow.down.circle.badge.pause"
		case .paused:
			return "pause.fill"
		case .error:
			return "exclamationmark.triangle"
		case .resuming, .restoring:
			return "square.and.arrow.up"
		case .saving:
			return "square.and.arrow.down"
		default:
			return "questionmark.circle.fill"
		}
	}

	func lightColor(_ status: VirtualMachineDocument.Status) -> Color {
		switch status {
		case .starting:
			return Color.orange
		case .running:
			return Color.green
		case .stopping:
			return Color.brown
		case .stopped:
			return Color.red
		case .paused, .pausing:
			return Color.yellow
		default:
			return Color.systemGray3
		}
	}
}

#Preview {
	VirtualMachineView(.init(AppState.shared.documents.first!), selected: false)
}
