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

struct ShortImageInfoComparator : SortComparator {
	var order: SortOrder
	
	func compare(_ lhs: ShortImageInfo, _ rhs: ShortImageInfo) -> ComparisonResult {
		if lhs.description == rhs.description {
			return .orderedSame
		}

		if order == .forward {
			return lhs.description < rhs.description ? .orderedAscending : .orderedDescending
		}

		return lhs.description > rhs.description ? .orderedAscending : .orderedDescending
	}
}

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
	@Environment(\.openDocument) private var openDocument
	
	@State private var selectedIndex: Int = 0
	@State private var config: VirtualMachineConfig = .init()
	@State private var imageName: String = defaultUbuntuImage
	@State private var configValid: Bool = false
	@State private var password: String = ""
	@State private var showPassword: Bool = false
	@State private var imageSource: VMBuilder.ImageSource = .cloud
	@State private var remoteImage: String = "ubuntu"
	@State private var remoteImages: [ShortImageInfo] = []
	@State private var selectedRemoteImage: String = ""

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
					
					AsyncButton {
						try await openVirtualMachine()
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
				Toggle("Use network ifnames", isOn: $config.netIfnames)
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
			Section {
				switch imageSource {
				case .raw:
					LabeledContent("Choose a local image disk.") {
						HStack {
							TextField("OS Image", text: $imageName)
								.multilineTextAlignment(.leading)
								.textFieldStyle(.roundedBorder)
								.background(.white)
								.labelsHidden()
								.clipShape(RoundedRectangle(cornerRadius: 6))

							Button(action: {
								if let imageName = chooseDiskImage() {
									self.imageName = imageName
								}
							}) {
								Image(systemName: "document.badge.gearshape")
							}.buttonStyle(.borderless)
						}
					}

				case .cloud:
					TextField("Cloud Image", text: $imageName)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))

				case .oci:
					TextField("OCI Image", text: $imageName)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))

				case .template:
					Picker("Select a template", selection: $imageName) {
						ForEach(templates(), id: \.self) { template in
							Text(template.name).tag(template.fqn)
						}
					}

				case .stream:
					VStack {
						Picker("Select remote sources", selection: $remoteImage) {
							ForEach(remotes(), id: \.self) { remote in
								Text(remote.name).tag(remote.name)
							}
						}.task {
							remoteImages = await images(remote: remoteImage)
						}.onChange(of: remoteImage) { newValue in
							Task {
								remoteImages = await images(remote: newValue)
							}
						}

						List(remoteImages, selection: $selectedRemoteImage) { remoteImage in
							Text(remoteImage.description).tag(remoteImage.fingerprint)
						}
					}.onChange(of: selectedRemoteImage) { newValue in
						imageName = "\(remoteImage)://\(newValue)"
					}
				}
			} header: {
				LabeledContent("Image source") {
					HStack {
						Picker("Image source", selection: $imageSource) {
							ForEach(VMBuilder.ImageSource.allCases, id: \.self) { source in
								Text(source.description).tag(source)
							}
						}.labelsHidden()
					}.frame(width: 100)
				}
			}

			Section("Cloud init") {
				LabeledContent("Optional user data") {
					HStack {
						TextField("User data", value: $config.userData, format: .optional)
							.multilineTextAlignment(.leading)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.clipShape(RoundedRectangle(cornerRadius: 6))
						Button(action: {
							config.userData = chooseYAML()
						}) {
							Image(systemName: "document.badge.gearshape")
						}.buttonStyle(.borderless)
					}
				}
				LabeledContent("Optional network configuration") {
					HStack {
						TextField("network configuration", value: $config.networkConfig, format: .optional)
							.multilineTextAlignment(.leading)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.clipShape(RoundedRectangle(cornerRadius: 6))
						Button(action: {
							config.networkConfig = chooseYAML()
						}) {
							Image(systemName: "document.badge.gearshape")
						}.buttonStyle(.borderless)
					}
				}
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
		
		let options = config.buildOptions(image: imageName)
		
		_ = try await BuildHandler.build(name: vmname, options: options, runMode: .app)
		
		return try StorageLocation(runMode: .app).find(vmname)
	}
	
	func openVirtualMachine() async throws {
		guard let location = try await createVirtualMachine() else {
			return
		}
		
		try? await self.openDocument(at: location.rootURL)
		self.dismiss()
	}

	func chooseDiskImage() -> String? {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: [.diskImage, .iso9660], withTitle: "Select disk image", allowsOtherFileTypes: true) {
			return diskImg.absoluteURL.path
		}
		
		return nil
	}

	func chooseYAML() -> String? {
		if let choosenFile = FileHelpers.selectSingleInputFile(ofType: [.yaml], withTitle: "Select data file", allowsOtherFileTypes: true) {
			return choosenFile.absoluteURL.path
		}
		
		return nil
	}
	
	func templates() -> [TemplateEntry] {
		if let result = try? TemplateHandler.listTemplate(runMode: .app) {
			return result
		}
		
		return []
	}
	
	func remotes() -> [RemoteEntry] {
		if let result = try? RemoteHandler.listRemote(runMode: .app) {
			return result
		}
		
		return []
	}
	
	func images(remote: String) async -> [ShortImageInfo] {
		guard let result = try? await ImageHandler.listImage(remote: remote, runMode: .app) else {
			return []
		}
		
		return result.compactMap {
			ShortImageInfo(imageInfo: $0)
		}.sorted(using: [ShortImageInfoComparator(order: .forward)]) /*{
			$0.description == $1.description
		}*/
	}
}

#Preview {
    VirtualMachineWizard()
}
