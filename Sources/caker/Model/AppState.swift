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
	@Published var hasVMNetworking = Entitlement.hasVMNetworking()
	
	private var connectionManager: ConnectionManager
	private var gcd: ServerStreamingCall<Caked_Empty, Caked_Caked.Reply>? = nil
	private var openedVirtualMachines: [VirtualMachineDocument] = []

	deinit {
		agentStatusTimer?.cancel()
		gcd?.cancel(promise: nil)
	}
	
	private func receiveScreenshot(_ vmURL: URL, value: Data) async {
		if let document = self.findVirtualMachineDocument(vmURL) {
			await document.setScreenshot(value)
		} else {
			self.logger.debug("VM : \(vmURL.absoluteString) not found for screenshot")
		}
	}
	
	private func receiveUsage(_ vmURL: URL, value: Caked_CurrentUsageReply) async {
		if let document = self.findVirtualMachineDocument(vmURL) {
			await document.setUsage(value)
		} else {
			self.logger.debug("VM : \(vmURL.absoluteString) not found for usage")
		}
	}
	
	private func receiveStatus(_ vmURL: URL, value: Caked_VirtualMachineStatus) async {
		self.logger.debug("Handle new status \(value) for vm: \(vmURL.absoluteString)")
		
		if let document = self.findVirtualMachineDocument(vmURL) {
			await MainActor.run {
				document.setState(value)
				
				if value == .deleted {
					self.removeVirtualMachineDocument(vmURL)
				}
			}
		} else if value == .new {
			self.addVirtualMachineDocument(vmURL)
		} else {
			self.logger.debug("VM : \(vmURL.absoluteString) not found for status")
		}
	}
	
	private func gdc(client: CakedServiceClient) async {
		let asyncStream = AsyncThrowingStream.makeStream(of: [Caked_CurrentStatus].self)
		
		let stream = client.grandCentralDispatcher(.init(), callOptions: .init(timeLimit: .none)) { reply in
			_ = asyncStream.continuation.yield(reply.status.statuses)
			// Consider calling asyncStream.continuation.finish() when the stream should end
		}
		
		do {
			_ = try await stream.subchannel.get()
			
			for try await statuses in asyncStream.stream {
				for status in statuses {
					let vmURL = URL(string: "\(VMLocation.scheme)://\(status.name)")!
					
					switch status.message {
					case .status(let value):
						await self.receiveStatus(vmURL, value: value)
					case .screenshot(let value):
						await self.receiveScreenshot(vmURL, value: value)
					case .usage(let value):
						await self.receiveUsage(vmURL, value: value)
					default:
						break
					}
				}
			}
		} catch {
			stream.cancel(promise: nil)
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
		func startGrandCentral() {
			let gcdFuture = Utilities.group.next().makeFutureWithTask {
				await self.gdc(client: connectionManager.serviceClient!)
			}
			
			gcdFuture.whenFailure { error in
				self.logger.error("GCD failed: \(error)")
			}
			
			gcdFuture.whenComplete { _ in
				self.logger.debug("GCD stopped")
				self.gcd = nil
			}
		}
		
		self.logger.debug("Switching mode: installed=\(installed), connectionMode=\(connectionMode)")
		
		if connectionManager.connectionMode == .app {
			self.gcd?.cancel(promise: nil)
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
					
					if connectionMode != .app && self.gcd == nil {
						startGrandCentral()
					}
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
		
		let connectionMode = ConnectionManager.ConnectionMode(ServiceHandler.runningMode)
		let installed = ServiceHandler.isAgentInstalled
		
		if self.cakedServiceInstalled != installed || self.connectionMode != connectionMode {
			// Suspend timer
			self.logger.debug("Suspend timer for new mode: installed=\(installed), connectionMode=\(connectionMode)")
			self.agentStatusTimer = nil
			task.cancel()
			
			self.switchMode(installed, connectionManager: ConnectionManager(connectionMode: connectionMode))
		}
	}
	
	private init() {
		let connectionManager = ConnectionManager(connectionMode: ConnectionManager.ConnectionMode(ServiceHandler.runningMode))
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
	
	func connectToRemote(listenAddress: String, password: String? = nil, tls: Bool) {
		self.switchMode(self.cakedServiceInstalled, connectionManager: ConnectionManager(connectionMode: .remote, listenAddress: listenAddress, password: password, tls: tls))
	}
	
	func connectToLocal() {
		self.switchMode(self.cakedServiceInstalled, connectionManager: ConnectionManager(connectionMode: .app))
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
		
		return self.virtualMachines[url]
	}
	
	func findVirtualMachineDocument(_ url: URL) -> VirtualMachineDocument? {
		return self.virtualMachines[url]
	}
	
	func findVirtualMachineDocument(_ name: String) -> VirtualMachineDocument? {
		self.virtualMachines.values.first {
			$0.name == name
		}
	}
	
	func fullQualifiedVMUrl(_ vmURL: URL?) -> URL? {
		guard let vmURL = vmURL else {
			return nil
		}
		
		guard vmURL.isFileURL else {
			guard self.connectionMode == .app else {
				return vmURL
			}
			
			if let location = try? StorageLocation(runMode: self.connectionMode.runMode).find(vmURL.host(percentEncoded: false)!) {
				return location.rootURL
			}
			
			return nil
		}
		
		return vmURL
	}
	
	func tryVirtualMachineDocument(_ vmURL: URL) -> VirtualMachineDocument? {
		guard let vmURL = self.fullQualifiedVMUrl(vmURL) else {
			return nil
		}
		
		guard let vm = self.findVirtualMachineDocument(vmURL) else {
			guard let vm = try? VirtualMachineDocument.createVirtualMachineDocument(vmURL: vmURL, connectionManager: self.connectionManager) else {
				return nil
			}
			
			self.virtualMachines[vmURL] = vm
			
			return vm
		}
		
		return vm
	}
	
	@discardableResult
	func addVirtualMachineDocument(_ url: URL) -> VirtualMachineDocument? {
		guard let vm = self.findVirtualMachineDocument(url) else {
			guard let vm = try? VirtualMachineDocument.createVirtualMachineDocument(vmURL: url, connectionManager: self.connectionManager) else {
				return nil
			}
			
			self.virtualMachines[url] = vm
			return vm
		}
		
		return vm
	}
	
	func removeVirtualMachineDocument(_ url: URL) {
		if self.virtualMachines[url] != nil {
			self.virtualMachines.removeValue(forKey: url)
		}
	}
	
	func haveVirtualMachinesRunning() -> Bool {
		guard self.openedVirtualMachines.first( where: { $0.status == .running && $0.url.isFileURL && $0.externalRunning == false }) == nil else {
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
		if self.openedVirtualMachines.contains(document) == false {
			self.openedVirtualMachines.append(document)
		}
	}

	func closeVirtualMachineDocument(_ document: VirtualMachineDocument) {
		self.openedVirtualMachines.removeAll {
			$0.id == document.id
		}
	}
}
