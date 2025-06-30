//
//  VirtualMachineWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/06/2025.
//

import SwiftUI
import Steps
import NIO

struct VirtualMachineWizard: View {
	struct ItemView {
		var title: String
		var image: Image?
		
		init(title: String, image: Image?) {
			self.title = title
			self.image = image
		}
	}

	@State private var selectedIndex: Int = 0
	@State private var config: VirtualMachineConfig = .init()
	@State private var imageName: String? = nil

	private let items: [ItemView]
	private let stepsState: StepsState<ItemView>

	init() {
		self.items = [
			ItemView(title: "Name", image: Image(systemName: "character.cursor.ibeam")),
			ItemView(title: "Choose OS", image: Image(systemName: "cloud")),
			ItemView(title: "CPU & Memory", image: Image(systemName: "cpu")),
			ItemView(title: "Sharing directory", image: Image(systemName: "folder.badge.plus")),
			ItemView(title: "Additional disk", image: Image(systemName: "externaldrive.badge.plus")),
			ItemView(title: "Network attachement", image: Image(systemName: "network")),
			ItemView(title: "Forwarded ports", image: Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")),
			ItemView(title: "Sockets endpoint", image: Image(systemName: "powerplug"))
		]

		self.stepsState = StepsState(data: items)
	}

	var body: some View {
		VStack(spacing: 12) {
			Steps(state: stepsState) {
					return Step(title: $0.title, image: $0.image)
				}
				.onSelectStepAtIndex { index in
					stepsState.setStep(index)
					selectedIndex = index
				}
				.itemSpacing(20)
				.size(20)
				.font(.caption)
				.padding()
			Divider()
			Form {
				switch selectedIndex {
				case 0:
					TextField("Virtual machine name", value: $config.vmname, format: .optional)
				case 1:
					TextField("OS Image", value: $imageName, format: .optional)
				case 2:
					generalSettings()
				case 3:
					mountsView()
				case 4:
					diskAttachementView()
				case 5:
					networksView()
				case 6:
					forwardPortsView()
				case 7:
					socketsView()
				default:
					EmptyView()
				}
			}
			.animation(.easeInOut)
			Spacer()
			Divider()
			HStack(alignment: .bottom) {
				Spacer()
				Button {
					stepsState.nextStep()
					selectedIndex = stepsState.currentIndex
				} label: {
					Text("Next").frame(width: 80)
				}
				.disabled(!stepsState.hasNext)
				Spacer()
				Button {
					stepsState.previousStep()
					selectedIndex = stepsState.currentIndex
				} label: {
					Text("Previous").frame(width: 80)
				}
				.disabled(!stepsState.hasPrevious)
				Spacer()
			}
		}.padding().frame(height: 800)
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
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
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
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
				}
				HStack {
					Text("Height")
					Spacer().border(.black)
					TextField("", value: $config.display.height, format: .number)
						.frame(width: 50)
						.multilineTextAlignment(.center)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
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
    VirtualMachineWizard()
}
