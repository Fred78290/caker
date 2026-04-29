import CakedLib
import Foundation
import GRPC
import GRPCLib
import SwiftUI
import CakeAgentLib
import NIO

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
	static let AppStateChanged = Notification.Name("AppStateChanged")

	private struct ServiceReply {
		let remotes: [RemoteEntry]
		let templates: [TemplateEntry]
		let networks: [BridgedNetwork]
		let virtualMachines: [URL: VirtualMachineDocument]
	}
	
	private let logger = Logger("AppState")
	private var agentStatusTimer: RepeatedTask? = nil
	private static var _shared: AppState! = nil
	
	static func loadSharedAppState() async {
		Self._shared = AppState()
	}

	static var sharedLoaded: Bool {
		return Self._shared != nil
	}

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
	@Published var connectionMode: ConnectionManager.ConnectionMode = .app
	@Published var currentDocument: VirtualMachineDocument! {
		didSet {
			self.updateState()
		}
	}
	@Published var isAgentInstalling: Bool = false
	@Published var isStopped: Bool = true
	@Published var isSuspendable: Bool = false
	@Published var isRunning: Bool = false
	@Published var isPaused: Bool = false
	@Published var remotes: [RemoteEntry] = []
	@Published var templates: [TemplateEntry] = []
	@Published var networks: [BridgedNetwork] = []
	@Published var virtualMachines: [URL: VirtualMachineDocument] = [:]
	@Published var hasVMNetworking = Entitlement.hasVMNetworking()
	@Published var connectionManager: ConnectionManager

	private var openedVirtualMachines: [URL: VirtualMachineDocument] = [:]

	deinit {
		agentStatusTimer?.cancel()
		connectionManager.stopGrandCentral()
	}

	func updateState() {
		if let currentDocument {
			self.isAgentInstalling = currentDocument.agent == .installing && currentDocument.status == .running
			self.isStopped = currentDocument.status == .stopped || currentDocument.status == .stopping
			self.isRunning = currentDocument.status == .running || currentDocument.status == .starting
			self.isPaused = currentDocument.status == .paused || currentDocument.status == .pausing
			self.isSuspendable = currentDocument.status == .running && currentDocument.suspendable
		} else {
			self.isAgentInstalling = false
			self.isStopped = true
			self.isRunning = false
			self.isPaused = false
			self.isSuspendable = false
		}
	}

	private static func loadService(connectionManager: ConnectionManager) throws -> ServiceReply {
		Logger("AppState").debug("Loading data for mode: connectionMode=\(connectionManager.connectionMode.runMode)")
		
		return try ServiceReply(
			remotes: connectionManager.loadRemotes(),
			templates: connectionManager.loadTemplates(),
			networks: connectionManager.loadNetworks(),
			virtualMachines: connectionManager.loadVirtualMachines()
		)
	}
	
	private func switchMode(_ installed: Bool, connectionManager: ConnectionManager) {
		self.logger.debug("Switching mode: installed=\(installed), connectionMode=\(connectionMode)")

		if self.openedVirtualMachines.values.first(where: { document in
			self.connectionManager == document.connectionManager
		}) == nil {
			self.connectionManager.stopGrandCentral()
		}
		
		Utilities.group.next().makeFutureWithTask {
			try Self.loadService(connectionManager: connectionManager)
		}.whenComplete { result in
			let connectionMode = connectionManager.connectionMode
			
			self.logger.debug("Data loaded for new mode: installed=\(installed), runMode=\(connectionMode)")
			
			DispatchQueue.main.async {
				self.cakedServiceInstalled = installed
				self.cakedServiceRunning = connectionMode != .app
				self.connectionMode = connectionMode
				self.connectionManager = connectionManager
				
				switch result {
				case let .failure(error):
					alertError(error)
				case let .success(serviceReply):
					self.virtualMachines = serviceReply.virtualMachines
					self.networks = serviceReply.networks
					self.remotes = serviceReply.remotes
					self.templates = serviceReply.templates
					
					connectionManager.startGrandCentral()

					NotificationCenter.default.post(name: Self.AppStateChanged, object: connectionManager)
				}

				// Restart timer
				self.logger.debug("Restart timer for new mode: installed=\(installed), runMode=\(connectionMode)")
				self.agentStatusTimer = Utilities.group.next().scheduleRepeatedTask(initialDelay: .seconds(1), delay: .seconds(1)) { task in
					self.agentStatusWatch(task)
				}
			}
		}
	}
	
	func agentStatusWatch(_ task: RepeatedTask) {
		guard self.connectionMode != .remote else { return }

		let runMode = ServiceHandler.runningMode
		let connectionMode = ConnectionManager.ConnectionMode(runMode)
		let installed = ServiceHandler.isAgentInstalled
		
		if self.cakedServiceInstalled != installed || self.connectionMode != connectionMode {
			// Suspend timer
			self.logger.debug("Suspend timer for new mode: installed=\(installed), connectionMode=\(connectionMode)")
			self.agentStatusTimer = nil
			task.cancel()

			DispatchQueue.main.async {
				self.switchMode(installed, connectionManager: ConnectionManager.connectionManager(runMode))
			}
		}
	}
	
	private init() {
		let runMode = ServiceHandler.runningMode
		let connectionManager = ConnectionManager.connectionManager(runMode)
		let cakedServiceInstalled = ServiceHandler.isAgentInstalled
		let cakedServiceRunning = connectionManager.connectionMode != .app
		
		let env = ProcessInfo.processInfo.environment
		let isRunningInPreviews = env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
		let isRunningInTests = env["XCTestConfigurationFilePath"] != nil
		
		if !isRunningInPreviews && !isRunningInTests {
			MainUIAppDelegate.ensurePrivilegedBootstrapFiles()
		}
		
		// Start polling agent running status every second
		self.connectionMode = connectionManager.connectionMode
		self.cakedServiceInstalled = cakedServiceInstalled
		self.cakedServiceRunning = cakedServiceRunning
		self.connectionManager = connectionManager
		self.agentStatusTimer = nil
		
		if connectionManager.connectionMode == .app {
			self.agentStatusTimer = Utilities.group.next().scheduleRepeatedTask(initialDelay: .seconds(1), delay: .seconds(1)) { task in
				self.agentStatusWatch(task)
			}
			
			if let serviceReply = try? Self.loadService(connectionManager: connectionManager) {
				self.virtualMachines = serviceReply.virtualMachines
				self.networks = serviceReply.networks
				self.remotes = serviceReply.remotes
				self.templates = serviceReply.templates
			}
		} else {
			self.switchMode(cakedServiceInstalled, connectionManager: connectionManager)
		}
	}
	
	func connectToRemote(_ serviceURL: URL) {
		self.switchMode(self.cakedServiceInstalled, connectionManager: ConnectionManager(serviceURL: serviceURL))
	}
	
	func connectToLocal() {
		self.switchMode(self.cakedServiceInstalled, connectionManager: ConnectionManager.appConnectionManager)
	}
	
	func loadNetworks() -> [BridgedNetwork] {
		self.connectionManager.loadNetworks()
	}
	
	func reloadNetworks() {
		self.networks = self.loadNetworks()
	}
	
	func loadRemotes() -> [RemoteEntry] {
		if let result = try? self.connectionManager.loadRemotes() {
			return result
		}
		
		return []
	}
	
	func reloadRemotes() {
		self.remotes = self.loadRemotes()
	}
	
	func loadTemplates() -> [TemplateEntry] {
		if let result = try? self.connectionManager.loadTemplates() {
			return result
		}
		
		return []
	}
	
	func reloadTemplates() {
		self.templates = self.loadTemplates()
	}
	
	func loadImages(remote: String) async -> [ImageInfo] {
		if let result = try? await self.connectionManager.loadImages(remote: remote) {
			return result
		}
		
		return []
	}
	
	func createNetwork(network: BridgedNetwork) throws {
		try self.connectionManager.createNetwork(network: network)
		self.reloadNetworks()
	}
	
	func startNetwork(networkName: String) -> StartedNetworkReply {
		self.connectionManager.startNetwork(networkName: networkName)
	}
	
	func stopNetwork(networkName: String) -> StoppedNetworkReply {
		self.connectionManager.stopNetwork(networkName: networkName)
	}
	
	func createTemplate(templateName: String) throws -> CreateTemplateReply {
		guard let currentDocument = self.currentDocument else {
			throw ServiceError(String(localized: "No VM found"))
		}
		
		guard currentDocument.status.isStopped else {
			throw ServiceError(String(localized: "VM is running"))
		}
		
		return try self.connectionManager.createTemplate(vmURL: currentDocument.url, templateName: templateName)
	}
	
	func templateExists(name: String) -> Bool {
		self.connectionManager.templateExists(name: name)
	}
	
	func buildVirtualMachine(options: BuildOptions, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildedReply {
		try await self.connectionManager.buildVirtualMachine(options: options, queue: queue, progressHandler: progressHandler)
	}
	
	func findVirtualMachineDocument(_ url: URL?) -> VirtualMachineDocument? {
		guard let url else {
			return nil
		}

		guard let vm = self.openedVirtualMachines[url] else {
			return self.virtualMachines[url]
		}

		return vm
	}

	func findVirtualMachineDocument(_ name: String) -> VirtualMachineDocument? {
		findVirtualMachineDocument(self.connectionManager.vmURL(name))
	}
	
	func fullQualifiedVMUrl(_ vmURL: URL?) -> URL? {
		guard let vmURL = vmURL else {
			return nil
		}

		let storage = StorageLocation(runMode: self.connectionMode.runMode)

		// Try to convert local file URL to "vm://name"
		if vmURL.isFileURL {
			if self.connectionMode == .user || self.connectionMode == .system {
				// Look same place
				if vmURL.absoluteString.hasPrefix(storage.rootURL.absoluteString) {
					// Extract vm name
					let vmName = vmURL.lastPathComponent.deletingPathExtension

					// Find it
					if let location = try? storage.find(vmName), location.rootURL == vmURL {
						return URL(string: "\(VMLocation.scheme)://\(vmName)")!
					}
				}
			}
		} else if self.connectionMode == .app && VMLocation.supportedSchemes.contains(vmURL.scheme) {
			// We run standalone convert to file url
			if let location = try? StorageLocation(runMode: self.connectionMode.runMode).find(vmURL.host(percentEncoded: false)!) {
				return location.rootURL
			}
		}
		
		return vmURL
	}
	
	func tryVirtualMachineDocument(_ vmURL: URL) -> VirtualMachineDocument? {
		guard let vmURL = self.fullQualifiedVMUrl(vmURL) else {
			return nil
		}
		
		guard let vm = self.findVirtualMachineDocument(vmURL) else {
			guard let vm = try? VirtualMachineDocument.openVirtualMachineDocument(vmURL, connectionManager: self.connectionManager) else {
				return nil
			}
			
			self.virtualMachines[vmURL] = vm
			
			return vm
		}
		
		return vm
	}
	
	@discardableResult
	func addVirtualMachineDocument(_ vmURL: URL) -> VirtualMachineDocument? {
		guard let vm = self.findVirtualMachineDocument(vmURL) else {
			guard let vm = try? VirtualMachineDocument.openVirtualMachineDocument(vmURL, connectionManager: self.connectionManager) else {
				return nil
			}
			
			self.virtualMachines[vmURL] = vm
			return vm
		}
		
		return vm
	}
	
	func removeVirtualMachineDocument(_ vmURL: URL) {
		if self.virtualMachines[vmURL] != nil {
			self.virtualMachines.removeValue(forKey: vmURL)
		}

		if self.openedVirtualMachines[vmURL] != nil {
			self.openedVirtualMachines.removeValue(forKey: vmURL)
		}
	}
	
	func haveVirtualMachinesRunning() -> Bool {
		guard self.openedVirtualMachines.values.first( where: { $0.status == .running && $0.url.isFileURL && $0.externalRunning == false }) == nil else {
			return true
		}
		
		return virtualMachines.values.first { vm in
			guard vm.status == .running && vm.url.isFileURL else {
				return false
			}
			
			return vm.externalRunning == false
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
		
		alert.messageText = String(localized: "Create template")
		alert.informativeText = String(localized: "Name of the new template")
		alert.alertStyle = .informational
		alert.addButton(withTitle: String(localized: "Create"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		
		alert.accessoryView = txt
		
		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				let templateResult = try self.connectionManager.createTemplate(vmURL: vm.url, templateName: txt.stringValue)
				
				if templateResult.created == false {
					self.reloadTemplates()
				} else {
					DispatchQueue.main.async {
						alertError(String(localized: "Failed to create template"), templateResult.reason ?? String(localized: "Internal error"))
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}
	
	func duplicateVirtualMachine(document vm: VirtualMachineDocument) {
		let alert = NSAlert()
		let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
		
		alert.messageText = String(localized: "Duplicate virtual machine")
		alert.informativeText = String(localized: "Name of the new vm")
		alert.alertStyle = .informational
		alert.addButton(withTitle: String(localized: "Duplicate"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		
		alert.accessoryView = txt
		
		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				let result = try vm.duplicateVirtualMachine(to: txt.stringValue)
				
				if result.duplicated {
					if self.connectionMode == .app {
						let location = try StorageLocation(runMode: self.connectionMode.runMode).find(txt.stringValue)
						self.addVirtualMachineDocument(location.rootURL)
					} else if let vmURL = URL(string:"\(VMLocation.scheme)://\(txt.stringValue)") {
						self.addVirtualMachineDocument(vmURL)
					} else {
						DispatchQueue.main.async {
							alertError(String(localized: "Failed to duplicate virtual machine"), String(localized: "Internal error: invalid VM location URL"))
						}
					}
				} else {
					DispatchQueue.main.async {
						alertError(String(localized: "Failed to duplicate virtual machine"), result.reason)
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}
	
	func saveConfiguration(document vm: VirtualMachineDocument) {
		vm.saveConfiguration()
	}
	
	func deleteVirtualMachine(document vm: VirtualMachineDocument) {
		let alert = NSAlert()
		
		alert.messageText = String(localized: "Delete virtual machine")
		alert.informativeText = String(localized: "Are you sure you want to delete \(vm.name)? This action cannot be undone.")
		alert.alertStyle = .critical
		alert.addButton(withTitle: String(localized: "Delete"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		
		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				NotificationCenter.default.post(name: VirtualMachineDocument.DeleteVirtualMachine, object: vm, userInfo: ["document": vm.url!])
				
				let result = try vm.deleteVirtualMachine()
				
				if result.success {
					self.removeVirtualMachineDocument(vm.url)
				} else {
					DispatchQueue.main.async {
						alertError(String(localized: "Delete failed"), result.reason)
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
		
		alert.messageText = String(localized: "Delete network")
		alert.informativeText = String(localized: "Are you sure you want to delete network \(name)? This action cannot be undone.")
		alert.alertStyle = .critical
		alert.addButton(withTitle: String(localized: "Delete"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		
		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = self.connectionManager.deleteNetwork(networkName: name)
			
			if result.deleted {
				self.reloadNetworks()
			} else {
				DispatchQueue.main.async {
					alertError(String(localized: "Delete failed"), result.reason)
				}
			}
		}
	}
	
	func deleteTemplate(name: String) {
		let alert = NSAlert()
		
		alert.messageText = String(localized: "Delete template")
		alert.informativeText = String(localized: "Are you sure you want to delete template \(name)? This action cannot be undone.")
		alert.alertStyle = .critical
		alert.addButton(withTitle: String(localized: "Delete"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		
		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				let result = try self.connectionManager.deleteTemplate(templateName: name)
				
				if result.deleted {
					self.reloadTemplates()
				} else {
					DispatchQueue.main.async {
						alertError(String(localized: "Delete failed"), result.reason)
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}
	
	func deleteRemote(name: String) {
		let alert = NSAlert()
		
		alert.messageText = String(localized: "Delete remote")
		alert.informativeText = String(localized: "Are you sure you want to delete remote \(name)? This action cannot be undone.")
		alert.alertStyle = .critical
		alert.addButton(withTitle: String(localized: "Delete"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		
		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				let result = try self.connectionManager.deleteRemote(name: name)
				
				if result.deleted {
					self.reloadTemplates()
				} else {
					DispatchQueue.main.async {
						alertError(String(localized: "Delete failed"), result.reason)
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}
	
	func openVirtualMachineDocument(_ document: VirtualMachineDocument) {
		self.openedVirtualMachines[document.url] = document
	}

	func closeVirtualMachineDocument(_ document: VirtualMachineDocument) {
		self.openedVirtualMachines.removeValue(forKey: document.url)
	}
}
