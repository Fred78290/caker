import CakedLib
import Foundation
import GRPC
import GRPCLib
import SwiftUI

typealias VirtualMachineDocumentByURL = [URL: VirtualMachineDocument]

extension VirtualMachineDocumentByURL {
	var vms: [PairedVirtualMachineDocument] {
		self.compactMap {
			PairedVirtualMachineDocument(id: $0.key, name: $0.value.name, document: $0.value)
		}.sorted(using: PairedVirtualMachineDocumentComparator())
	}
}

struct RemoteHandlerComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: RemoteEntry, _ rhs: RemoteEntry) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

struct BridgedNetworkComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: BridgedNetwork, _ rhs: BridgedNetwork) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

struct TemplateEntryComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: TemplateEntry, _ rhs: TemplateEntry) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

extension RemoteEntry {
	var remoteData: RemoteData {
		RemoteData(remote: self.name)
	}
}

struct PairedVirtualMachineDocument: Identifiable {
	let id: URL
	let name: String
	let document: VirtualMachineDocument
}

struct PairedVirtualMachineDocumentComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: PairedVirtualMachineDocument, _ rhs: PairedVirtualMachineDocument) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

class AppState: ObservableObject, Observable {
	private var agentStatusTimer: Timer?
	private static var _shared: AppState! = nil

	static var shared: AppState {
		guard let shared = _shared else {
			_shared = AppState()
			return _shared
		}

		return shared
	}

	@AppStorage("VMLaunchMode") var launchVMExternally = false
	@AppStorage("ClipboardRedirectionEnabled") var isClipboardRedirectionEnabled = false
	@AppStorage("DebugVNCMessageEnabled") var debugVNCMessageEnabled: Bool = false

	@Published var cakedServiceInstalled: Bool = false
	@Published var cakedServiceRunning: Bool = false
	@Published var cakedServiceClient: CakedServiceClient? = nil
	@Published var runMode: Utils.RunMode = .app
	@Published var currentDocument: VirtualMachineDocument!
	@Published var isAgentInstalling: Bool = false
	@Published var isStopped: Bool = true
	@Published var isSuspendable: Bool = false
	@Published var isRunning: Bool = false
	@Published var isPaused: Bool = false
	@Published var remotes: [RemoteEntry] = []
	@Published var templates: [TemplateEntry] = []
	@Published var networks: [BridgedNetwork] = []
	@Published var virtualMachines: [URL: VirtualMachineDocument] = [:]

	deinit {
		agentStatusTimer?.invalidate()
	}

