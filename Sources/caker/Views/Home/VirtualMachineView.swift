//
//  VirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/07/2025.
//

import SwiftUI

extension Shape {
	func fill<Fill: ShapeStyle, Stroke: ShapeStyle>(_ fillStyle: Fill, strokeBorder strokeStyle: Stroke, lineWidth: Double = 1) -> some View {
		if #available(macOS 26.0, *) {
			return self
				.fill(fillStyle)
				.background(fillStyle)
		} else {
			return self
				.fill(fillStyle)
				.stroke(strokeStyle, lineWidth: lineWidth)
				.background(fillStyle)
		}
	}
}

struct VirtualMachineView: View {
	@Environment(\.appearsActive) var appearsActive
	@Environment(\.materialActiveAppearance) var materialActiveAppearance

	var selected: Bool
	@StateObject var vm: VirtualMachineDocument
	private let radius: CGFloat = 12
	private let secondarySystemFill = Color(NSColor.tertiarySystemFill)

	var body: some View {
		let lightColor = self.lightColor(vm.status)
		let imageName = self.imageName(vm.status)

		GeometryReader { geometry in
			RoundedRectangle(cornerRadius: radius)
				.fill(self.selected ? Color.secondary : secondarySystemFill, strokeBorder: .white, lineWidth: 0.2)
				.overlay {
					VStack {
						HStack(alignment: .center) {
							ZStack {
								Circle()
									.fill(lightColor)
									.frame(width: 14, height: 14)
									.overlay(
										Circle()
											.stroke(.white, lineWidth: 0.5)
											.fill(
												RadialGradient(
													gradient: Gradient(colors: [Color.white.opacity(0.85), Color.white.opacity(0.0)]),
													center: .topLeading,
													startRadius: 0,
													endRadius: 16
												)
											)
											.blendMode(.screen)
									)
							}
							
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
							self.vm.screenshot.image
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
		case .running, .starting:
			return "stop.fill"
		case .stopped, .stopping:
			return "play.fill"
		case .paused, .pausing:
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
		case .running, .starting:
			return Color.green
		case .stopped, .stopping:
			return Color.red
		case .paused, .pausing:
			return Color.yellow
		default:
			return Color.systemGray3
		}
	}
}

#Preview {
	let appState = AppState()

	VirtualMachineView(selected: false, vm: appState.virtualMachines.first!.value)
}
