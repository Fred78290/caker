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

struct VirtualMachineSettingsView: View {
	var vmname: String?
	@Environment(\.dismiss) var dismiss
	@State var selectedOption: Int? = 0
	@State var selectedImageSize: Int? = 0
	@State var playSound: Bool = false
	@State var readReceipt: Bool = false

	@State var cpuCount: Int
	@State var memorySize: UInt64
	@State var macAddress: String

	@State var autostart: Bool
	@State var suspendable: Bool
	@State var dynamicPortForwarding: Bool
	@State var displayRefit: Bool
	@State var nestedVirtualization: Bool
	@State var display: ViewSize
	@State var forwardPorts: [TunnelAttachement]
	@State var sockets: [SocketDevice]
	@State var networks: [BridgeAttachement]
	@State var attachedDisks: [DiskAttachement]
	@State var mounts: [DirectorySharingAttachment]
	@State var configChanged = false
	var config: CakeConfig? = nil

	struct ViewSize: Identifiable, Hashable {
		var id: Int {
			width * height
		}
		var width: Int
		var height: Int

		init(width: Int, height: Int) {
			self.width = width
			self.height = height
		}
	}

	init(vmname: String? = nil) {
		var cpuCount: Int = 0
		var memorySize: UInt64 = 0
		var macAddress: String = ""
		var autostart = false
		var suspendable = false
		var dynamicPortForwarding = false
		var displayRefit = false
		var nestedVirtualization = false
		var display = ViewSize(width: 800, height: 600)
		var forwardPorts: [TunnelAttachement] = []
		var sockets: [SocketDevice] = []
		var networks: [BridgeAttachement] = []
		var attachedDisks: [DiskAttachement] = []
		var mounts: [DirectorySharingAttachment] = []
		self.vmname = vmname

		if let vmname = vmname, let vmLocation = try? StorageLocation(runMode: .app).find(vmname) {
			self.config = try? vmLocation.config()

			if let config = self.config {
				cpuCount = config.cpuCount
				memorySize = config.memorySize / (1024 * 1024)
				macAddress = config.macAddress?.string ?? ""
				autostart = config.autostart
				suspendable = config.suspendable
				dynamicPortForwarding = config.dynamicPortForwarding
				displayRefit = config.displayRefit
				nestedVirtualization = config.nestedVirtualization
				display = ViewSize(width: config.display.width, height: config.display.height)
				forwardPorts = config.forwardedPorts
				sockets = config.sockets
				networks = config.networks
				attachedDisks = config.attachedDisks
				mounts = config.mounts
			}
		}

		self.cpuCount = cpuCount
		self.memorySize = memorySize
		self.macAddress = macAddress
		self.autostart = autostart
		self.suspendable = suspendable
		self.dynamicPortForwarding = dynamicPortForwarding
		self.displayRefit = displayRefit
		self.nestedVirtualization = nestedVirtualization
		self.display = display
		self.forwardPorts = forwardPorts
		self.sockets = sockets
		self.networks = networks
		self.attachedDisks = attachedDisks
		self.mounts = mounts
	}

