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
	@Binding private var vm: VirtualMachineDocument
	@State var screenshot: NSImage?

#if DEBUG
	let tracker: TrackDealloc
#endif

	init(_ vm: Binding<VirtualMachineDocument>, selected: Bool) {
		let lastScreenshot = vm.wrappedValue.lastScreenshot

		self._vm = vm
		self.selected = selected
		self._screenshot = State(initialValue: lastScreenshot)
#if DEBUG
		self.tracker = TrackDealloc(from: "VirtualMachineView \(vm.wrappedValue.url.absoluteString)")
#endif
	}

	var body: some View {
		let lightColor = self.lightColor(vm.status)
		let imageName = self.imageName(vm.status)

		GeometryReader { geometry in
			RoundedRectangle(cornerRadius: radius)
				.fill(self.selected ? selectedSystemFill : secondarySystemFill, strokeBorder: .white, lineWidth: 0.2)
				.overlay {
					VStack {
						HStack(alignment: .center) {
							GlossyCircle(color: lightColor)
								.frame(width: 14, height: 14)

							Text("\(vm.name)").font(.headline)
							Spacer()

							Button(action: action) {
								Image(systemName: imageName)
									.font(.headline)
							}
							.buttonStyle(.borderless)
							.labelsHidden()
						}
						.padding(EdgeInsets(top: 4, leading: 10, bottom: 0, trailing: 10))
						.frame(width: geometry.size.width)

						HStack {
							Spacer()
							Label("\(vm.virtualMachineConfig.cpuCount)", systemImage: "cpu")
								.font(.headline)
								.foregroundStyle(Color.secondary)
							Label("\(vm.virtualMachineConfig.humanReadableDiskSize)", systemImage: "internaldrive")
								.font(.headline)
								.foregroundStyle(Color.secondary)
							Label("\(vm.virtualMachineConfig.humanReadableMemorySize)", systemImage: "memorychip")
								.font(.headline)
								.foregroundStyle(Color.secondary)
							Spacer()
						}
						.frame(width: geometry.size.width, height: 20)

						HStack {
							GeometryReader { geom in
								if let screenshot = self.screenshot {
									Rectangle()
										.fill(.black)
										.frame(size: geom.size)
										.overlay {
											Image(nsImage: screenshot)
												.resizable()
												.blur(radius: 8)
												.aspectRatio(contentMode: .fit)
												.scaledToFit()
										}.clipped()
								} else {
									Rectangle()
										.fill(.black)
										.frame(size: geom.size)
								}
							}
						}.overlay {
							self.vm.osImage.frame(size: CGSize(width: 64, height: 64))
						}
						.padding(10)
						.frame(width: geometry.size.width, height: geometry.size.height * 0.75)
					}
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
			Button("Start") {
				self.vm.startFromUI()
			}.disabled(self.vm.status.isRunning)

			Button("Stop") {
				self.vm.stopFromUI(force: vm.status != .running)
			}.disabled(self.vm.status.isStopped)

			Button("Pause") {
				self.vm.suspendFromUI()
			}.disabled(self.vm.status != .running)

			Divider()
			Button("Duplicate") {
				AppState.shared.duplicateVirtualMachine(document: self.vm)
			}.disabled(self.vm.status.isRunning)

			Button("Delete VM") {
				AppState.shared.deleteVirtualMachine(document: self.vm)
			}.disabled(vm.status.isRunning)
		}

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
			self.vm.stopFromUI(force: vm.status != .running)
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
	VirtualMachineView(.constant(AppState.shared.virtualMachines.first!.value), selected: false)
}
