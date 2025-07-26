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
import UniformTypeIdentifiers

typealias OptionalVMLocation = VMLocation?

enum OSCloudImage: Int, CaseIterable {
	/*static var allCases: [String] = [
		"Ubuntu 25.04",
		"Ubuntu 24.04",
		"Ubuntu 22.04",
		"Ubuntu 20.04",
		
		"CentOS 10",
		"CentOS 9",
		
		"Fedora 42",
		"Fedora 41",
		"Fedora 40",
		
		"Debian 12",
		"Debian 11",
		"Debian 10",
		
		"OpenSUSE 156",
		"OpenSUSE 155",
		"OpenSUSE 154",

		"Alpine 3.22",
		"Alpine 3.21",
		"Alpine 3.20",
	]*/
	
	case ubuntu2504LTS
	case ubuntu2404LTS
	case ubuntu2204LTS
	case ubuntu2004LTS

	case centos10
	case centos9

	case fedora42
	case fedora41
	case fedora40

	case debian12
	case debian11
	case debian10
	
	case openSUSE156
	case openSUSE155
	case openSUSE154

	case alpine322
	case alpine321
	case alpine320
	
	var stringValue: String {
		switch self {
			case .ubuntu2504LTS: return "Ubuntu 25.04 LTS"
			case .ubuntu2404LTS: return "Ubuntu 24.04 LTS"
			case .ubuntu2204LTS: return "Ubuntu 22.04 LTS"
			case .ubuntu2004LTS: return "Ubuntu 20.04 LTS"
				
			case .centos10: return "CentOS 10"
			case .centos9: return "CentOS 9"
				
			case .fedora42: return "Fedora 42"
			case .fedora41: return "Fedora 41"
			case .fedora40: return "Fedora 40"
				
			case .debian12: return "Debian 12"
			case .debian11: return "Debian 11"
			case .debian10: return "Debian 10"
					
			case .openSUSE156: return "OpenSUSE Leap 15.6"
			case .openSUSE155: return "OpenSUSE Leap 15.6"
			case .openSUSE154: return "OpenSUSE Leap 15.4"

			case .alpine322: return "Alpine 3.22"
			case .alpine321: return "Alpine 3.21"
			case .alpine320: return "Alpine 3.20"
		}
	}

	var arch: String {
#if arch(arm64)
		switch self {
		case .ubuntu2504LTS, .ubuntu2404LTS, .ubuntu2204LTS, .ubuntu2004LTS,.debian12, .debian11, .debian10:
			return "arm64"

		case .centos10, .centos9,.fedora42, .fedora41, .fedora40,.openSUSE156, .openSUSE155, .openSUSE154,.alpine322, .alpine321, .alpine320:
			return "aarch64"
		}
#elseif arch(x86_64)
		switch self {
		case .ubuntu2504LTS, .ubuntu2404LTS, .ubuntu2204LTS, .ubuntu2004LTS,.debian12, .debian11, .debian10:
			return "amd64"

		case .centos10, .centos9,.fedora42, .fedora41, .fedora40,.openSUSE156, .openSUSE155, .openSUSE154,.alpine322, .alpine321, .alpine320:
			return "x86_64"
		}
#endif
	}

