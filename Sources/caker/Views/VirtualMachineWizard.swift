//
//  VirtualMachineWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/06/2025.
//

import SwiftUI
import Steps
import NIO
import CakedLib
import GRPCLib

typealias OptionalVMLocation = VMLocation?

let groups: [String] = [
	"root",
	"daemon",
	"bin",
	"sys",
	"adm",
	"tty",
	"disk",
	"lp",
	"mail",
	"news",
	"uucp",
	"man",
	"proxy",
	"kmem",
	"dialout",
	"fax",
	"voice",
	"cdrom",
	"floppy",
	"tape",
	"sudo",
	"audio",
	"dip",
	"www-data",
	"backup",
	"operator",
	"list",
	"irc",
	"src",
	"shadow",
	"utmp",
	"video",
	"sasl",
	"plugdev",
	"staff",
	"games",
	"users",
	"nogroup",
	"systemd-journal",
	"systemd-network",
	"crontab",
	"systemd-timesync",
	"input",
	"sgx",
	"kvm",
	"render",
	"messagebus",
	"syslog",
	"systemd-resolve",
	"uuidd",
	"_ssh",
	"rdma",
	"tcpdump",
	"landscape",
	"fwupd-refresh",
	"polkitd",
	"admin",
	"netdev"
]

struct VirtualMachineWizard: View {
	struct ItemView {
		var title: String
		var image: Image?
		
		init(title: String, image: Image?) {
			self.title = title
			self.image = image
		}
	}

	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL

