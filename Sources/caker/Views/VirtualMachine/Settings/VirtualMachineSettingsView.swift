//
//  VirtualMachineSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/06/2025.
//

import CakedLib
import GRPCLib
import NIO
import SwiftUI
import Virtualization
import MultiplatformTabBar

struct VirtualMachineSettingsView: View {
	@Environment(\.dismiss) var dismiss

	@Binding var config: VirtualMachineConfig
	@State var configChanged = false

	init(config: Binding<VirtualMachineConfig>) {
		_config = config
	}

	var body: some View {
		VStack {
			MultiplatformTabBar(tabPosition: .top, barHorizontalAlignment: .center)
				.tab(title: "General", icon: Image(systemName: "gearshape")) {
					generalSettings()
				}
				.tab(title: "Network", icon: Image(systemName: "network")) {
					networkSettings()
				}
				.tab(title: "Disk", icon: Image(systemName: "externaldrive.badge.wifi")) {
					mediaSettings()
				}
			
			Spacer()
			Divider()
			
			HStack(alignment: .bottom) {
				Spacer()
				
				Button {
					dismiss()
				} label: {
					Text("Cancel")
						.frame(width: 60)
				}
				.buttonStyle(.borderedProminent)
				
				Spacer()
				
				Button {
					try? self.config.save()
					dismiss()
				} label: {
					Text("Save")
						.frame(width: 60)
				}
				.buttonStyle(.bordered)
				.disabled(self.configChanged == false)
				
				Spacer()
			}
			.frame(width: 200)
			.padding(.bottom)
			
		}
		.frame(height: 600)
		.onChange(of: config) { newValue in
			self.configChanged = true
		}
	}

	func generalSettings() -> some View {
		VStack {
			Form {
				self.cpuCountAndMemoryView()
				self.optionsView()
				self.displaySizeView()
			}.formStyle(.grouped)
		}.frame(maxHeight: .infinity)
	}

	func networkSettings() -> some View {
		VStack {
			Form {
				self.networksView()
				self.forwardPortsView()
				self.socketsView()
			}.formStyle(.grouped)
		}.frame(maxHeight: .infinity)
	}

	func mediaSettings() -> some View {
		VStack {
			Form {
				self.mountsView()
				self.diskAttachementView()
			}.formStyle(.grouped)
		}.frame(maxHeight: .infinity)
	}

	func cpuCountAndMemoryView() -> some View {
		Section("CPU & Memory") {
			let cpuRange = 1...System.coreCount
			let totalMemoryRange = 1...ProcessInfo().physicalMemory / 1024 / 1024

			Picker("CPU count", selection: $config.cpuCount) {
				ForEach(cpuRange, id: \.self) { cpu in
					if cpu == 1 {
						Text("\(cpu) core").tag(cpu)
					} else {
						Text("\(cpu) cores").tag(cpu)
					}
				}
			}

			HStack {
				Text("Memory size")
				Spacer().border(.black)
				HStack {
					TextField("", value: $config.memorySize, format: .number)
						.frame(width: 50)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
					Stepper(value: $config.memorySize, in: totalMemoryRange, step: 1) {

					}.labelsHidden()
				}
			}
		}
	}

	func optionsView() -> some View {
		Section("Options") {
			VStack(alignment: .leading) {
				Toggle("Autostart", isOn: $config.autostart)
				Toggle("Suspendable", isOn: $config.suspendable)
				Toggle("Dynamic forward ports", isOn: $config.dynamicPortForwarding)
				Toggle("Refit display", isOn: $config.displayRefit)
				Toggle("Nested virtualization", isOn: $config.nestedVirtualization)
			}
		}
	}

	func displaySizeView() -> some View {
		Section("Display size") {
			VStack(alignment: .leading) {
				HStack {
					Text("Width")
					Spacer().border(.black)
					TextField("", value: $config.display.width, format: .number)
						.frame(width: 50)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
				}
				HStack {
					Text("Height")
					Spacer().border(.black)
					TextField("", value: $config.display.height, format: .number)
						.frame(width: 50)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
				}
			}
		}
	}

	func forwardPortsView() -> some View {
		Section("Forwarded ports") {
			ForwardedPortView(forwardPorts: $config.forwardPorts)
		}
	}

	func networksView() -> some View {
		Section("Network attachements") {
			NetworkAttachementView(networks: $config.networks)
		}
	}

	func mountsView() -> some View {
		Section("Directory sharing") {
			MountView(mounts: $config.mounts)
		}
	}

	func diskAttachementView() -> some View {
		Section("Disks attachements") {
			DiskAttachementView(attachedDisks: $config.attachedDisks)
		}
	}

	func socketsView() -> some View {
		Section("Virtual sockets") {
			SocketsView(sockets: $config.sockets)
		}
	}
}

#Preview {
	VirtualMachineSettingsView(config: .constant(.init()))
}
