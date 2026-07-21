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

	@State var document: VirtualMachineDocument
	@State var config: VirtualMachineConfig
	@State var configChanged = false
	@State var selectedTab: SettingsTab = .account
	@State var showPassword = false
	@State var userPassword: String
	@State var noRootDisk: Bool
	@State var mountPoints: MountPoints
	@State var diskSizeInGiB: Int

	private let initialDiskSize: Int

	init() {
		let document = try! VirtualMachineDocument.anyVirtualMachineDocument()
		let config = document.virtualMachineConfig

		self.initialDiskSize = Int(config.diskSizeInGiB)
		self.diskSizeInGiB = Int(config.diskSizeInGiB)
		self.document = document
		self.config = config
		self.userPassword = config.configuredPassword ?? String.empty
		self.noRootDisk = (config.rootDisk ?? "").isEmpty
		self.mountPoints = config.mounts.map {
			MountPoint($0)
		}
	}

	init(document: VirtualMachineDocument) {
		let config = document.virtualMachineConfig

		self.initialDiskSize = Int(config.diskSizeInGiB)
		self.diskSizeInGiB = Int(config.diskSizeInGiB)
		self.document = document
		self.config = config
		self.userPassword = config.configuredPassword ?? String.empty
		self.noRootDisk = (config.rootDisk ?? "").isEmpty
		self.mountPoints = config.mounts.map {
			MountPoint($0)
		}
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

			Divider()

			HStack(spacing: 8) {
				Spacer()

				Button {
					dismiss()
				} label: {
					Text("Cancel")
						.frame(width: 80)
				}
				.buttonStyle(.bordered)

				Button {
					self.document.virtualMachineConfig = self.config
					AppState.shared.saveConfiguration(document: self.document)
					dismiss()
				} label: {
					Text("Save")
						.frame(width: 80)
				}
				.buttonStyle(.borderedProminent)
				.disabled(self.configChanged == false)
			}
			.padding(.horizontal, 16)
			.padding(.vertical, 12)

		}
		.frame(minHeight: 630)
		.onChange(of: config) { _, newValue in
			self.configChanged = true
		}
		.onChange(of: mountPoints) { _, newValue in
			self.config.mounts = newValue.map { $0.directorySharingAttachment }
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
		return Section(self.noRootDisk ? "CPU & Memory & Disk" : "CPU & Memory") {
			let cpuRange: ClosedRange<UInt16> = 1...UInt16(System.coreCount)
			let memoryLowerBound: UInt64 = config.os == .darwin ? 4096 : 512
			let memoryUpperBound: UInt64 = max(memoryLowerBound, ProcessInfo().physicalMemory / MoB)
			let totalMemoryRange: ClosedRange<UInt64> = memoryLowerBound...memoryUpperBound

			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text("CPU count")
					Spacer()
					if config.cpuCount == 1 {
						Text("1 core")
							.monospacedDigit()
							.foregroundStyle(Color.secondary)
					} else {
						Text("\(config.cpuCount) cores")
							.monospacedDigit()
							.foregroundStyle(Color.secondary)
					}
				}
				VStack {
					Slider(
						value: Binding(
							get: { Double($config.cpuCount.wrappedValue) },
							set: { $config.cpuCount.wrappedValue = UInt16($0.rounded()) }
						),
						in: Double(cpuRange.lowerBound)...Double(cpuRange.upperBound),
						step: 1
					) {
						Text("CPU count")
					}
					.labelsHidden()
					HStack {
						Text("\(cpuRange.lowerBound)").font(.caption).foregroundStyle(Color.secondary)
						Spacer()
						Text("\(cpuRange.upperBound)").font(.caption).foregroundStyle(Color.secondary)
					}
				}
			}
			.padding(.vertical, 2)

			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text("Memory size")
					Spacer()
					Text(ByteCountFormatter.string(fromByteCount: Int64(config.memorySize), countStyle: .memory))
						.monospacedDigit()
						.foregroundStyle(Color.secondary)
				}
				VStack {
					Slider(
						value: Binding(
							get: { Double($config.memorySizeInMoB.wrappedValue) },
							set: { $config.memorySizeInMoB.wrappedValue = UInt64($0.rounded()) }
						),
						in: Double(totalMemoryRange.lowerBound)...Double(totalMemoryRange.upperBound),
						step: 256
					) {
						Text("Memory size")
					}
					.labelsHidden()
					HStack {
						Text(ByteCountFormatter.string(fromByteCount: Int64(totalMemoryRange.lowerBound * MoB), countStyle: .memory))
							.font(.caption).foregroundStyle(Color.secondary)
						Spacer()
						Text(ByteCountFormatter.string(fromByteCount: Int64(totalMemoryRange.upperBound * MoB), countStyle: .memory))
							.font(.caption).foregroundStyle(Color.secondary)
					}
				}
			}
			.padding(.vertical, 2)

			if self.noRootDisk {
				HStack {
					let range = RangeIntegerStyle.ranged(Int(max(self.initialDiskSize, self.config.source == .ipsw ? 40 : 5))...2048)

					Text("Disk size (GiB)")
					Spacer()
					TextField(String.empty, value: $diskSizeInGiB, format: range)
						.rounded(.center)
						.frame(width: 50)
						.onChange(of: self.diskSizeInGiB) { _, newValue in
							let minDisk = max(self.initialDiskSize, self.config.source == .ipsw ? 40 : 5)
							let clamped = min(max(newValue, minDisk), 2048)

							self.diskSizeInGiB = clamped
							config.diskSizeInGiB = UInt64(clamped)
						}
				}
				if Bundle.isApplicationSandboxed && self.config.diskFormat == .asif && self.document.connectionManager.connectionMode != .app {
					Text("Warning resize will not be available in sandboxed mode for asif disk format. If you want to resize the disk, you must use diskutil to resize the disk.").font(.callout).foregroundStyle(Color.red)
				}
			}
		}
	}

	func optionsView() -> some View {
		Section("Options") {
			VStack(alignment: .leading) {
				Toggle("Autostart", isOn: $config.autostart)
				Toggle("Dynamic forward ports", isOn: $config.dynamicPortForwarding)
				Toggle("Refit display", isOn: $config.displayRefit)
				Toggle("Nested virtualization", isOn: $config.nestedVirtualization)

				if config.os == .darwin {
					Toggle("Suspendable", isOn: $config.suspendable)
				}
			}
		}
	}

	func displaySizeView() -> some View {
		Section("Display size") {
			VStack(alignment: .leading) {
				HStack {
					Text("Width")
					Spacer()
					TextField(String.empty, value: $config.display.width, format: .number)
						.rounded(.center)
						.frame(width: 50)
				}
				HStack {
					Text("Height")
					Spacer()
					TextField(String.empty, value: $config.display.height, format: .number)
						.rounded(.center)
						.frame(width: 50)
				}
			}
		}
	}

	func forwardPortsView() -> some View {
		Form {
			Section("Forwarded ports") {
				ForwardedPortView(forwardPorts: $config.forwardedPorts, disabled: .constant(false)).frame(height: 380)
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
				MountView(mounts: $mountPoints, disabled: .constant(false)).frame(height: 380)
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
	VirtualMachineSettingsView()
}