	@State private var selectedIndex: Int = 0
	@State private var config: VirtualMachineConfig = .init()
	@State private var imageName: String = defaultUbuntuImage
	@State private var configValid: Bool = false
	@State private var vmLocation: OptionalVMLocation = nil
	@State private var password: String = ""
	@State private var showPassword: Bool = false

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
				.itemSpacing(25)
				.size(16)
				.font(.caption)
				.padding()
			Divider()
			VStack {
				switch selectedIndex {
				case 0:
					chooseVMName()
				case 1:
					chooseOSImage()
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
			.animation(.easeInOut, value: selectedIndex)
			Spacer()
			Divider()
			HStack(alignment: .bottom) {
				HStack{
				}.frame(maxWidth: .infinity)

				Spacer()
				HStack {
					Button {
						stepsState.previousStep()
						selectedIndex = stepsState.currentIndex
					} label: {
						Text("Previous").frame(width: 80)
					}
					.disabled(!stepsState.hasPrevious)
					Button {
						stepsState.nextStep()
						selectedIndex = stepsState.currentIndex
					} label: {
						Text("Next").frame(width: 80)
					}
					.disabled(!stepsState.hasNext)
				}

				Spacer()
				HStack{
					Spacer()

					AsyncButton($vmLocation) {
						try await createVirtualMachine()
					} label: {
						Text("Create").frame(width: 80)
					}
					.disabled(configValid == false)
				}.frame(maxWidth: .infinity)
			}
		}
		.padding()
		.frame(height: 800)
		.onChange(of: config) { newValue in
			self.validateConfig(config: newValue)
		}
		.onChange(of: vmLocation) { newValue in
			if let location = vmLocation {
				self.openURL(location.rootURL)
				self.dismiss()
			}
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
	
	func cpuCountAndMemoryView() -> some View {
		Section("CPU & Memory & Disk") {
			let cpuRange = 1...System.coreCount
			let diskRange = 5...UInt16.max
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

			HStack {
				Text("Disk size")
				Spacer().border(.black)
				HStack {
					TextField("", value: $config.diskSize, format: .number)
						.frame(width: 50)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
					Stepper(value: $config.diskSize, in: diskRange, step: 1) {
						
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

	func chooseVMName() -> some View {
		Form {
			Section("Virtual machine name") {
				TextField("Virtual machine name", value: $config.vmname, format: .optional)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.onChange(of: config.vmname) { newValue in
						self.validateConfig(config: self.config)
					}
			}

			Section("Administrator settings") {
				LabeledContent("Administator name") {
					TextField("User name", text: $config.configuredUser)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
				}

				LabeledContent("Administator password") {
					HStack {
						if showPassword {
							TextField("Password", text: $password)
								.multilineTextAlignment(.leading)
								.textFieldStyle(.roundedBorder)
								.background(.white)
								.labelsHidden()
								.clipShape(RoundedRectangle(cornerRadius: 6))
						} else {
							SecureField("Password", text: $password)
								.multilineTextAlignment(.leading)
								.textFieldStyle(.roundedBorder)
								.background(.white)
								.labelsHidden()
								.clipShape(RoundedRectangle(cornerRadius: 6))
						}
					}.overlay(alignment: .trailing) {
						Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
						.padding()
						.onTapGesture {
							showPassword.toggle()
						}
					}
				}

				LabeledContent("Administator password") {
					HStack {
						if showPassword {
							TextField("Password", text: $password)
								.multilineTextAlignment(.leading)
								.textFieldStyle(.roundedBorder)
								.background(.white)
								.labelsHidden()
								.clipShape(RoundedRectangle(cornerRadius: 6))
						} else {
							SecureField("Password", text: $password)
								.multilineTextAlignment(.leading)
								.textFieldStyle(.roundedBorder)
								.background(.white)
								.labelsHidden()
								.clipShape(RoundedRectangle(cornerRadius: 6))
						}
					}.overlay(alignment: .trailing) {
						Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
						.padding()
						.onTapGesture {
							showPassword.toggle()
						}
					}
				}

				Toggle("SSH with password", isOn: $config.clearPassword)

				LabeledContent("Administator group") {
					HStack {
						Spacer()
						Picker("Main group", selection: $config.mainGroup) {
							ForEach(groups, id: \.self) { name in
								Text(name).tag(name)
							}
						}
						.labelsHidden()
					}.frame(width: 100)
				}
			}

		}.formStyle(.grouped)
	}

	func chooseOSImage() -> some View {
		Form {
			Section("Choose OS image") {
				TextField("OS Image", text: $imageName)
					.multilineTextAlignment(.leading)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}.formStyle(.grouped)
	}

	func forwardPortsView() -> some View {
		Form {
			Section("Forwarded ports") {
				ForwardedPortView(forwardPorts: $config.forwardPorts)
			}
		}.formStyle(.grouped)
	}

	func networksView() -> some View {
		Form {
			Section("Network attachements") {
				NetworkAttachementView(networks: $config.networks)
			}
		}.formStyle(.grouped)
	}

	func mountsView() -> some View {
		Form {
			Section("Directory sharing") {
				MountView(mounts: $config.mounts)
			}
		}.formStyle(.grouped)
	}

	func diskAttachementView() -> some View {
		Form {
			Section("Disks attachements") {
				DiskAttachementView(attachedDisks: $config.attachedDisks)
			}
		}.formStyle(.grouped)
	}

	func socketsView() -> some View {
		Form {
			Section("Virtual sockets") {
				SocketsView(sockets: $config.sockets)
			}
		}.formStyle(.grouped)
	}

	func validateConfig(config: VirtualMachineConfig) {
		if let vmname = config.vmname {
			if vmname.isEmpty || StorageLocation(runMode: .app, template: false).exists(vmname) {
				self.configValid = false
			} else {
				self.configValid = true
			}
		} else {
			self.configValid = false
		}
	}

	func createVirtualMachine() async throws -> VMLocation? {
		guard let vmname = config.vmname else {
			return nil
		}

		let location = StorageLocation(runMode: .app, template: false).location(vmname)
		let options = config.buildOptions(image: imageName)
		
		_ = try await VMBuilder.buildVM(vmName: vmname, vmLocation: location, options: options, runMode: .app)
		
		return location
	}
}

#Preview {
    VirtualMachineWizard()
}