	var body: some View {
		if self.vmname != nil {
			if self.config != nil {
				VStack {
					TabView {
						generalSettings().tabItem {
							Label("General", systemImage: "gearshape")
						}

						networkSettings().tabItem {
							Label("Network", systemImage: "network")
						}

						mediaSettings().tabItem {
							Label("Disk", systemImage: "externaldrive.badge.wifi")
						}
					}
					.padding(.top)
					.navigationTitle("Settings")

					Spacer()
					Divider()

					HStack(alignment: .bottom) {
						Spacer()
						Button("Cancel") {
							// Cancel saving and dismiss.
							dismiss()
						}
						Spacer()
						Button("Save") {
							// Save the article and dismiss.
							try? self.config?.save()
							dismiss()
						}.disabled(self.configChanged == false)
						Spacer()
					}.frame(width: 200).padding(.bottom)
				}.frame(height: 600)
			} else {
				Text("Failed to load vm settings")
			}
		} else {
			Text("No Virtual machine selected")
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
				self.diskAttachementView()
				self.mountsView()
			}.formStyle(.grouped)
		}.frame(maxHeight: .infinity)
	}

	func cpuCountAndMemoryView() -> some View {
		Section("CPU & Memory") {
			let cpuRange = 1...System.coreCount
			let totalMemoryRange = 1...ProcessInfo().physicalMemory / 1024 / 1024

			Picker("CPU count", selection: $cpuCount) {
				ForEach(cpuRange, id: \.self) { cpu in
					if cpu == 1 {
						Text("\(cpu) core").tag(cpu)
					} else {
						Text("\(cpu) cores").tag(cpu)
					}
				}
			}
			.onChange(of: cpuCount) { newValue in
				config?.cpuCount = newValue
				configChanged = true
			}

			HStack {
				Text("Memory size")
				Spacer().border(.black)
				HStack {
					TextField("", value: $memorySize, format: .number)
						.frame(width: 50)
						.multilineTextAlignment(.center)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
					Stepper(value: $memorySize, in: totalMemoryRange, step: 1) {

					}.labelsHidden()
				}
			}
			.onChange(of: memorySize) { newValue in
				config?.memorySize = newValue * (1024 * 1024)
				configChanged = true
			}
		}
	}

	func optionsView() -> some View {
		Section("Options") {
			VStack(alignment: .leading) {
				Toggle("Autostart", isOn: $autostart)
				Toggle("Suspendable", isOn: $suspendable)
				Toggle("Dynamic forward ports", isOn: $dynamicPortForwarding)
				Toggle("Refit display", isOn: $displayRefit)
				Toggle("Nested virtualization", isOn: $nestedVirtualization)
			}
		}
		.onChange(of: autostart) { newValue in
			config?.autostart = newValue
			configChanged = true
		}
		.onChange(of: suspendable) { newValue in
			config?.suspendable = newValue
			configChanged = true
		}
		.onChange(of: dynamicPortForwarding) { newValue in
			config?.dynamicPortForwarding = newValue
			configChanged = true
		}
		.onChange(of: displayRefit) { newValue in
			config?.displayRefit = newValue
			configChanged = true
		}
		.onChange(of: nestedVirtualization) { newValue in
			config?.nested = newValue
			configChanged = true
		}
	}

	func displaySizeView() -> some View {
		Section("Display size") {
			VStack(alignment: .leading) {
				TextField("Width", value: $display.width, format: .number)
				TextField("Height", value: $display.height, format: .number)
			}
		}
		.onChange(of: display) { newValue in
			config?.display = DisplaySize(width: newValue.width, height: newValue.height)
			configChanged = true
		}
	}

	func forwardPortsView() -> some View {
		Section("Forwarded ports") {
			ForwardedPortView(forwardPorts: $forwardPorts)
				.onChange(of: forwardPorts) { newValue in
					config?.forwardedPorts = newValue
					configChanged = true
				}
		}
	}

	func networksView() -> some View {
		Section("Network attachements") {
			NetworkAttachementView(networks: $networks)
				.onChange(of: networks) { newValue in
					config?.networks = newValue
					configChanged = true
				}
		}
	}

	func mountsView() -> some View {
		Section("Directory sharing") {
			MountView(mounts: $mounts)
				.onChange(of: mounts) { newValue in
					config?.mounts = newValue
					configChanged = true
				}
		}
	}

	func diskAttachementView() -> some View {
		Section("Disks attachements") {
			DiskAttachementView(attachedDisks: $attachedDisks)
				.onChange(of: attachedDisks) { newValue in
					config?.attachedDisks = newValue
					configChanged = true
				}
		}
	}

	func socketsView() -> some View {
		Section("Virtual sockets") {
			SocketsView(sockets: $sockets)
				.onChange(of: sockets) { newValue in
					config?.sockets = newValue
					configChanged = true
				}
		}
	}
}

#Preview {
	VirtualMachineSettingsView(vmname: "linux")
}
