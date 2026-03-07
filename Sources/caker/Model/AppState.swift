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

	private var gcd: ServerStreamingCall<Caked_Empty, Caked_Caked.Reply>? = nil

	deinit {
		agentStatusTimer?.cancel()
		gcd?.cancel(promise: nil)
	}

	var serviceClient: CakedServiceClient? {
		if self.runMode == .app {
			return nil
		}

		return self.cakedServiceClient
	}

	private func receiveScreenshot(name: String, screenshot: Data) async {
		
	}

	private func receiveUsage(name: String, usage: Caked_CurrentUsageReply) async {
		
	}

	private func receiveStatus(name: String, status: Caked_VirtualMachineStatus) async {
		
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
					switch status.message {
					case .status(let value):
						await self.receiveStatus(name: status.name, status: value)
					case .screenshot(let png):
						await self.receiveScreenshot(name: status.name, screenshot: png)
					case .usage(let usage):
						await self.receiveUsage(name: status.name, usage: usage)
					default:
						break
					}
				}
			}
		} catch {
			stream.cancel(promise: nil)
		}
	}

	private func switchMode(_ installed: Bool, runMode: Utils.RunMode) {
		struct ServiceReply {
			let remotes: [RemoteEntry]
			let templates: [TemplateEntry]
			let networks: [BridgedNetwork]
			let virtualMachines: [URL: VirtualMachineDocument]
		}

		if runMode == .app {
			self.gcd?.cancel(promise: nil)
		} else if gcd == nil {
			let gcdFuture = Utilities.group.next().makeFutureWithTask {
				await self.gdc(client: self.cakedServiceClient!)
			}
			
			gcdFuture.whenComplete { _ in
				self.gcd = nil
			}
		}

		let serviceReplyFuture = Utilities.group.next().makeFutureWithTask {
			ServiceReply(
				remotes: Self.loadRemotes(client: self.serviceClient, runMode: runMode),
				templates: Self.loadTemplates(client: self.serviceClient, runMode: runMode),
				networks: Self.loadNetworks(client: self.serviceClient, runMode: runMode),
				virtualMachines: Self.loadVirtualMachines(client: self.serviceClient, runMode: runMode)
			)
		}

		serviceReplyFuture.whenSuccess { serviceReply in
			DispatchQueue.main.async {
				if runMode == .app {
					self.cakedServiceClient = nil
				} else {
					self.cakedServiceClient = ServiceHandler.serviceClient
				}
				
				self.cakedServiceInstalled = installed
				self.cakedServiceRunning = runMode != .app
				self.runMode = runMode
				
				self.virtualMachines = serviceReply.virtualMachines
				self.networks = serviceReply.networks
				self.remotes = serviceReply.remotes
				self.templates = serviceReply.templates
			}
		}
	}

	init() {
		var cakedServiceClient: CakedServiceClient? = nil
		let runMode = ServiceHandler.runningMode
		let cakedServiceInstalled = ServiceHandler.isAgentInstalled
		let cakedServiceRunning = runMode != .app

		if cakedServiceRunning {
			cakedServiceClient = ServiceHandler.serviceClient
		}

		// Start polling agent running status every second
		let agentStatusTimer = Utilities.group.next().scheduleRepeatedTask(initialDelay: .seconds(1), delay: .seconds(1)) { task in
			let runMode = ServiceHandler.runningMode
			let installed = ServiceHandler.isAgentInstalled

			if self.cakedServiceInstalled != installed || self.runMode != runMode {
				self.switchMode(installed, runMode: runMode)
			}
		}

		self.agentStatusTimer = agentStatusTimer
		self.runMode = runMode
		self.cakedServiceInstalled = cakedServiceInstalled
		self.cakedServiceRunning = cakedServiceRunning
		self.cakedServiceClient = cakedServiceClient
		self.virtualMachines = Self.loadVirtualMachines(client: cakedServiceClient, runMode: runMode)
		self.networks = Self.loadNetworks(client: cakedServiceClient, runMode: runMode)
		self.remotes = Self.loadRemotes(client: cakedServiceClient, runMode: runMode)
		self.templates = Self.loadTemplates(client: cakedServiceClient, runMode: runMode)
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
		VirtualMachineDocument.createVirtualMachineDocuments(client: client, runMode: runMode)
	}

	func loadNetworks() -> [BridgedNetwork] {
		Self.loadNetworks(client: self.serviceClient, runMode: self.runMode)
	}

	func reloadNetworks() {
		self.networks = self.loadNetworks()
	}

	func loadRemotes() -> [RemoteEntry] {
		Self.loadRemotes(client: self.serviceClient, runMode: self.runMode)
	}

	func reloadRemotes() {
		self.remotes = self.loadRemotes()
	}

	func loadTemplates() -> [TemplateEntry] {
		Self.loadTemplates(client: self.serviceClient, runMode: self.runMode)
	}

	func reloadTemplates() {
		self.templates = self.loadTemplates()
	}

	func loadImages(remote: String) async -> [ImageInfo] {
		await Self.loadImages(client: self.serviceClient, remote: remote, runMode: self.runMode)
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

		_ = try NetworksHandler.create(client: self.serviceClient, networkName: network.name, network: vzNetwork, runMode: self.runMode)

		self.reloadNetworks()
	}

	func startNetwork(networkName: String) -> StartedNetworkReply {
		NetworksHandler.start(client: self.serviceClient, networkName: networkName, runMode: self.runMode)
	}

	func stopNetwork(networkName: String) -> StoppedNetworkReply {
		NetworksHandler.stop(client: self.serviceClient, networkName: networkName, runMode: self.runMode)
	}

	func createTemplate(templateName: String) throws -> CreateTemplateReply {
		guard let currentDocument = self.currentDocument else {
			throw ServiceError("No VM found")
		}
		
		guard currentDocument.status.isStopped else {
			throw ServiceError("VM is running")
		}
		
		return try TemplateHandler.createTemplate(client: self.serviceClient, rootURL: currentDocument.url, templateName: templateName, runMode: self.runMode)
	}

	func templateExists(name: String) -> Bool {
		TemplateHandler.exists(client: self.serviceClient, name: name, runMode: self.runMode)
	}

	func findVirtualMachineDocument(_ url: URL) -> VirtualMachineDocument? {
		self.virtualMachines[url]
	}

	func findVirtualMachineDocument(_ name: String) -> VirtualMachineDocument? {
		self.virtualMachines.values.first {
			$0.name == name
		}
	}

	func addVirtualMachineDocument(_ url: URL) {
		if self.virtualMachines[url] == nil {
			if let vm = try? VirtualMachineDocument.createVirtualMachineDocument(vmURL: url) {
				self.virtualMachines[url] = vm
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

	func installAgent(_ url: URL) throws -> Bool {
		let reply = try InstallAgentHandler.installAgent(client: self.serviceClient, rootURL: url, timeout: 2, runMode: self.runMode)

		return reply.installed
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
				let templateResult = try TemplateHandler.createTemplate(client: self.serviceClient, rootURL: vm.url, templateName: txt.stringValue, runMode: self.runMode)
				
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
	func startVirtualMachine(rootURL: URL, screenSize: GRPCLib.ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartHandler.StartMode) throws -> StartedReply {
		let result = try StartHandler.startVM(client: self.serviceClient, rootURL: rootURL, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: 30, startMode: startMode,runMode: self.runMode)
		
		if result.started == false {
			throw ServiceError("Failed to start VM")
		}
		
		return result
	}

	@discardableResult
	func restartVirtualMachine(rootURL: URL, force: Bool = false, waitIPTimeout: Int = 30) throws -> RestartReply {
		let result = try RestartHandler.restart(client: self.serviceClient, rootURL: rootURL, force: force, waitIPTimeout: 30, runMode: self.runMode)
			
		if result.success == false {
			throw ServiceError("Failed to restart VM")
		}
		
		return result
	}

	@discardableResult
	func stopVirtualMachine(rootURL: URL, force: Bool = false) throws -> StopReply {
		let result = try StopHandler.stopVM(client: self.serviceClient, rootURL: rootURL, force: force, runMode: self.runMode)

		if result.success == false {
			throw ServiceError("Failed to stop VM")
		}

		return result
	}

	@discardableResult
	func suspendVirtualMachine(rootURL: URL) throws -> SuspendReply {
		let result = try SuspendHandler.suspendVM(client: self.serviceClient, rootURL: rootURL, runMode: self.runMode)

		if result.success == false {
			throw ServiceError("Failed to suspend VM")
		}

		return result
	}

	func setVncScreenSize(rootURL: URL, screenSize: ViewSize) async {
		do {
			let result = try ScreenSizeHandler.setScreenSize(client: self.serviceClient, rootURL: rootURL, width: Int(screenSize.width), height: Int(screenSize.height), runMode: self.runMode)

			if result.success == false {
				await alertError(result.reason, "Failed to set VM screen size")
			}
		} catch {
			await alertError(error)
		}
	}

	func getVncScreenSize(rootURL: URL, _ defaultSize: ViewSize = .zero) -> ViewSize {
		do {
			let result = try ScreenSizeHandler.getScreenSize(client: self.serviceClient, rootURL: rootURL, runMode: self.runMode)
			
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

	func vncURL(rootURL: URL) throws -> [URL] {
		try VncURLHandler.vncURL(client: self.serviceClient, rootURL: rootURL, runMode: self.runMode)
	}

	func virtualMachineInfos(rootURL: URL) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {
		try InfosHandler.infos(client: self.serviceClient, rootURL: rootURL, runMode: self.runMode)
	}

	func buildVirtualMachine(options: BuildOptions, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildedReply {
		try await BuildHandler.build(client: self.serviceClient, options: options, runMode: self.runMode, queue: queue, progressHandler: progressHandler)
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
				let result = try DuplicateHandler.duplicate(client: self.serviceClient, rootURL: vm.url, to: txt.stringValue, resetMacAddress: true, runMode: self.runMode)
				if result.duplicated {
					let location = StorageLocation(runMode: self.runMode).location(txt.stringValue)
					self.addVirtualMachineDocument(location.rootURL)
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

	func saveConfiguration(document vm: VirtualMachineDocument) {
		do {
			if self.serviceClient != nil && vm.url.isFileURL == false {
				let reply = ConfigureHandler.configure(name: vm.name, options: vm.virtualMachineConfig.configureOptions(), runMode: self.runMode)
				
				if reply.configured == false {
					throw ServiceError("Failed to save VM configuration: \(reply.reason)")
				}

			} else if vm.url.isFileURL {
				try vm.virtualMachineConfig.saveLocally(vm.location!)
			} else {
				throw ServiceError("Failed to save VM configuration, Unexpected error")
			}

			vm.virtualMachineConfig.clearChangedFields()
		} catch {
			DispatchQueue.main.async {
				alertError(error)
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
				NotificationCenter.default.post(name: VirtualMachineDocument.DeleteVirtualMachine, object: vm, userInfo: ["document": vm.url!])

				let result = try DeleteHandler.delete(client: self.serviceClient, rootURL: vm.url, runMode: self.runMode)

				if result.success {
					self.removeVirtualMachineDocument(vm.url)
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
