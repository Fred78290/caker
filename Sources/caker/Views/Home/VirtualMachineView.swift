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
					Image(systemName: "circle.fill")
						.font(.headline)
						.foregroundColor(lightColor())
					
					Text("\(vm.name)")
						.font(.headline)
					
					Spacer()
					
					Button(action: action) {
						Image(systemName: imageName())
							.font(.headline)
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
					self.vm.screenshot.image
				}
				.padding(10)
				.frame(width: geometry.size.width, height: geometry.size.height * 0.75)

			}
			.background(Material.bar)
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
			return Color.systemGray3
		}
	}
}

#Preview {
	let appState = AppState()

	VirtualMachineView(vm: appState.virtualMachines.first!.value)
}