	init() {
		self.runMode = ServiceHandler.runningMode
		self.cakedServiceInstalled = ServiceHandler.isAgentInstalled
		self.cakedServiceRunning = self.runMode != .app

		if self.cakedServiceRunning {
			self.cakedServiceClient = ServiceHandler.serviceClient
		}

		self.virtualMachines = Self.loadVirtualMachines(client: self.cakedServiceClient, runMode: self.runMode)
		self.networks = Self.loadNetworks(client: self.cakedServiceClient, runMode: self.runMode)
		self.remotes = Self.loadRemotes(client: self.cakedServiceClient, runMode: self.runMode)
		self.templates = Self.loadTemplates(client: self.cakedServiceClient, runMode: self.runMode)

		// Start polling agent running status every second
		self.agentStatusTimer?.invalidate()
		self.agentStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
			guard let self = self else { return }

			let runMode = ServiceHandler.runningMode
			let installed = ServiceHandler.isAgentInstalled

			if self.cakedServiceInstalled != installed || self.runMode != runMode {
				DispatchQueue.main.async {
					if runMode != .app {
						self.cakedServiceClient = ServiceHandler.serviceClient
					}

					self.cakedServiceInstalled = installed
					self.cakedServiceRunning = runMode != .app
					self.runMode = runMode

					self.virtualMachines = Self.loadVirtualMachines(client: self.cakedServiceClient, runMode: runMode)
					self.networks = Self.loadNetworks(client: self.cakedServiceClient, runMode: runMode)
					self.remotes = Self.loadRemotes(client: self.cakedServiceClient, runMode: runMode)
					self.templates = Self.loadTemplates(client: self.cakedServiceClient, runMode: runMode)
				}
			}
		}
	}

	static func loadNetworks(client: CakedServiceClient?, runMode: Utils.RunMode) -> [BridgedNetwork] {
		guard let result = try? NetworksHandler.networks(client: client, runMode: runMode) else {
			return []
		}

		return result.networks.sorted(using: BridgedNetworkComparator())
	}

	static func loadRemotes(client: CakedServiceClient?, runMode: Utils.RunMode) -> [RemoteEntry] {
		guard let result = try? RemoteHandler.listRemote(client: client, runMode: runMode) else {
			return []
		}

		return result.remotes.sorted(using: RemoteHandlerComparator())
	}

	static func loadTemplates(client: CakedServiceClient?, runMode: Utils.RunMode) -> [TemplateEntry] {
		guard let result = try? TemplateHandler.listTemplate(client: client, runMode: runMode) else {
			return []
		}

		return result.templates.sorted(using: TemplateEntryComparator())
	}

	static func loadImages(client: CakedServiceClient?, remote: String, runMode: Utils.RunMode) async -> [ImageInfo] {
		await ImageHandler.listImage(client: client, remote: remote, runMode: runMode).infos
	}

	static func loadVirtualMachines(client: CakedServiceClient?, runMode: Utils.RunMode) -> ([URL: VirtualMachineDocument]) {
		guard let result = try? ListHandler.list(client: client, vmonly: true, runMode: runMode) else {
			return [:]
		}

		var vms: [URL: VirtualMachineDocument] = [:]

		if result.success {
			let storage = StorageLocation(runMode: runMode)

			result.infos.compactMap {
				if let location = try? storage.find($0.name) {
					return location
				}

				return nil
			}.forEach { location in
				if let vm = try? VirtualMachineDocument(location: location) {
					vms[location.rootURL] = vm
				}
			}
		}

		return vms
	}

	func loadNetworks() -> [BridgedNetwork] {
		Self.loadNetworks(client: self.cakedServiceClient, runMode: self.runMode)
	}

	func reloadNetworks() {
		self.networks = self.loadNetworks()
	}

	func loadRemotes() -> [RemoteEntry] {
		Self.loadRemotes(client: self.cakedServiceClient, runMode: self.runMode)
	}

	func reloadRemotes() {
		self.remotes = self.loadRemotes()
	}

	func loadTemplates() -> [TemplateEntry] {
		Self.loadTemplates(client: self.cakedServiceClient, runMode: self.runMode)
	}

	func reloadTemplates() {
		self.templates = self.loadTemplates()
	}

	func loadImages(remote: String) async -> [ImageInfo] {
		await Self.loadImages(client: self.cakedServiceClient, remote: remote, runMode: self.runMode)
	}

	func createNetwork(network: BridgedNetwork) throws {
		let vzNetwork = VZSharedNetwork(
			mode: network.mode == .shared ? .shared : .host,
			netmask: network.netmask,
			dhcpStart: network.dhcpStart,
			dhcpEnd: network.dhcpEnd,
			dhcpLease: Int32(network.dhcpLease),
			interfaceID: network.interfaceID,
			nat66Prefix: nil
		)

		_ = try NetworksHandler.create(client: self.cakedServiceClient, networkName: network.name, network: vzNetwork, runMode: self.runMode)

		self.reloadNetworks()
	}

	func startNetwork(networkName: String) -> StartedNetworkReply {
		NetworksHandler.start(client: self.cakedServiceClient, networkName: networkName, runMode: self.runMode)
	}

	func stopNetwork(networkName: String) -> StoppedNetworkReply {
		NetworksHandler.stop(client: self.cakedServiceClient, networkName: networkName, runMode: self.runMode)
	}

	func createTemplate(templateName: String) throws -> CreateTemplateReply {
		guard let currentDocument = self.currentDocument else {
			throw ServiceError("No VM found")
		}
		
		guard currentDocument.status.isStopped else {
			throw ServiceError("VM is running")
		}
		
		return try TemplateHandler.createTemplate(client: self.cakedServiceClient, sourceName: currentDocument.name, templateName: templateName, runMode: self.runMode)
	}

	func templateExists(name: String) -> Bool {
		TemplateHandler.exists(client: self.cakedServiceClient, name: name, runMode: self.runMode)
	}

	func findVirtualMachineDocument(_ url: URL) -> VirtualMachineDocument? {
		self.virtualMachines[url]
	}

	func findVirtualMachineDocument(_ name: String) -> VirtualMachineDocument? {
		self.virtualMachines.values.first {
			$0.name == name
		}
	}

	func addVirtualMachineDocument(_ location: VMLocation) {
		if self.virtualMachines[location.rootURL] == nil {
			if let vm = try? VirtualMachineDocument(location: location) {
				self.virtualMachines[location.rootURL] = vm
			}
		}
	}

	func removeVirtualMachineDocument(_ url: URL) {
		if self.virtualMachines[url] != nil {
			self.virtualMachines.removeValue(forKey: url)
		}
	}

	func haveVirtualMachinesRunning() -> Bool {
		return virtualMachines.values.first { vm in
			vm.status == .running && vm.externalRunning == false
		} != nil
	}

	func replaceVirtualMachineDocument(_ url: URL, with document: VirtualMachineDocument) {
		DispatchQueue.main.async {
			self.virtualMachines[url] = document
		}
	}

	func createTemplate(document vm: VirtualMachineDocument) {
		let alert = NSAlert()
		let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))

		alert.messageText = "Create template"
		alert.informativeText = "Name of the new template"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Create")
		alert.addButton(withTitle: "Cancel")

		alert.accessoryView = txt

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				let templateResult = try TemplateHandler.createTemplate(client: self.cakedServiceClient, sourceName: vm.name, templateName: txt.stringValue, runMode: self.runMode)
				
				if templateResult.created == false {
					self.reloadTemplates()
				} else {
					DispatchQueue.main.async {
						alertError("Failed to create template", templateResult.reason ?? "Internal error")
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}

	@discardableResult
	func startVirtualMachine(name: String) async throws -> StartedReply {
		StartedReply(name: name, ip: "", started: false, reason: "Not yet implemented")
	}

	@discardableResult
	func restartVirtualMachine(name: String, force: Bool = false, waitIPTimeout: Int = 30) async -> RestartReply {
		do {
			let result = try RestartHandler.restart(client: self.cakedServiceClient, name: name, force: force, waitIPTimeout: 30, runMode: self.runMode)
			
			if result.success == false {
				await alertError(result.reason, "Failed to restart VM")
			}
			
			return result
		} catch {
			await alertError(error)
			
			return .init(objects: [], success: false, reason: "\(error)")
		}
	}

	@discardableResult
	func stopVirtualMachine(name: String, force: Bool = false) async -> StopReply {
		do {
			let result = try StopHandler.stopVM(client: self.cakedServiceClient, name: name, force: force, runMode: self.runMode)

			if result.success == false {
				await alertError(result.reason, "Failed to stop VM")
			}

			return result
		} catch {
			await alertError(error)
			
			return .init(objects: [], success: false, reason: "\(error)")
		}
	}

	@discardableResult
	func suspendVirtualMachine(name: String) async -> SuspendReply {
		do {
			let result = try SuspendHandler.suspendVM(client: self.cakedServiceClient, name: name, runMode: self.runMode)

			if result.success == false {
				await alertError(result.reason, "Failed to suspend VM")
			}

			return result
		} catch {
			await alertError(error)
			
			return .init(objects: [], success: false, reason: "\(error)")
		}
	}

	func setVncScreenSize(name: String, screenSize: ViewSize) async {
		do {
			let result = try ScreenSizeHandler.setScreenSize(client: self.cakedServiceClient, name: name, width: Int(screenSize.width), height: Int(screenSize.height), runMode: self.runMode)

			if result.success == false {
				await alertError(result.reason, "Failed to set VM screen size")
			}
		} catch {
			await alertError(error)
		}
	}

	func getVncScreenSize(name: String, _ defaultSize: ViewSize = .zero) -> ViewSize {
		do {
			let result = try ScreenSizeHandler.getScreenSize(client: self.cakedServiceClient, name: name, runMode: self.runMode)
			
			if result.success == false {
				DispatchQueue.main.async {
					alertError(result.reason, "Failed to get VM screen size")
				}
			} else {
				return .init(width: CGFloat(result.width), height: CGFloat(result.height))
			}
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}

		return defaultSize
	}

	func vncURL(name: String) -> [URL]? {
		try? VncURLHandler.vncURL(client: self.cakedServiceClient, name: name, runMode: self.runMode)
	}

	func buildVirtualMachine(options: BuildOptions, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildedReply {
		try await BuildHandler.build(client: self.cakedServiceClient, options: options, runMode: self.runMode, queue: queue, progressHandler: progressHandler)
	}

	func duplicateVirtualMachine(document vm: VirtualMachineDocument) {
		let alert = NSAlert()
		let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))

		alert.messageText = "Duplicate virtual machine"
		alert.informativeText = "Name of the new vm"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Duplicate")
		alert.addButton(withTitle: "Cancel")

		alert.accessoryView = txt

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				let result = try DuplicateHandler.duplicate(client: self.cakedServiceClient, from: vm.name, to: txt.stringValue, resetMacAddress: true, runMode: self.runMode)
				if result.duplicated {
					let location = StorageLocation(runMode: self.runMode).location(txt.stringValue)
					
					self.addVirtualMachineDocument(location)
				} else {
					DispatchQueue.main.async {
						alertError("Failed to duplicate virtual machine", result.reason)
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}

	func deleteVirtualMachine(document vm: VirtualMachineDocument) {
		let alert = NSAlert()

		alert.messageText = "Delete virtual machine"
		alert.informativeText = "Are you sure you want to delete \(vm.name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				NotificationCenter.default.post(name: VirtualMachineDocument.DeleteVirtualMachine, object: vm.name, userInfo: ["document": vm.name])

				let result = try DeleteHandler.delete(client: self.cakedServiceClient, name: vm.name, runMode: self.runMode)

				if result.success {
					let location = StorageLocation(runMode: self.runMode).location(vm.name)

					self.removeVirtualMachineDocument(location.rootURL)
				} else {
					DispatchQueue.main.async {
						alertError(ServiceError(result.reason))
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}

	func deleteNetwork(name: String) {
		let alert = NSAlert()

		alert.messageText = "Delete network"
		alert.informativeText = "Are you sure you want to delete network \(name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = NetworksHandler.delete(networkName: name, runMode: self.runMode)

			if result.deleted {
				self.reloadNetworks()
			} else {
				DispatchQueue.main.async {
					alertError(ServiceError(result.reason))
				}
			}
		}
	}

	func deleteTemplate(name: String) {
		let alert = NSAlert()

		alert.messageText = "Delete template"
		alert.informativeText = "Are you sure you want to delete template \(name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = TemplateHandler.deleteTemplate(templateName: name, runMode: self.runMode)

			if result.deleted {
				self.reloadTemplates()
			} else {
				DispatchQueue.main.async {
					alertError(ServiceError(result.reason))
				}
			}
		}
	}

	func deleteRemote(name: String) {
		let alert = NSAlert()

		alert.messageText = "Delete remote"
		alert.informativeText = "Are you sure you want to delete remote \(name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = RemoteHandler.deleteRemote(name: name, runMode: self.runMode)

			if result.deleted {
				self.reloadTemplates()
			} else {
				DispatchQueue.main.async {
					alertError(ServiceError(result.reason))
				}
			}
		}
	}

	func installCakedService() {
		do {
			try ServiceHandler.installAgent(runMode: .user)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	func removeCakedService() {
		do {
			try ServiceHandler.uninstallAgent(runMode: self.runMode)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	func stopCakedService() {
		do {
			try ServiceHandler.stopAgent(runMode: self.runMode)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	func startCakedService() {
		do {
			try ServiceHandler.launchAgent(runMode: self.runMode)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
}
