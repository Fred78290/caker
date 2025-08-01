//
//  VirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/07/2025.
//

import SwiftUI

struct VirtualMachineView: View {
	@Binding var vm: VirtualMachineDocument

	var body: some View {
		Group {
			HStack(alignment: .center) {
				Circle()
					.strokeBorder(.gray, lineWidth: 1)
					.background(Circle().foregroundColor(lightColor()))
					.frame(width: 15, height: 15)
				Text("\(vm.name)").font(.title)
				Spacer()
				Button(action: action) {
					Image(systemName: imageName())
						.frame(width: 15, height: 15).scaledToFill()
				}
				.buttonStyle(.borderless)
				.labelsHidden()
			}
		}.padding()
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

	VirtualMachineView(vm: .constant(appState.vms.first!.document))
}
