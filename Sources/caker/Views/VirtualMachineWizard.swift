//
//  VirtualMachineWizard.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/06/2025.
//

import CakedLib
import GRPCLib
//import MultiplatformTabBar
import NIO
import Steps
import SwiftUI
import Synchronization
import UniformTypeIdentifiers
import Virtualization

typealias OptionalVMLocation = VMLocation?

extension VMImageEntry {
	/// Raises `config`'s CPU count / memory to this entry's `minCPU`/`minMemoryMiB`, if any —
	/// never lowers a value the user already raised above the minimum. IPSW entries have no
	/// minimum here; macOS installs apply their own fixed floor separately (see the `.ipsw`
	/// image-source case below).
	func applyMinimumResources(to config: inout VirtualMachineConfig) {
		if let minCPU {
			config.cpuCount = max(config.cpuCount, minCPU)
		}

		if let minMemoryMiB {
			config.memorySizeInMoB = max(config.memorySizeInMoB, minMemoryMiB)
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

@Observable class VirtualMachineWizardStateObject {
	var currentStep: WizardModel.SelectedItem
	var configValid: Bool
	var password: String
	var showPassword: Bool
	var imageSource: ImageSource
	var remoteImage: String
	var remoteImages: [ShortImageInfo]
	var selectedRemoteImage: ShortImageInfo.ID
	var cloudImageRelease: VMImageEntry
	var isoImageRelease: VMImageEntry
	var ipswRelease: VMImageEntry
	var createVM: Bool
	var fractionCompleted: Double
	var createVMMessage: String
	var createVMSubtitle: String
	var rootDisk: String
	var mountPoints: MountPoints
	var showDiskFormat: Bool
	var createVirtualMachineTask: Task<Void, Never>?
	var provisioningTemplate: String

	init() {
		self.currentStep = .name
		self.configValid = false
		self.password = String.empty
		self.showPassword = false
		self.imageSource = .qcow2
		self.remoteImage = "ubuntu"
		self.remoteImages = []
		self.selectedRemoteImage = String.empty
		self.cloudImageRelease = VMImageCatalog.shared.cloudImage("ubuntu2604LTS")
		self.isoImageRelease = VMImageCatalog.shared.isoImage("ubuntu2604Server")
		self.ipswRelease = VMImageCatalog.shared.ipswImage("macos26_6")
		self.createVM = false
		self.fractionCompleted = 0
		self.createVMMessage = String.empty
		self.createVMSubtitle = String.empty
		self.rootDisk = String.empty
		self.mountPoints = []
		self.showDiskFormat = false
		self.provisioningTemplate = String.empty
	}

	func reset() {
		self.currentStep = .name
		self.configValid = false
		self.password = String.empty
		self.showPassword = false
		self.imageSource = .qcow2
		self.remoteImage = "ubuntu"
		self.remoteImages = []
		self.selectedRemoteImage = String.empty
		self.cloudImageRelease = VMImageCatalog.shared.cloudImage("ubuntu2404LTS")
		self.isoImageRelease = VMImageCatalog.shared.isoImage("ubuntu2604Server")
		self.ipswRelease = VMImageCatalog.shared.ipswImage("macos26_6")
		self.createVM = false
		self.fractionCompleted = 0
		self.createVMMessage = String.empty
		self.createVMSubtitle = String.empty
		self.rootDisk = String.empty
		self.mountPoints = []
		self.showDiskFormat = false
		self.provisioningTemplate = String.empty
	}
}

struct WizardVirtualMachineView: NSViewRepresentable {
	public typealias NSViewType = NSView

	private let virtualMachine: VirtualMachine

	init(_ virtualMachine: VirtualMachine) {
		self.virtualMachine = virtualMachine
	}

	public func makeNSView(context: Context) -> NSViewType {
		guard let vzMachineView = self.virtualMachine.vzMachineView else {
			fatalError("No virtual machine view")
		}

		let view = NSView(frame: vzMachineView.bounds)
		view.wantsLayer = true
		view.layer?.cornerRadius = 10
		view.layer?.masksToBounds = true

		view.addSubview(vzMachineView)
		// Use Auto Layout to scale-fit the subview to its container
		vzMachineView.translatesAutoresizingMaskIntoConstraints = false
		vzMachineView.automaticallyReconfiguresDisplay = false
		NSLayoutConstraint.activate([
			vzMachineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			vzMachineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			vzMachineView.topAnchor.constraint(equalTo: view.topAnchor),
			vzMachineView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])

		return view
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
	}
}

struct VirtualMachineWizard: View {
	static let wizardQueue = DispatchQueue(label: "VZVirtualMachineQueue", qos: .userInteractive)
	static let ProgressCreateVirtualMachine = NSNotification.Name("ProgressCreateVirtualMachine")
	static let ProgressTitleCreateVirtualMachine = NSNotification.Name("ProgressTitleCreateVirtualMachine")
	static let ProgressSubtitleCreateVirtualMachine = NSNotification.Name("ProgressSubtitleCreateVirtualMachine")
	static let CreatedVirtualMachine = NSNotification.Name("CreatedVirtualMachine")
	static let FailCreateVirtualMachine = NSNotification.Name("FailCreateVirtualMachine")

	@Environment(\.dismiss) private var dismiss
	@Environment(\.openWindow) private var openWindow

	@State private var config: VirtualMachineConfig
	@State private var currentTab: Int = 0
	@State private var model: VirtualMachineWizardStateObject
	@State private var diskSizeValueIsInvalid = false
	@State private var allowsOverrideMinimumResources = false
	@State private var provisionnedVM: VirtualMachine? = nil

	private let wizardID = UUID()
	private let listHeight: CGFloat = 460
	private let fromPreset: Bool
	private let presetImage: String

	var sheet: Bool = false

	private static let randomNameWords: [String] = {
		let fallback = [
			"swift", "brisk", "calm", "lively", "merry", "noble", "bright", "vivid", "quiet", "bold",
			"otter", "falcon", "lynx", "panda", "tiger", "eagle", "wolf", "orca", "fox", "ibis",
		]

		guard let content = try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8) else {
			return fallback
		}

		let words = content.split(separator: "\n").compactMap { line -> String? in
			guard line.count >= 3, line.count <= 8, line.allSatisfy({ ("a"..."z").contains($0) }) else {
				return nil
			}

			return String(line)
		}

		return words.isEmpty ? fallback : words
	}()

	static func generateRandomVMName() -> String {
		let first = randomNameWords.randomElement() ?? "swift"
		let second = randomNameWords.randomElement() ?? "otter"
		return "\(first)-\(second)"
	}

	init(sheet: Bool = false, presetTemplate: TemplateEntry? = nil, presetRemoteImage: (remote: String, image: ImageInfo)? = nil) {
		self.sheet = sheet

		if let presetTemplate {
			var config = VirtualMachineConfig()

			config.source = .template
			config.imageName = presetTemplate.fqn
			config.vmname = presetTemplate.name

			let model = VirtualMachineWizardStateObject()

			model.imageSource = .template

			self._config = State(initialValue: config)
			self._model = State(initialValue: model)
			self.fromPreset = true
			self.presetImage = presetTemplate.name
		} else if let presetRemoteImage {
			var config = VirtualMachineConfig()

			config.vmname = Self.generateRandomVMName()
			config.source = .stream
			config.diskFormat = .raw
			config.os = .linux
			config.imageName = "\(presetRemoteImage.remote)://\(presetRemoteImage.image.fingerprint)"

			let model = VirtualMachineWizardStateObject()
			let image = ShortImageInfo(presetRemoteImage.image)

			model.imageSource = .stream
			model.remoteImage = presetRemoteImage.remote
			model.selectedRemoteImage = presetRemoteImage.image.fingerprint
			model.remoteImages = [image]

			self._config = State(initialValue: config)
			self._model = State(initialValue: model)
			self.fromPreset = true
			self.presetImage = image.description
		} else {
			var config = VirtualMachineConfig()

			config.vmname = Self.generateRandomVMName()
			config.source = .qcow2

			let defaultCloudImage = VMImageCatalog.shared.cloudImage("ubuntu2604LTS")

			config.imageName = defaultCloudImage.url
			config.os = .linux
			defaultCloudImage.applyMinimumResources(to: &config)

			let model = VirtualMachineWizardStateObject()

			model.imageSource = .qcow2
			model.cloudImageRelease = defaultCloudImage

			self._config = State(initialValue: config)
			self._model = State(initialValue: model)
			self.fromPreset = false
			self.presetImage = ""
		}
	}

	@ViewBuilder
	func Content(currentStep: WizardModel.SelectedItem) -> some View {
		switch currentStep {
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
		if #unavailable(macOS 15.0) {
			HostingWindowFinder { window in
				if let window = window {
					window.standardWindowButton(.zoomButton)?.isEnabled = self.model.createVM == false
					window.standardWindowButton(.closeButton)?.isEnabled = self.model.createVM == false
					window.standardWindowButton(.miniaturizeButton)?.isEnabled = self.model.createVM == false
				}
			}
		}

		self.Body().onReceive(Self.ProgressCreateVirtualMachine) { notification in
			if self.isMyNotification(notification), let fractionCompleted = notification.object as? Double {
				self.model.fractionCompleted = max(0, min(1.0, fractionCompleted))
			}
		}
		.onReceive(Self.CreatedVirtualMachine) { notification in
			if self.isMyNotification(notification) {
				self.model.createVM = false

				if let vmURL = notification.object as? URL {
					Task {
						await MainApp.app.openVirtualMachine(vmURL)
						self.dismiss()
					}
				}

				self.config = VirtualMachineConfig()
				self.model.reset()
			}
		}
		.onReceive(Self.FailCreateVirtualMachine) { notification in
			if self.isMyNotification(notification) {
				self.model.createVM = false
				self.model.createVMMessage = String.empty

				if let error = notification.object as? Error {
					alertError(error)
				}
			}
		}
		.onReceive(Self.ProgressTitleCreateVirtualMachine) { notification in
			if self.isMyNotification(notification), let message = notification.object as? String {
				self.model.createVMMessage = message
			}
		}
		.onReceive(Self.ProgressSubtitleCreateVirtualMachine) { notification in
			if self.isMyNotification(notification), let message = notification.object as? String {
				self.model.createVMSubtitle = message
			}
		}
		.onReceive(PackerLiteEngine.provisionedStartNotification) { notification in
			if self.isMyNotification(notification), let virtualMachine = notification.object as? VirtualMachine {
				#if DEBUG_PAKERLITE
					self.openWindow(id: "Debug PackerLite", value: self.wizardID)
				#else
					self.provisionnedVM = virtualMachine
				#endif
			}
		}
		.onReceive(PackerLiteEngine.provisionedTerminatedNotification) { notification in
			if self.isMyNotification(notification) {
				self.provisionnedVM = nil
			}
		}

		.onAppear {
			self.validateConfig(config: self.config)
		}
		.onDisappear {
			self.model.createVirtualMachineTask?.cancel()
		}
		.windowMinimizeBehavior(self.model.createVM ? .disabled : .automatic)
		.windowDismissBehavior(self.model.createVM ? .disabled : .automatic)
		//.windowResizeBehavior(self.model.createVM ? .disabled : .automatic)
	}

	func isMyNotification(_ notification: Notification) -> Bool {
		notification.userInfo?["wizardID"] as? UUID == self.wizardID
	}

	func TabBar() -> some View {
		let tabBar = MultiplatformTabBar(selection: $model.currentStep, tabPosition: .top, barHorizontalAlignment: .center)

		WizardModel.items.forEach { item in
			tabBar.tab(title: item.title, systemName: item.systemImage, tag: item.id) {
				self.Content(currentStep: item.id)
			}
		}

		return tabBar
	}

	@ViewBuilder
	func Body() -> some View {
		if self.sheet {
			VStack(spacing: 12) {
				if let provisionnedVM = self.provisionnedVM {
					WizardVirtualMachineView(provisionnedVM)
						.padding(20)
						.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
						.disabled(true)
				} else {
					TabBar()
				}
				Footer()
			}
		} else {
			VStack(spacing: 12) {
				if let provisionnedVM = self.provisionnedVM {
					WizardVirtualMachineView(provisionnedVM)
						.padding(10)
						.clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
						.disabled(true)
				} else {
					Content(currentStep: self.model.currentStep)
				}
				Footer()
			}
			.toolbar {
				ToolbarSettings($model.currentStep, items: WizardModel.items, placement: .principal)
			}
			.toolbarTitleDisplayMode(.inlineLarge)
		}
	}

	func Middle() -> some View {
		VStack {
			switch self.model.currentStep {
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
		VStack(spacing: 0) {
			if self.model.createVM {
				VStack(alignment: .center, spacing: 6) {
					HStack(spacing: 6) {
						Image(systemName: "gearshape.2")
							.foregroundStyle(.secondary)
							.font(.callout)
						Text(self.model.createVMMessage)
							.font(.callout)
							.foregroundStyle(.secondary)
					}
					ProgressView(value: self.model.fractionCompleted)
						.frame(width: 320)
						.tint(.accentColor)
					Text(self.model.createVMSubtitle)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(.vertical, 10)
			}

			Divider()

			HStack {
				HStack(spacing: 6) {
					Button {
						self.previousStep()
					} label: {
						HStack(spacing: 4) {
							Image(systemName: "chevron.left")
							Text("Previous")
						}.frame(width: 90)
					}
					.disabled(self.hasPrevious == false || self.model.createVM)

					Button {
						self.nextStep()
					} label: {
						HStack(spacing: 4) {
							Text("Next")
							Image(systemName: "chevron.right")
						}.frame(width: 70)
					}
					.disabled(self.hasNext == false || self.model.createVM)
				}
				.frame(maxWidth: .infinity, alignment: .center)

				HStack(spacing: 8) {
					if self.sheet {
						Button {
							self.dismiss()
						} label: {
							Text("Cancel").frame(width: 80)
						}
					}

					AsyncButton { done in
						self.model.createVirtualMachineTask = Task {
							await openVirtualMachine(done)
						}
					} label: {
						Text("Create").frame(width: 80)
					}
					.buttonStyle(.borderedProminent)
					.disabled(self.model.configValid == false)
				}
			}
			.padding(EdgeInsets(top: 10, leading: 16, bottom: 16, trailing: 16))
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

	/// The CPU/memory floor the sliders (and `validateConfig`) should enforce for the currently
	/// selected image — the entry's own `minCPU`/`minMemoryMiB` for `.iso`/`.qcow2`, the `.ipsw`
	/// case's own fixed minimums, or the generic floor for sources with no catalog entry. Without
	/// this, `applyMinimumResources(to:)` only raises the config once at selection time — the
	/// slider would still let the user drag straight back down below the image's minimum.
	var minimumCPUCount: UInt16 {
		guard allowsOverrideMinimumResources == false else {
			return 1
		}

		switch model.imageSource {
		case .iso: return model.isoImageRelease.minCPU ?? 1
		case .qcow2: return model.cloudImageRelease.minCPU ?? 1
		case .ipsw: return 4
		default: return 1
		}
	}

	var minimumMemoryInMiB: UInt64 {
		guard allowsOverrideMinimumResources == false else {
			return 512
		}

		switch model.imageSource {
		case .iso: return model.isoImageRelease.minMemoryMiB ?? 512
		case .qcow2: return model.cloudImageRelease.minMemoryMiB ?? 512
		case .ipsw: return 4096
		default: return 512
		}
	}

	func cpuCountAndMemoryView() -> some View {
		Section("CPU & Memory") {
			let cpuLowerBound: UInt16 = self.minimumCPUCount
			let cpuUpperBound: UInt16 = max(cpuLowerBound, UInt16(System.coreCount))
			let cpuRange: ClosedRange<UInt16> = cpuLowerBound...cpuUpperBound
			let memoryLowerBound: UInt64 = self.minimumMemoryInMiB
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
					.disabled(self.model.createVM)
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
					.disabled(self.model.createVM)
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

			Toggle("Allow override minimum resources", isOn: $allowsOverrideMinimumResources)
				.disabled(self.model.createVM)
				.padding(.vertical, 2)
		}
	}

	func optionsView() -> some View {
		Section("Options") {
			VStack(alignment: .leading) {
				Toggle("Autostart", isOn: $config.autostart).disabled(self.model.createVM)
				Toggle("Dynamic forward ports", isOn: $config.dynamicPortForwarding).disabled(self.model.createVM)
				Toggle("Refit display", isOn: $config.displayRefit).disabled(self.model.createVM)
				Toggle("Nested virtualization", isOn: $config.nestedVirtualization).disabled(self.model.createVM)
				Toggle("Use network ifnames", isOn: $config.ifname).disabled(self.model.createVM)

				if self.model.imageSource == .ipsw {
					Toggle("Suspendable", isOn: $config.suspendable).disabled(self.model.createVM)
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
						.disabled(self.model.createVM)
				}
				HStack {
					Text("Height")
					Spacer()
					TextField(String.empty, value: $config.display.height, format: .number)
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
			Section {
				TextField("Virtual machine name", value: $config.vmname, format: .optional)
					.rounded(.leading)
					.disabled(self.model.createVM)
					.onChange(of: config.vmname) {
						self.validateConfig(config: self.config)
					}

			} header: {
				HStack {
					Text("Virtual machine name")
					Spacer()
					Text("\((config.vmname ?? String.empty).count)/\(URL.maxVirtualMachineNameLength)")
						.font(.caption)
						.foregroundStyle((config.vmname ?? String.empty).count > URL.maxVirtualMachineNameLength ? .red : .secondary)
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
							if let sshPublicKey = chooseDocument(String(localized: "Choose a public ssh key"), ofType: UTType.sshPublicKey, showsHiddenFiles: true), let sshPublicKey = try? sshPublicKey.stringContent() {
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
						Picker("Main group", selection: $config.configuredGroup) {
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
			if self.fromPreset {
				Section("Preset image source") {
					LabeledContent("From source") {
						Text(self.model.imageSource.description)
					}
					LabeledContent("Preset image") {
						Text(presetImage)
					}
					LabeledContent("FQN") {
						Text(config.imageName)
					}
				}
			} else {
				Section {
					switch self.model.imageSource {
					case .raw:
						if AppState.shared.connectionMode == .app {
							LabeledContent("Choose a local image disk.") {
								HStack {
									TextField("OS Image", text: $config.imageName)
										.rounded(.leading)
										.disabled(self.model.createVM)

									Button(action: {
										if let imageName = chooseDiskImage(ofType: UTType.diskImage) {
											self.config.imageName = "file://\(imageName)"
										}
									}) {
										Image(systemName: "document.badge.gearshape")
									}
									.buttonStyle(.borderless)
									.disabled(self.model.createVM)
								}
							}
						} else {
							LabeledContent("Raw image url.") {
								TextField("URL", text: $config.imageName)
									.rounded(.leading)
									.disabled(self.model.createVM)
							}
						}
					case .iso:
						VStack(alignment: .leading) {
							let platform = SupportedPlatform(rawValue: self.config.imageName)

							LabeledContent {
								if AppState.shared.connectionMode == .app {
									HStack {
										TextField("Choose an ISO image disk.", text: $config.imageName)
											.frame(width: 300)
											.rounded(.leading)
											.disabled(self.model.createVM)

										Button(action: {
											if let imageName = chooseDiskImage(ofTypes: [UTType.iso9660, UTType.cdr]) {
												self.config.imageName = "file://\(imageName)"
											}
										}) {
											Image(systemName: "document.badge.gearshape")
										}
										.disabled(self.model.createVM)
										.buttonStyle(.borderless)
									}
								} else {
									TextField("Bootable iso url.", text: $config.imageName)
										.frame(width: 340)
										.rounded(.leading)
										.disabled(self.model.createVM)
								}
							} label: {
								Picker("Preconfigured ISO", selection: $model.isoImageRelease) {
									ForEach(VMImageCatalog.shared.availableISOImages) { os in
										Text(os.label).tag(os)
									}
								}
								.pickerStyle(.menu)
								.disabled(self.model.createVM)
								.labelsHidden()
								.onChange(of: model.isoImageRelease) { _, newValue in
									self.config.imageName = newValue.url
									newValue.applyMinimumResources(to: &self.config)
								}
							}

							if platform == .ubuntu {
								Toggle("Create autoinstall config", isOn: $config.autoinstall).disabled(self.model.createVM)
								//						} else if platform == .fedora {
								//							Toggle("Create kickstart config", isOn: $config.autoinstall).disabled(self.model.createVM)
								//						} else if platform == .debian {
								//							Toggle("Create preseed config", isOn: $config.autoinstall).disabled(self.model.createVM)
							} else {
								// Fedora/CentOS/RHEL/openSUSE/Debian ship a built-in template (see
								// PackerLiteTemplateResolver) auto-selected from the detected platform, so the
								// picker below is only required to override it or for a platform with no default.
								let hasBuiltInTemplate = PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for: platform)

								LabeledContent(hasBuiltInTemplate ? "Provisioning template (optional)" : "Provisioning template") {
									HStack {
										TextField("", text: $model.provisioningTemplate)
											.frame(width: 300)
											.rounded(.leading)
											.disabled(self.model.createVM)
										Button(action: {
											if let provisioningTemplate = chooseYAML() {
												model.provisioningTemplate = provisioningTemplate
											}
										}) {
											Image(systemName: "document.badge.gearshape")
										}
										.disabled(self.model.createVM)
										.buttonStyle(.borderless)
									}
								}
								Text(hasBuiltInTemplate ? "Leave empty to use the built-in \(platform.rawValue) template or provide a custom one provisioning template" : "Provide a custom one provisioning template")
									.font(.caption)
									.foregroundStyle(.secondary)
								Toggle("Auto configuration with provisioning", isOn: $config.autoinstall).disabled(self.model.createVM)
							}
						}

					case .ipsw:
						VStack(alignment: .leading) {
							LabeledContent {
								if AppState.shared.connectionMode == .app {
									HStack {
										TextField("IPSW Image", text: $config.imageName)
											.frame(width: 460)
											.rounded(.leading)
											.disabled(self.model.createVM)
										Button(action: {
											if let imageName = chooseDiskImage(ofType: UTType.ipsw) {
												self.config.imageName = "file://\(imageName)"
											}
										}) {
											Image(systemName: "document.badge.gearshape")
										}
										.disabled(self.model.createVM)
										.buttonStyle(.borderless)
									}
								} else {
									TextField("MacOS ipsw url.", text: $config.imageName)
										.frame(width: 460)
										.rounded(.leading)
										.disabled(self.model.createVM)
								}
							} label: {
								Picker("Preconfigured IPSW", selection: $model.ipswRelease) {
									ForEach(VMImageCatalog.shared.availableIPSWImages) { os in
										Text(os.label).tag(os)
									}
								}
								.pickerStyle(.menu)
								.disabled(self.model.createVM)
								.labelsHidden()
								.onChange(of: model.ipswRelease) { _, newValue in
									self.config.imageName = newValue.url
								}
							}
							Toggle("Configure automaticly the system", isOn: $config.autoinstall).disabled(self.model.createVM)
						}
					case .qcow2:
						LabeledContent {
							TextField("Cloud Image", text: $config.imageName)
								.rounded(.leading)
								.frame(width: 460)
								.disabled(self.model.createVM)
						} label: {
							Picker("Preconfigured image", selection: $model.cloudImageRelease) {
								ForEach(VMImageCatalog.shared.availableCloudImages) { os in
									Text(os.label).tag(os)
								}
							}
							.pickerStyle(.menu)
							.disabled(self.model.createVM)
							.labelsHidden()
							.onChange(of: model.cloudImageRelease) { _, newValue in
								self.config.imageName = newValue.url
								newValue.applyMinimumResources(to: &self.config)
							}
						}

					case .oci:
						TextField("OCI Image", text: $config.imageName)
							.rounded(.leading)
							.disabled(self.model.createVM)

					case .template:
						Picker("Select a template", selection: $config.imageName) {
							ForEach(AppState.shared.templates, id: \.self) { template in
								Text(template.name).tag(template.fqn)
							}
						}
						.pickerStyle(.menu)
						.disabled(self.model.createVM)

					case .stream:
						VStack {
							Picker("Select remote sources", selection: $model.remoteImage) {
								ForEach(AppState.shared.remotes, id: \.self) { remote in
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
											Text(remoteImage.description).tag(remoteImage.id)
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
								if model.rootDisk.isEmpty {
									ForEach(ImageSource.allCases, id: \.self) { source in
										Text(source.description).tag(source)
									}
								} else {
									ForEach([ImageSource.iso, ImageSource.ipsw], id: \.self) { source in
										Text(source.description).tag(source)
									}
								}
							}.onChange(of: self.model.imageSource) { _, newValue in
								self.config.source = newValue
								self.config.diskFormat = newValue.supportedDiskFormat(for: self.config.diskFormat)

								switch newValue {
								case .raw:
									self.config.imageName = String.empty
									self.model.showDiskFormat = false
									self.config.diskFormat = .raw
									self.config.os = .linux
									self.config.autoinstall = false
									self.model.provisioningTemplate = String.empty
								case .qcow2:
									self.config.imageName = model.cloudImageRelease.url
									model.cloudImageRelease.applyMinimumResources(to: &self.config)
									self.model.showDiskFormat = false
									self.config.diskFormat = .raw
									self.config.os = .linux
									self.config.autoinstall = false
									self.model.provisioningTemplate = String.empty
								case .oci:
									self.config.imageName = String.empty
									self.model.showDiskFormat = false
									self.config.diskFormat = .raw
									self.config.os = .linux
									self.config.autoinstall = false
									self.model.provisioningTemplate = String.empty
								case .template:
									self.config.imageName = String.empty
									self.model.showDiskFormat = false
									self.config.diskFormat = .raw
									self.config.autoinstall = false
									self.model.provisioningTemplate = String.empty
								case .stream:
									self.config.imageName = String.empty
									self.model.showDiskFormat = false
									self.model.showDiskFormat = false
									self.config.diskFormat = .raw
									self.config.os = .linux
									self.config.autoinstall = false
									self.model.provisioningTemplate = String.empty
								case .iso:
									self.config.autoinstall = false
									self.config.imageName = self.model.isoImageRelease.url
									self.model.isoImageRelease.applyMinimumResources(to: &self.config)
									self.model.showDiskFormat = true
									self.config.diskFormat = .defaultSupportedFormat
									self.config.os = .linux
								case .ipsw:
									self.config.autoinstall = true
									self.config.imageName = self.model.ipswRelease.url
									self.config.cpuCount = max(self.config.cpuCount, 4)
									self.config.memorySizeInMoB = max(self.config.memorySizeInMoB, 4096)
									self.config.diskSizeInGiB = max(self.config.diskSizeInGiB, 40)
									self.model.showDiskFormat = true
									self.config.diskFormat = .defaultSupportedFormat
									self.config.os = .darwin
									self.config.autoinstall = false
									self.model.provisioningTemplate = String.empty
								}
							}
							.pickerStyle(.menu)
							.disabled(self.model.createVM)
							.labelsHidden()
						}.frame(width: 100)
					}
				}
			}

			let diskRange: ClosedRange<UInt64> = 5...UInt64(UInt16.max)
			let noRootDisk = (config.rootDisk ?? "").isEmpty

			Section("Root disk") {
				if self.model.rootDisk.isEmpty {
					HStack {
						Text("Disk size (GiB)")
						Spacer()
						HStack {
							TextField(String.empty, value: $config.diskSizeInGiB, format: .number)
								.rounded(.center)
								.frame(width: 50)
								.disabled(self.model.createVM && noRootDisk == false)
								.foregroundStyle(diskSizeValueIsInvalid ? Color.red : Color.primary)
								.onChange(of: config.diskSizeInGiB) { oldValue, newValue in
									let clamped = max(newValue, self.config.source == .ipsw ? 40 : 5)
									self.diskSizeValueIsInvalid = clamped != newValue
								}
							Stepper(value: $config.diskSizeInGiB, in: diskRange, step: 1) {

							}
							.labelsHidden()
							.disabled(self.model.createVM && noRootDisk == false)
						}
					}

					if self.model.showDiskFormat {
						LabeledContent("Root disk format") {
							HStack {
								Picker("Format", selection: $config.diskFormat) {
									ForEach(SupportedDiskFormat.allCases, id: \.self) { source in
										Text(source.description).tag(source)
									}
								}
								.pickerStyle(.menu)
								.disabled(self.model.createVM)
								.labelsHidden()
							}.frame(width: 100)
						}

						if Bundle.isApplicationSandboxed && self.config.diskFormat == .asif && AppState.shared.connectionMode != .app {
							Text("Warning by choosing asif format, command line tools will be unable to resize the disk. If you choose it, you must use diskutil to resize the disk.").font(.callout).foregroundStyle(Color.red)
						}
					}
				}

				if model.imageSource == .iso || model.imageSource == .ipsw {
					LabeledContent("Optional existing root disk (no copy)") {
						HStack {
							TextField("path", text: $model.rootDisk)
								.rounded(.leading)
								.disabled(self.model.createVM)
							Button(action: {
								model.rootDisk = chooseDocument(String(localized: "Choose a root disk"), showsHiddenFiles: true)?.path(percentEncoded: false) ?? String.empty
							}) {
								Image(systemName: "externaldrive.badge.plus")
							}
							.disabled(self.model.createVM)
							.buttonStyle(.borderless)
							.onChange(of: model.rootDisk) { _, newValue in
								if newValue.isEmpty {
									self.config.rootDisk = nil
								} else {
									if self.model.imageSource != .ipsw && self.model.imageSource != .iso {
										self.model.imageSource = .iso
									}

									self.config.rootDisk = newValue
								}
							}
						}
					}
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
				ForwardedPortView(forwardPorts: $config.forwardedPorts, disabled: $model.createVM).frame(height: listHeight)
			}
		}.formStyle(.grouped)
	}

	func networksView() -> some View {
		Form {
			Section("Network attachements") {
				NetworkAttachementView(networks: $config.networks, disabled: $model.createVM).frame(height: listHeight)
			}
		}.formStyle(.grouped)
	}

	func mountsView() -> some View {
		Form {
			Section("Directory sharing") {
				MountView(mounts: $model.mountPoints, disabled: $model.createVM).frame(height: listHeight)
					.onChange(of: model.mountPoints) { _, newValue in
						self.config.mounts = newValue.map { $0.directorySharingAttachment }
					}
			}
		}.formStyle(.grouped)
	}

	func diskAttachementView() -> some View {
		Form {
			Section("Disks attachements") {
				DiskAttachementView(attachedDisks: $config.attachedDisks, disabled: $model.createVM).frame(height: listHeight)
			}
		}.formStyle(.grouped)
	}

	func socketsView() -> some View {
		Form {
			Section("Virtual sockets") {
				SocketsView(sockets: $config.sockets, disabled: $model.createVM).frame(height: listHeight)
			}
		}.formStyle(.grouped)
	}

	func validateConfig(config: VirtualMachineConfig) {
		var valid = model.mountPoints.first(where: { $0.validate() == false }) == nil
		let platform = SupportedPlatform(rawValue: self.config.imageName)

		if valid {
			if config.os == .linux {
				valid = config.memorySizeInMoB >= 512 && config.diskSizeInGiB >= 5
			} else {
				valid = config.memorySizeInMoB >= 4096 && config.diskSizeInGiB >= 40
			}
		}

		if valid {
			// Belt-and-suspenders on top of the sliders' floor: catches a config that reached
			// this state some other way (a preset, or a config restored without going through
			// the sliders) still undercutting the selected image's minimum.
			valid = config.cpuCount >= self.minimumCPUCount && config.memorySizeInMoB >= self.minimumMemoryInMiB
		}

		if valid && model.rootDisk.isEmpty == false {
			valid = FileManager.default.fileExists(atPath: model.rootDisk)
		}

		if valid && model.imageSource == .iso && platform != .ubuntu && platform != .unknown && config.autoinstall {
			// A missing provisioningTemplate is fine when the detected platform has a built-in
			// default (see PackerLiteTemplateResolver) — only genuinely require one otherwise.
			valid = self.model.provisioningTemplate.isEmpty == false || PackerLiteTemplateResolver.hasBuiltInLinuxTemplate(for: platform)
		}

		if valid && (model.imageSource == .iso || model.imageSource == .ipsw || model.imageSource == .raw) {
			if let url = URL(spaced: config.imageName) {
				if AppState.shared.connectionMode == .app {
					valid =
						(url.isFileURL && FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
						|| ["http", "https"].contains(url.scheme)
						|| (url.scheme == nil && FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
				} else {
					valid = ["http", "https"].contains(url.scheme)
				}
			} else {
				valid = false
			}
		}

		if valid {
			if (config.configuredPassword ?? String.empty).isEmpty && config.clearPassword {
				valid = false
			} else if let vmname = config.vmname, self.config.imageName.isEmpty == false, vmname.isEmpty == false {
				valid = vmname.count <= URL.maxVirtualMachineNameLength && AppState.shared.findVirtualMachineDocument(vmname) == nil
			} else {
				valid = false
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

		await self.createVirtualMachine { result in
			guard self.model.createVM else {
				return
			}

			DispatchQueue.main.async {
				switch result {
				case .progress(_, let fractionCompleted):
					NotificationCenter.default.post(name: Self.ProgressCreateVirtualMachine, object: fractionCompleted, userInfo: ["wizardID": self.wizardID])

				case .terminated(let result, let message):
					if case .failure(let error) = result {
						NotificationCenter.default.post(name: Self.FailCreateVirtualMachine, object: error, userInfo: ["message": message ?? String.empty, "wizardID": self.wizardID])
					} else if case .success(let vmURL) = result {
						NotificationCenter.default.post(name: Self.CreatedVirtualMachine, object: vmURL, userInfo: ["message": message ?? String.empty, "wizardID": self.wizardID])
					} else {
						NotificationCenter.default.post(
							name: Self.FailCreateVirtualMachine, object: ServiceError(String(localized: "Internal error creating virtual machine")), userInfo: ["message": message ?? String.empty, "wizardID": self.wizardID])
					}

					done()

				case .step(let message):
					NotificationCenter.default.post(name: Self.ProgressTitleCreateVirtualMachine, object: message, userInfo: ["wizardID": self.wizardID])
				case .substep(let message):
					NotificationCenter.default.post(name: Self.ProgressSubtitleCreateVirtualMachine, object: message, userInfo: ["wizardID": self.wizardID])
				}
			}
		}
	}

	func createVirtualMachine(progressHandler: @escaping ProgressObserver.BuildProgressHandler) async {
		await withTaskCancellationHandler {
			defer {
				self.model.createVirtualMachineTask = nil
			}

			do {
				let options = self.config.buildOptions(wizardID, imageSource: model.imageSource)

				let build = try await AppState.shared.buildVirtualMachine(options: options, queue: Self.wizardQueue) { result in
					progressHandler(result)
				}

				if build.builded == false {
					progressHandler(.terminated(.failure(ServiceError(build.reason)), String(localized: "Create virtual machine failed")))
				}
			} catch {
				progressHandler(.terminated(.failure(error), String(localized: "Create virtual machine failed")))
			}
		} onCancel: {
			Task { @MainActor in
				self.model.createVirtualMachineTask = nil
				progressHandler(.terminated(.failure(ServiceError(String(localized: "Cancelled"))), String(localized: "Create virtual machine failed")))
			}
		}
	}

	func chooseDiskImage(ofTypes: [UTType]) -> String? {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: ofTypes, withTitle: String(localized: "Choose an image disk"), allowsOtherFileTypes: true) {
			return diskImg.absoluteURL.path(percentEncoded: false)
		}

		return nil
	}

	func chooseDiskImage(ofType: UTType = .diskImage) -> String? {
		return chooseDiskImage(ofTypes: [ofType])
	}

	func chooseDocument(_ title: String, ofType: UTType = .diskImage, showsHiddenFiles: Bool = false) -> URL? {
		if let diskImg = FileHelpers.selectSingleInputFile(ofType: [ofType], withTitle: title, allowsOtherFileTypes: true, showsHiddenFiles: showsHiddenFiles) {
			return diskImg.absoluteURL
		}

		return nil
	}

	func chooseYAML() -> String? {
		if let choosenFile = FileHelpers.selectSingleInputFile(ofType: [.yaml], withTitle: String(localized: "Choose a data file"), allowsOtherFileTypes: true) {
			return choosenFile.absoluteURL.path(percentEncoded: false)
		}

		return nil
	}

	func templates() -> [TemplateEntry] {
		return AppState.shared.loadTemplates()
	}

	func remotes() -> [RemoteEntry] {
		return AppState.shared.loadRemotes()
	}

	func images(remote: String) async -> [ShortImageInfo] {
		let result = await AppState.shared.loadImages(remote: remote)

		return result.compactMap {
			ShortImageInfo($0)
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
