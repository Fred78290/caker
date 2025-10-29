import CakedLib
import GRPCLib
//import MultiplatformTabBar
import NIO
import Steps
//
//  VirtualMachineWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/06/2025.
//
import SwiftUI
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
			case .ubuntu2504LTS, .ubuntu2404LTS, .ubuntu2204LTS, .ubuntu2004LTS, .debian12, .debian11, .debian10:
				return "arm64"

			case .centos10, .centos9, .fedora42, .fedora41, .fedora40, .openSUSE156, .openSUSE155, .openSUSE154, .alpine322, .alpine321, .alpine320:
				return "aarch64"
			}
		#elseif arch(x86_64)
			switch self {
			case .ubuntu2504LTS, .ubuntu2404LTS, .ubuntu2204LTS, .ubuntu2004LTS, .debian12, .debian11, .debian10:
				return "amd64"

			case .centos10, .centos9, .fedora42, .fedora41, .fedora40, .openSUSE156, .openSUSE155, .openSUSE154, .alpine322, .alpine321, .alpine320:
				return "x86_64"
			}
		#endif
	}

	var url: URL {
		switch self {
		case .ubuntu2504LTS: return URL(string: "https://cloud-images.ubuntu.com/releases/plucky/release/ubuntu-25.04-server-cloudimg-\(self.arch).img")!  // amd64|arm64
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
	"netdev",
]

struct ShortImageInfoComparator: SortComparator {
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

class VirtualMachineWizardStateObject: ObservableObject {
	@Published var currentStep: WizardModel.SelectedItem
	@Published var configValid: Bool
	@Published var password: String
	@Published var showPassword: Bool
	@Published var imageSource: VMBuilder.ImageSource
	@Published var remoteImage: String
	@Published var remoteImages: [ShortImageInfo]
	@Published var selectedRemoteImage: String
	@Published var cloudImageRelease: OSCloudImage
	@Published var createVM: Bool
	@Published var fractionCompleted: Double
	@Published var createVMMessage: String

	init() {
		self.currentStep = .name
		self.configValid = false
		self.password = ""
		self.showPassword = false
		self.imageSource = .cloud
		self.remoteImage = "ubuntu"
		self.remoteImages = []
		self.selectedRemoteImage = ""
		self.cloudImageRelease = .ubuntu2404LTS
		self.createVM = false
		self.fractionCompleted = 0
		self.createVMMessage = ""
	}
	
	func reset() {
		self.currentStep = .name
		self.configValid = false
		self.password = ""
		self.showPassword = false
		self.imageSource = .cloud
		self.remoteImage = "ubuntu"
		self.remoteImages = []
		self.selectedRemoteImage = ""
		self.cloudImageRelease = .ubuntu2404LTS
		self.createVM = false
		self.fractionCompleted = 0
		self.createVMMessage = ""
	}
}

struct VirtualMachineWizard: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.openDocument) private var openDocument
	@Environment(\.colorScheme) var colorScheme

	@State private var config: VirtualMachineConfig = .init()
	@StateObject private var model = VirtualMachineWizardStateObject()
	@StateObject private var appState = AppState.shared
	private let vmQueue = DispatchQueue(label: "VZVirtualMachineQueue", qos: .userInteractive)

	@ViewBuilder
	func Content() -> some View {
		switch (self.model.currentStep) {
		case .name:
			chooseVMName()
		case .os:
			chooseOSImage()
		case .cpuAndRam:
			generalSettings()
		case .sharing:
			mountsView()
		case .disk:
			diskAttachementView()
		case .network:
			networksView()
		case .ports:
			forwardPortsView()
		case .sockets:
			socketsView()
		}
	}

	var body: some View {
		VStack(spacing: 12) {
			Content()
			Footer()

			if #unavailable(macOS 15.0) {
				HostingWindowFinder { window in
					if let window = window {
						window.standardWindowButton(.zoomButton)?.isEnabled = self.model.createVM == false
						window.standardWindowButton(.closeButton)?.isEnabled = self.model.createVM == false
						window.standardWindowButton(.miniaturizeButton)?.isEnabled = self.model.createVM == false
					}
				}
			}
		}
		.colorSchemeForColor(self.colorScheme)
		.onChange(of: self.colorScheme) { _, newValue in
			Color.colorScheme = newValue
		}
		.onReceive(VirtualMachineDocument.ProgressCreateVirtualMachine) { notification in
			if let fractionCompleted = notification.object as? Double {
				self.model.fractionCompleted = fractionCompleted
			}
		}
		.onReceive(VirtualMachineDocument.CreatedVirtualMachine) { notification in
			self.model.createVM = false

			if let location = notification.object as? VMLocation {
				Task {
					try? await self.openDocument(at: location.rootURL)
					self.dismiss()
				}
			}
			
			self.config = VirtualMachineConfig()
			self.model.reset()
		}
		.onReceive(VirtualMachineDocument.FailCreateVirtualMachine) { notification in
			self.model.createVM = false
			self.model.createVMMessage = ""

			if let error = notification.object as? Error {
				alertError(error)
			}
		}
		.onReceive(VirtualMachineDocument.ProgressMessageCreateVirtualMachine) { notification in
			if let message = notification.object as? String {
				self.model.createVMMessage = message
			}
		}
		.onAppear {
			self.validateConfig(config: self.config)
		}
		.toolbar {
			ToolbarSettings($model.currentStep, items: WizardModel.items, placement: .principal)
		}
		.toolbarTitleDisplayMode(.inlineLarge)
		.windowMinimizeBehavior(self.model.createVM ? .disabled : .automatic)
		.windowDismissBehavior(self.model.createVM ? .disabled : .automatic)
			//.windowResizeBehavior(self.model.createVM ? .disabled : .automatic)
	}

	func Middle() -> some View {
		VStack {
			switch (self.model.currentStep) {
			case .name:
				chooseVMName()
			case .os:
				chooseOSImage()
			case .cpuAndRam:
				generalSettings()
			case .sharing:
				mountsView()
			case .disk:
				diskAttachementView()
			case .network:
				networksView()
			case .ports:
				forwardPortsView()
			case .sockets:
				socketsView()
			}
		}
		.animation(.easeInOut, value: self.model.currentStep)
		.padding()
	}

	func Footer() -> some View {
		VStack {
			if self.model.createVM {
				VStack(alignment: .center) {
					Text(self.model.createVMMessage)
					ProgressView(value: self.model.fractionCompleted).frame(width: 300)
				}.frame(height: 30)
			}

			Divider()

			HStack {
				HStack {
				}.frame(maxWidth: .infinity)

				Spacer()

				HStack {
					Button {
						self.previousStep()
					} label: {
						Text("Previous").frame(width: 80)
					}
					.disabled(self.hasPrevious == false || self.model.createVM)
					Button {
						self.nextStep()
					} label: {
						Text("Next").frame(width: 80)
					}
					.disabled(self.hasNext == false || self.model.createVM)
				}

				Spacer()

				HStack {
					Spacer()

					AsyncButton { done in
						await openVirtualMachine(done)
					} label: {
						Text("Create").frame(width: 80)
					}
					.disabled(self.model.configValid == false)
				}.frame(maxWidth: .infinity)
			}.padding(EdgeInsets(top: 1, leading: 15, bottom: 15, trailing: 15))
		}
		.onChange(of: config) { _, newValue in
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
			.menuStyle(.button)
			.pickerStyle(.menu)
			.disabled(self.model.createVM)

			HStack {
				Text("Memory size")
				Spacer().border(.black)
				HStack {
					TextField("", value: $config.memorySize, format: .number)
						.rounded(.center)
						.frame(width: 50)
						.disabled(self.model.createVM)
					Stepper(value: $config.memorySize, in: totalMemoryRange, step: 1) {

					}
					.labelsHidden()
					.disabled(self.model.createVM)
				}
			}

			HStack {
				Text("Disk size")
				Spacer().border(.black)
				HStack {
					TextField("", value: $config.diskSize, format: .number)
						.rounded(.center)
						.frame(width: 50)
						.disabled(self.model.createVM)
					Stepper(value: $config.diskSize, in: diskRange, step: 1) {

					}
					.labelsHidden()
					.disabled(self.model.createVM)
				}
			}
		}
	}

	func optionsView() -> some View {
		Section("Options") {
			VStack(alignment: .leading) {
				Toggle("Autostart", isOn: $config.autostart).disabled(self.model.createVM)
				Toggle("Suspendable", isOn: $config.suspendable).disabled(self.model.createVM)
				Toggle("Dynamic forward ports", isOn: $config.dynamicPortForwarding).disabled(self.model.createVM)
				Toggle("Refit display", isOn: $config.displayRefit).disabled(self.model.createVM)
				Toggle("Nested virtualization", isOn: $config.nestedVirtualization).disabled(self.model.createVM)
				Toggle("Use network ifnames", isOn: $config.netIfnames).disabled(self.model.createVM)
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
						.disabled(self.model.createVM)
				}
				HStack {
					Text("Height")
					Spacer().border(.black)
					TextField("", value: $config.display.height, format: .number)
						.rounded(.center)
						.frame(width: 50)
						.disabled(self.model.createVM)
				}
			}
		}
	}

	@ViewBuilder
	func chooseVMName() -> some View {
		Form {
			Section("Virtual machine name") {
				TextField("Virtual machine name", value: $config.vmname, format: .optional)
					.rounded(.leading)
					.disabled(self.model.createVM)
					.onChange(of: config.vmname) {
						self.validateConfig(config: self.config)
					}
			}

			Section("Administrator settings") {
				LabeledContent("Administator name") {
					TextField("User name", text: $config.configuredUser)
						.rounded(.leading)
						.disabled(self.model.createVM)
				}

				LabeledContent("Administator password") {
					HStack {
						if self.model.showPassword {
							TextField("Password", value: $config.configuredPassword, format: .optional)
								.rounded(.leading)
								.disabled(self.model.createVM)
						} else {
							SecureField("Password", text: $model.password)
								.rounded(.leading)
								.disabled(self.model.createVM)
								.onChange(of: self.model.password) { _, newValue in
									if newValue.isEmpty {
										config.configuredPassword = nil
									} else {
										config.configuredPassword = newValue
									}
								}
						}
					}.overlay(alignment: .trailing) {
						Image(systemName: self.model.showPassword ? "eye.fill" : "eye.slash.fill")
							.padding()
							.onTapGesture {
								self.model.showPassword.toggle()
							}
					}
				}

				LabeledContent("SSH Public key") {
					HStack {
						TextField("SSH Public key", value: $config.sshAuthorizedKey, format: .optional)
							.rounded(.leading)
							.disabled(self.model.createVM)
						Button(action: {
							if let sshPublicKey = chooseDocument("Select public key", ofType: UTType.sshPublicKey, showsHiddenFiles: true) {
								self.config.sshAuthorizedKey = sshPublicKey
							}
						}) {
							Image(systemName: "key")
						}
						.buttonStyle(.borderless)
						.disabled(self.model.createVM)
					}
				}

				Toggle("SSH with password", isOn: $config.clearPassword).disabled(self.model.createVM)

				LabeledContent("Administator group") {
					HStack {
						Spacer()
						Picker("Main group", selection: $config.mainGroup) {
							ForEach(groups, id: \.self) { name in
								Text(name).tag(name)
							}
						}
						.pickerStyle(.menu)
						.disabled(self.model.createVM)
						.labelsHidden()
					}.frame(width: 100)
				}
			}

		}.formStyle(.grouped)
	}

	func chooseOSImage() -> some View {
		Form {
			Section {
				switch self.model.imageSource {
				case .raw:
					LabeledContent("Choose a local image disk.") {
						HStack {
							TextField("OS Image", text: $config.imageName)
								.rounded(.leading)
								.disabled(self.model.createVM)

							Button(action: {
								if let imageName = chooseDiskImage(ofType: UTType.diskImage) {
									self.config.imageName = "img://\(imageName)"
								}
							}) {
								Image(systemName: "document.badge.gearshape")
							}
							.buttonStyle(.borderless)
							.disabled(self.model.createVM)
						}
					}

				case .iso:
					VStack {
						let platform = SupportedPlatform(rawValue: self.config.imageName)

						LabeledContent("Choose an ISO image disk.") {
							HStack {
								TextField("ISO Image", text: $config.imageName)
									.rounded(.leading)
									.disabled(self.model.createVM)

								Button(action: {
									if let imageName = chooseDiskImage(ofTypes: [UTType.iso9660, UTType.cdr]) {
										self.config.imageName = "iso://\(imageName)"
									}
								}) {
									Image(systemName: "document.badge.gearshape")
								}
								.disabled(self.model.createVM)
								.buttonStyle(.borderless)
							}
						}

						if platform == .ubuntu {
							Toggle("Create autoinstall config", isOn: $config.autoinstall).disabled(self.model.createVM)
//						} else if platform == .fedora {
//							Toggle("Create kickstart config", isOn: $config.autoinstall).disabled(self.model.createVM)
//						} else if platform == .debian {
//							Toggle("Create preseed config", isOn: $config.autoinstall).disabled(self.model.createVM)
						}
					}

				#if arch(arm64)
					case .ipsw:
						LabeledContent("Choose an IPSW image.") {
							HStack {
								TextField("IPSW Image", text: $config.imageName)
									.rounded(.leading)
									.disabled(self.model.createVM)
								Button(action: {
									if let imageName = chooseDiskImage(ofType: UTType.ipsw) {
										self.config.imageName = "ipsw://\(imageName)"
									}
								}) {
									Image(systemName: "document.badge.gearshape")
								}
								.disabled(self.model.createVM)
								.buttonStyle(.borderless)
							}
						}
				#endif

				case .cloud:
					LabeledContent {
						TextField("Cloud Image", text: $config.imageName)
							.rounded(.leading)
							.disabled(self.model.createVM)
					} label: {
						Picker("Preconfigured image", selection: $model.cloudImageRelease) {
							ForEach(OSCloudImage.allCases, id: \.self) { os in
								Text(os.stringValue).tag(os)
							}
						}
						.pickerStyle(.menu)
						.disabled(self.model.createVM)
						.labelsHidden()
						.onChange(of: model.cloudImageRelease) { _, newValue in
							self.config.imageName = newValue.url.absoluteString
						}
					}

				case .oci:
					TextField("OCI Image", text: $config.imageName)
						.rounded(.leading)
						.disabled(self.model.createVM)

				case .template:
					Picker("Select a template", selection: $config.imageName) {
						ForEach(self.appState.templates, id: \.self) { template in
							Text(template.name).tag(template.fqn)
						}
					}
					.pickerStyle(.menu)
					.disabled(self.model.createVM)

				case .stream:
					VStack {
						Picker("Select remote sources", selection: $model.remoteImage) {
							ForEach(self.appState.remotes, id: \.self) { remote in
								Text(remote.name).tag(remote.name)
							}
						}
						.pickerStyle(.menu)
						.disabled(self.model.createVM)
						.task {
							self.model.remoteImages = await images(remote: self.model.remoteImage)
						}.onChange(of: self.model.remoteImage) { _, newValue in
							Task {
								self.model.remoteImages = await images(remote: newValue)
							}
						}
						ScrollView {
							VStack {
								GeometryReader { geom in
									List(self.model.remoteImages, selection: $model.selectedRemoteImage) { remoteImage in
										Text(remoteImage.description).tag(remoteImage.fingerprint)
									}.frame(height: geom.size.height)
								}
							}.frame(minHeight: 250, maxHeight: .infinity)
						}
					}.onChange(of: model.selectedRemoteImage) { _, newValue in
						self.config.imageName = "\(self.model.remoteImage)://\(newValue)"
					}
				}
			} header: {
				LabeledContent("Image source") {
					HStack {
						Picker("Image source", selection: $model.imageSource) {
							ForEach(VMBuilder.ImageSource.allCases, id: \.self) { source in
								Text(source.description).tag(source)
							}
						}.onChange(of: self.model.imageSource) { _, newValue in
							self.config.imageName = ""
							#if arch(arm64)
								if newValue == .ipsw {
									self.config.cpuCount = max(self.config.cpuCount, 4)
									self.config.memorySize = max(self.config.memorySize, 4096)
									self.config.diskSize = max(self.config.diskSize, 40)
								}
							#endif
						}
						.pickerStyle(.menu)
						.disabled(self.model.createVM)
						.labelsHidden()
					}.frame(width: 100)
				}
			}

			if model.imageSource.supportCloudInit {
				Section("Cloud init") {
					LabeledContent("Optional user data") {
						HStack {
							TextField("User data", value: $config.userData, format: .optional)
								.rounded(.leading)
								.disabled(self.model.createVM)
							Button(action: {
								config.userData = chooseYAML()
							}) {
								Image(systemName: "document.badge.gearshape")
							}
							.disabled(self.model.createVM)
							.buttonStyle(.borderless)
						}
					}
					LabeledContent("Optional network configuration") {
						HStack {
							TextField("network configuration", value: $config.networkConfig, format: .optional)
								.rounded(.leading)
								.disabled(self.model.createVM)
							Button(action: {
								config.networkConfig = chooseYAML()
							}) {
								Image(systemName: "document.badge.gearshape")
							}
							.disabled(self.model.createVM)
							.buttonStyle(.borderless)
						}
					}
				}
			}
		}.formStyle(.grouped).disabled(self.model.createVM)
	}

	func forwardPortsView() -> some View {
		Form {
			Section("Forwarded ports") {
				ForwardedPortView(forwardPorts: $config.forwardPorts, disabled: $model.createVM).frame(height: 400)
			}
		}.formStyle(.grouped)
	}

	func networksView() -> some View {
		Form {
			Section("Network attachements") {
				NetworkAttachementView(networks: $config.networks, disabled: $model.createVM).frame(height: 400)
			}
		}.formStyle(.grouped)
	}

	func mountsView() -> some View {
		Form {
			Section("Directory sharing") {
				MountView(mounts: $config.mounts, disabled: $model.createVM).frame(height: 400)
			}
		}.formStyle(.grouped)
	}

	func diskAttachementView() -> some View {
		Form {
			Section("Disks attachements") {
				DiskAttachementView(attachedDisks: $config.attachedDisks, disabled: $model.createVM).frame(height: 400)
			}
		}.formStyle(.grouped)
	}

	func socketsView() -> some View {
		Form {
			Section("Virtual sockets") {
				SocketsView(sockets: $config.sockets, disabled: $model.createVM).frame(height: 400)
			}
		}.formStyle(.grouped)
	}

	func validateConfig(config: VirtualMachineConfig) {
		var valid = false

		if let vmname = config.vmname, self.config.imageName.isEmpty == false, vmname.isEmpty == false {
			if StorageLocation(runMode: .app, template: false).exists(vmname) == false {
				valid = true
			}
		}

		self.model.configValid = valid
	}

	func openVirtualMachine(_ done: @escaping () -> Void) async {
		if config.vmname == nil {
			return
		}

		self.model.createVM = true
		self.model.createVMMessage = "Creating virtual machine..."

		await self.config.createVirtualMachine(imageSource: self.model.imageSource) { result in
			DispatchQueue.main.async {
				switch result {
				case .progress(_, let fractionCompleted):
					NotificationCenter.default.post(name: VirtualMachineDocument.ProgressCreateVirtualMachine, object: fractionCompleted)

				case .terminated(let result):
					if case let .failure(error) = result {
						NotificationCenter.default.post(name: VirtualMachineDocument.FailCreateVirtualMachine, object: error)
					} else if case let .success(location) = result {
						NotificationCenter.default.post(name: VirtualMachineDocument.CreatedVirtualMachine, object: location)
					} else {
						NotificationCenter.default.post(name: VirtualMachineDocument.FailCreateVirtualMachine, object: ServiceError("Internal error creating virtual machine"))
					}

					done()
				case .step(let message):
					NotificationCenter.default.post(name: VirtualMachineDocument.ProgressMessageCreateVirtualMachine, object: message)
				}
			}
		}
	}

	func chooseDiskImage(ofTypes: [UTType]) -> String? {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: ofTypes, withTitle: "Select image", allowsOtherFileTypes: true) {
			return diskImg.absoluteURL.path
		}

		return nil
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

	var hasPrevious: Bool {
		self.model.currentStep != .name
	}

	var hasNext: Bool {
		self.model.currentStep != .sockets
	}

	func previousStep() {
		guard self.model.currentStep != .name else {
			return
		}

		validateConfig(config: self.config)
		self.model.currentStep = WizardModel.SelectedItem(rawValue: self.model.currentStep.rawValue - 1)!
	}

	func nextStep() {
		guard self.model.currentStep != .sockets else {
			return
		}

		validateConfig(config: self.config)
		self.model.currentStep = WizardModel.SelectedItem(rawValue: self.model.currentStep.rawValue + 1)!
	}
}

#Preview {
	VirtualMachineWizard()
}
