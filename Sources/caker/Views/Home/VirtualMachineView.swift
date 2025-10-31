//
//  VirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/07/2025.
//

import SwiftUI

struct VirtualMachineView: View {
	@State var vm: VirtualMachineDocument

	var body: some View {
		GeometryReader { geometry in
			VStack {
				HStack(alignment: .center) {
					Circle()
						.strokeBorder(.gray, lineWidth: 1)
						.background(Circle().foregroundColor(lightColor()))
						.frame(width: 12, height: 12)
					Text("\(vm.name)").font(.headline)
					Spacer()
					Button(action: action) {
						Image(systemName: imageName())
							.frame(width: 15, height: 15).scaledToFill()
					}
					.buttonStyle(.borderless)
					.labelsHidden()
				}
				.padding(4)
				.frame(width: geometry.size.width)
				
				HStack {
					Spacer()
					Label("\(vm.virtualMachineConfig.cpuCount)", systemImage: "cpu")
						.font(.caption)
						.foregroundStyle(Color.secondary)
					Label("\(vm.virtualMachineConfig.humanReadableDiskSize)", systemImage: "internaldrive")
						.font(.caption)
						.foregroundStyle(Color.secondary)
					Label("\(vm.virtualMachineConfig.humanReadableMemorySize)", systemImage: "memorychip")
						.font(.caption)
						.foregroundStyle(Color.secondary)
					Spacer()
				}
				.frame(width: geometry.size.width, height: 20)
				
				HStack {
					self.vm.screenshot()
						.scaledToFit()
				}
				.padding(10)
				.background(Color.red)
				.frame(width: geometry.size.width, height: geometry.size.height * 0.75)

			}
			.background(Color.systemGray6)
			.clipShape(RoundedRectangle(cornerRadius: 8))
			.frame(size: geometry.size)
		}
	}

	func action() {

	}

	func imageName() -> String {
		switch vm.status {
		case .running, .starting:
			return "stop.fill"
		case .stopped, .stopping:
			return "play.fill"
		case .paused, .pausing:
			return "pause.fill"
		default:
			return "questionmark.circle.fill"
		}
	}

	func lightColor() -> Color {
		switch vm.status {
		case .running, .starting:
			return Color.green
		case .stopped, .stopping:
			return Color.red
		case .paused, .pausing:
			return Color.yellow
		default:
			return Color(red: 192, green: 192, blue: 192)
		}
	}
}

#Preview {
	let appState = AppState()

	VirtualMachineView(vm: appState.vms.first!.document)
}
