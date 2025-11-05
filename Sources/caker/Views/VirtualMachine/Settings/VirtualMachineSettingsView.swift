//
//  VirtualMachineSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/06/2025.
//

import CakedLib
import GRPCLib
//import MultiplatformTabBar
import NIO
import SwiftUI
import Virtualization

struct VirtualMachineSettingsView: View {

	@Environment(\.dismiss) var dismiss

	enum SettingsTab: Int, MultiplatformTabIdentifier {
		static func < (lhs: VirtualMachineSettingsView.SettingsTab, rhs: VirtualMachineSettingsView.SettingsTab) -> Bool {
			lhs.rawValue < rhs.rawValue
		}
		
		var id: Int {
			self.rawValue
		}
		
		case account
		case general
		case network
		case ports
		case sockets
		case sharing
		case storage
	}

	@Binding var config: VirtualMachineConfig
	@State var configChanged = false
	@State var selectedTab: SettingsTab = .account
	@State var showPassword = false
	@State var userPassword: String

	init(config: Binding<VirtualMachineConfig>) {
		self._config = config
		self.userPassword = config.wrappedValue.configuredPassword ?? ""
	}

	var body: some View {
		VStack {
			MultiplatformTabBar(selection: $selectedTab, tabPosition: .top, barHorizontalAlignment: .center)
				.tab(title: "Account", systemName: "person.badge.key", tag: .account) {
					self.userSettings()
				}
				.tab(title: "General", systemName: "cpu", tag: .general) {
					self.generalSettings()
				}
				.tab(title: "Network", systemName: "network", tag: .network) {
					self.networksView()
				}
				.tab(title: "Ports", systemName: "point.bottomleft.forward.to.point.topright.scurvepath", tag: .ports) {
					self.forwardPortsView()
				}
				.tab(title: "Sockets", systemName: "powerplug", tag: .sockets) {
					self.socketsView()
				}
				.tab(title: "Sharing", systemName: "folder.badge.plus", tag: .sharing) {
					self.mountsView()
				}
				.tab(title: "Disk", systemName: "externaldrive.badge.plus", tag: .storage) {
					self.diskAttachementView()
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
		.onChange(of: config) { _, newValue in
			self.configChanged = true
		}
	}

	func userSettings() -> some View {
		VStack {
			Form {
				Section("Administrator settings") {
					LabeledContent("Administator name") {
						TextField("User name", text: $config.configuredUser)
							.rounded(.leading)
					}
					
					LabeledContent("Administator password") {
						HStack {
							if self.showPassword {
								TextField("Password", value: $config.configuredPassword, format: .optional)
									.rounded(.leading)
							} else {
								SecureField("Password", text: $userPassword)
									.rounded(.leading)
									.onChange(of: userPassword) { _, newValue in
										if newValue.isEmpty {
											config.configuredPassword = nil
										} else {
											config.configuredPassword = newValue
										}
									}
							}
						}.overlay(alignment: .trailing) {
							Image(systemName: self.showPassword ? "eye.fill" : "eye.slash.fill")
								.padding()
								.onTapGesture {
									self.showPassword.toggle()
								}
						}
					}
				}
			}.formStyle(.grouped)
		}.frame(maxHeight: .infinity)
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
					TextField("", value: $config.memorySize, format: .number /*.memory(.useGB)*/)
						.rounded(.center)
						.frame(width: 50)
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
						.rounded(.center)
						.frame(width: 50)
				}
				HStack {
					Text("Height")
					Spacer().border(.black)
					TextField("", value: $config.display.height, format: .number)
						.rounded(.center)
						.frame(width: 50)
				}
			}
		}
	}

	func forwardPortsView() -> some View {
		Form {
			Section("Forwarded ports") {
				ForwardedPortView(forwardPorts: $config.forwardPorts, disabled: .constant(false)).frame(height: 380)
			}
		}.formStyle(.grouped).frame(maxHeight: .infinity)
	}

	func networksView() -> some View {
		Form {
			Section("Network attachements") {
				NetworkAttachementView(networks: $config.networks, disabled: .constant(false)).frame(height: 380)
			}
		}.formStyle(.grouped).frame(maxHeight: .infinity)
	}

	func mountsView() -> some View {
		Form {
			Section("Directory sharing") {
				MountView(mounts: $config.mounts, disabled: .constant(false)).frame(height: 380)
			}
		}.formStyle(.grouped).frame(maxHeight: .infinity)
	}

	func diskAttachementView() -> some View {
		Form {
			Section("Disks attachements") {
				DiskAttachementView(attachedDisks: $config.attachedDisks, disabled: .constant(false)).frame(height: 380)
			}
		}.formStyle(.grouped).frame(maxHeight: .infinity)
	}

	func socketsView() -> some View {
		Form {
			Section("Virtual sockets") {
				SocketsView(sockets: $config.sockets, disabled: .constant(false)).frame(height: 380)
			}
		}.formStyle(.grouped).frame(maxHeight: .infinity)
	}
}

#Preview {
	VirtualMachineSettingsView(config: .constant(.init()))
}