	var url: URL {
		switch self {
		case .ubuntu2504LTS: return URL(string: "https://cloud-images.ubuntu.com/releases/plucky/release/ubuntu-25.04-server-cloudimg-\(self.arch).img")! // amd64|arm64
		case .ubuntu2404LTS: return URL(string: "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-\(self.arch).img")!
		case .ubuntu2204LTS: return URL(string: "https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-\(self.arch).img")!
		case .ubuntu2004LTS: return URL(string: "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-\(self.arch).img")!
			
		case .centos10: return URL(string: "https://cloud.centos.org/centos/10-stream/\(self.arch)/images/CentOS-Stream-GenericCloud-10-20250506.2.\(self.arch).qcow2")!
		case .centos9: return URL(string: "https://cloud.centos.org/centos/9-stream/\(self.arch)/images/CentOS-Stream-GenericCloud-9-20250526.1.\(self.arch).qcow2")!
			
		case .fedora42: return URL(string: "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Server/\(self.arch)/images/Fedora-Server-Guest-Generic-42-1.1.\(self.arch).qcow2")!
		case .fedora41: return URL(string: "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/\(self.arch)/images/Fedora-Server-KVM-41-1.4.\(self.arch).qcow2")!
		case .fedora40: return URL(string: "https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Server/\(self.arch)/images/Fedora-Server-KVM-40-1.14.\(self.arch).qcow2")!
			
		case .debian12: return URL(string: "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-\(self.arch).qcow2")!
		case .debian11: return URL(string: "https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-\(self.arch).qcow2")!
		case .debian10: return URL(string: "https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-\(self.arch).qcow2")!
			
		case .openSUSE156: return URL(string: "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.6/images/openSUSE-Leap-15.6.\(self.arch)-NoCloud.qcow2")!
		case .openSUSE155: return URL(string: "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.5/images/openSUSE-Leap-15.5.\(self.arch)-NoCloud.qcow2")!
		case .openSUSE154: return URL(string: "https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4.\(self.arch)-NoCloud.qcow2")!
			
		case .alpine322: return URL(string: "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/generic_alpine-3.22.1-\(self.arch)-uefi-cloudinit-r0.qcow2")!
		case .alpine321: return URL(string: "https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/cloud/generic_alpine-3.21.2-\(self.arch)-uefi-cloudinit-r0.qcow2")!
		case .alpine320: return URL(string: "https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/cloud/generic_alpine-3.20.7-\(self.arch)-uefi-cloudinit-r0.qcow2")!
		}
	}
}

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
	
	@State private var selectedIndex: Int
	@State private var config: VirtualMachineConfig
	@State private var imageName: String
	@State private var configValid: Bool
	@State private var password: String
	@State private var showPassword: Bool
	@State private var imageSource: VMBuilder.ImageSource
	@State private var remoteImage: String
	@State private var remoteImages: [ShortImageInfo]
	@State private var selectedRemoteImage: String
	@State private var cloudImageRelease: OSCloudImage
	@State private var sshAuthorizedKey: String?

	private let items: [ItemView]
	private let stepsState: StepsState<ItemView>
	
	init() {
		self.selectedIndex = 0
		self.config = .init()
		self.imageName = OSCloudImage.ubuntu2404LTS.url.absoluteString
		self.configValid = false
		self.password = ""
		self.showPassword = false
		self.imageSource = .cloud
		self.remoteImage = "ubuntu"
		self.remoteImages = []
		self.selectedRemoteImage = ""
		self.cloudImageRelease = .ubuntu2404LTS

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
		
		if FileManager.default.fileExists(atPath: "~/.ssh/id_rsa.pub".expandingTildeInPath) {
			self.sshAuthorizedKey = "~/.ssh/id_rsa.pub"
		}
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
							TextField("Password", value: $config.configuredPassword, format: .optional)
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
								.onChange(of: password) { newValue in
									if newValue.isEmpty {
										config.configuredPassword = nil
									} else {
										config.configuredPassword = newValue
									}
								}
						}
					}.overlay(alignment: .trailing) {
						Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
							.padding()
							.onTapGesture {
								showPassword.toggle()
							}
					}
				}
				
				LabeledContent("SSH Public key") {
					HStack {
						TextField("SSH Public key", value: $sshAuthorizedKey, format: .optional)
							.multilineTextAlignment(.leading)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.clipShape(RoundedRectangle(cornerRadius: 6))
						Button(action: {
							if let sshPublicKey = chooseDocument("Select public key", ofType: UTType.sshPublicKey, showsHiddenFiles: true) {
								self.sshAuthorizedKey = sshPublicKey
							}
						}) {
							Image(systemName: "key")
						}.buttonStyle(.borderless)
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
								if let imageName = chooseDiskImage(ofType: UTType.diskImage) {
									self.imageName = "img://\(imageName)"
								}
							}) {
								Image(systemName: "document.badge.gearshape")
							}.buttonStyle(.borderless)
						}
					}

				case .iso:
					VStack {
						let platform = SupportedPlatform(rawValue: imageName)

						LabeledContent("Choose an ISO image disk.") {
							HStack {
								TextField("ISO Image", text: $imageName)
									.multilineTextAlignment(.leading)
									.textFieldStyle(.roundedBorder)
									.background(.white)
									.labelsHidden()
									.clipShape(RoundedRectangle(cornerRadius: 6))
								
								Button(action: {
									if let imageName = chooseDiskImage(ofType: UTType.iso9660) {
										self.imageName = "iso://\(imageName)"
									}
								}) {
									Image(systemName: "document.badge.gearshape")
								}.buttonStyle(.borderless)
							}
						}

						if platform == .ubuntu {
							Toggle("Create autoinstall config", isOn: $config.autoinstall)
						} else if platform == .fedora {
							Toggle("Create kickstart config", isOn: $config.autoinstall)
						} else if platform == .debian {
							Toggle("Create preseed config", isOn: $config.autoinstall)
						}
					}
					
				case .ipsw:
					LabeledContent("Choose an IPSW image.") {
						HStack {
							TextField("IPSW Image", text: $imageName)
								.multilineTextAlignment(.leading)
								.textFieldStyle(.roundedBorder)
								.background(.white)
								.labelsHidden()
								.clipShape(RoundedRectangle(cornerRadius: 6))

							Button(action: {
								if let imageName = chooseDiskImage(ofType: UTType.ipsw) {
									self.imageName = "ipsw://\(imageName)"
								}
							}) {
								Image(systemName: "document.badge.gearshape")
							}.buttonStyle(.borderless)
						}
					}

				case .cloud:
					LabeledContent {
						TextField("Cloud Image", text: $imageName)
							.multilineTextAlignment(.leading)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.clipShape(RoundedRectangle(cornerRadius: 6))
					} label: {
						Picker("Preconfigured image", selection: $cloudImageRelease) {
							ForEach(OSCloudImage.allCases, id: \.self) { os in
								Text(os.stringValue).tag(os)
							}
						}
						.onChange(of: cloudImageRelease) { newValue in
							self.imageName = newValue.url.absoluteString
						}
						.labelsHidden()
					}

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
						}.onChange(of: imageSource) { _ in
							self.imageName = ""
						}.labelsHidden()
					}.frame(width: 100)
				}
			}

			if imageSource != .iso && imageSource != .ipsw {
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
		
		let options = config.buildOptions(image: imageName, sshAuthorizedKey: sshAuthorizedKey)
		
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

	func chooseDiskImage(ofType: UTType = .diskImage) -> String? {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: [ofType], withTitle: "Select image", allowsOtherFileTypes: true) {
			return diskImg.absoluteURL.path
		}
		
		return nil
	}

	func chooseDocument(_ title: String, ofType: UTType = .diskImage, showsHiddenFiles: Bool = false) -> String? {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: [ofType], withTitle: title, allowsOtherFileTypes: true, showsHiddenFiles: showsHiddenFiles) {
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
		}.sorted(using: [ShortImageInfoComparator(order: .forward)])
	}
}

#Preview {
    VirtualMachineWizard()
}
