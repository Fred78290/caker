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
	enum ConnectionMode: Sendable, Codable {
		case system
		case user
		case app
		case remote

		var runMode: Utils.RunMode {
			switch self {
			case .system:
				return .system
			case .user:
				return .user
			case .app:
				return .app
			case .remote:
				return .user
			}
		}
		
		init(_ from: Utils.RunMode) {
			switch from {
			case .system:
				self = .system
			case .user:
				self = .user
			case .app:
				self = .app
			}
		}
	}

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
	@Published var connectionMode: ConnectionMode = .app
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
	
	private var cakedServiceClient: CakedServiceClient? = nil
	private var gcd: ServerStreamingCall<Caked_Empty, Caked_Caked.Reply>? = nil
	private var listenAddress: String? = nil
	private var password: String? = nil
	private var tls: Bool = true

	deinit {
		agentStatusTimer?.cancel()
		gcd?.cancel(promise: nil)
	}
	
	var serviceClient: CakedServiceClient? {
		if self.connectionMode == .app {
			return nil
		}
		
		return self.cakedServiceClient
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
	
	private static func loadService(client: CakedServiceClient?, connectionMode: AppState.ConnectionMode, listenAddress: String?, password: String?, tls: Bool) throws -> ServiceReply {
		let runMode = connectionMode.runMode

		Logger("AppState").debug("Loading data for mode: connectionMode=\(connectionMode)")
		
		return try ServiceReply(
			remotes: Self.loadRemotes(client: client, runMode: runMode),
			templates: Self.loadTemplates(client: client, runMode: runMode),
			networks: Self.loadNetworks(client: client, runMode: runMode),
			virtualMachines: Self.loadVirtualMachines(client: client, connectionMode: connectionMode, listenAddress: listenAddress, password: password, tls: tls)
		)
	}

	private func switchMode(_ installed: Bool, connectionMode: ConnectionMode, listenAddress: String?, password: String?, tls: Bool) {
		func startGrandCentral() {
			let gcdFuture = Utilities.group.next().makeFutureWithTask {
				await self.gdc(client: self.cakedServiceClient!)
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

		if connectionMode == .app {
			self.gcd?.cancel(promise: nil)
			self.cakedServiceClient = nil
		} else if connectionMode == .remote {
			self.cakedServiceClient = try? ServiceHandler.createCakedServiceClient(listenAddress: listenAddress, password: password, tls: tls, runMode: .user)
		} else {
			self.cakedServiceClient = ServiceHandler.serviceClient
		}
				
		Utilities.group.next().makeFutureWithTask {
			try Self.loadService(client: self.cakedServiceClient, connectionMode: connectionMode, listenAddress: listenAddress, password: password, tls: tls)
		}.whenComplete { result in
			self.logger.debug("Data loaded for new mode: installed=\(installed), runMode=\(connectionMode)")

			DispatchQueue.main.async {
				self.cakedServiceInstalled = installed
				self.cakedServiceRunning = connectionMode != .app
				self.connectionMode = connectionMode
				self.listenAddress = listenAddress
				self.password = password
				self.tls = tls
	
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

		let connectionMode = ConnectionMode(ServiceHandler.runningMode)
		let installed = ServiceHandler.isAgentInstalled
		
		if self.cakedServiceInstalled != installed || self.connectionMode != connectionMode {
			// Suspend timer
			self.logger.debug("Suspend timer for new mode: installed=\(installed), connectionMode=\(connectionMode)")
			self.agentStatusTimer = nil
			task.cancel()

			self.switchMode(installed, connectionMode: connectionMode, listenAddress: nil, password: nil, tls: true)
		}
	}

	private init() {
		var cakedServiceClient: CakedServiceClient? = nil
		let connectionMode = ConnectionMode(ServiceHandler.runningMode)
		let cakedServiceInstalled = ServiceHandler.isAgentInstalled
		let cakedServiceRunning = connectionMode != .app
		
		let env = ProcessInfo.processInfo.environment
		let isRunningInPreviews = env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
		let isRunningInTests = env["XCTestConfigurationFilePath"] != nil
		
		if !isRunningInPreviews && !isRunningInTests {
			MainUIAppDelegate.ensurePrivilegedBootstrapFiles()
		}

		if cakedServiceRunning {
			cakedServiceClient = ServiceHandler.serviceClient
		}
		
		// Start polling agent running status every second
		self.connectionMode = connectionMode
		self.cakedServiceInstalled = cakedServiceInstalled
		self.cakedServiceRunning = cakedServiceRunning
		self.cakedServiceClient = cakedServiceClient
		self.agentStatusTimer = nil

		if connectionMode == .app {
			self.agentStatusTimer = Utilities.group.next().scheduleRepeatedTask(initialDelay: .seconds(1), delay: .seconds(1)) { task in
				self.agentStatusWatch(task)
			}

			if let serviceReply = try? Self.loadService(client: nil, connectionMode: .app, listenAddress: nil, password: nil, tls: true) {
				self.virtualMachines = serviceReply.virtualMachines
				self.networks = serviceReply.networks
				self.remotes = serviceReply.remotes
				self.templates = serviceReply.templates
			}
		} else {
			self.switchMode(cakedServiceInstalled, connectionMode: connectionMode, listenAddress: nil, password: nil, tls: true)
		}
	}

	func connectToRemote(listenAddress: String, password: String? = nil, tls: Bool) {
		self.switchMode(self.cakedServiceInstalled, connectionMode: .remote, listenAddress: listenAddress, password: password, tls: tls)
	}

	static func loadNetworks(client: CakedServiceClient?, runMode: Utils.RunMode) -> [BridgedNetwork] {
		guard let result = try? NetworksHandler.networks(client: client, runMode: runMode) else {
			return []
		}
		
		return result.networks.sorted(using: BridgedNetworkComparator())
	}
	
	static func loadRemotes(client: CakedServiceClient?, runMode: Utils.RunMode)throws  -> [RemoteEntry] {
		return try RemoteHandler.listRemote(client: client, runMode: runMode).remotes.sorted(using: RemoteHandlerComparator())
	}
	
	static func loadTemplates(client: CakedServiceClient?, runMode: Utils.RunMode) throws -> [TemplateEntry] {
		try TemplateHandler.listTemplate(client: client, runMode: runMode).templates.sorted(using: TemplateEntryComparator())
	}
	
	static func loadImages(client: CakedServiceClient?, remote: String, runMode: Utils.RunMode) async throws -> [ImageInfo] {
		try await ImageHandler.listImage(client: client, remote: remote, runMode: runMode).infos
	}
	
	static func loadVirtualMachines(client: CakedServiceClient?, connectionMode: AppState.ConnectionMode, listenAddress: String?, password: String?, tls: Bool) throws -> ([URL: VirtualMachineDocument]) {
		return try VirtualMachineDocument.loadVirtualMachineDocuments(client: client, connectionMode: connectionMode, listenAddress: listenAddress, password: password, tls: tls)
	}
	
	func loadNetworks() -> [BridgedNetwork] {
		Self.loadNetworks(client: self.serviceClient, runMode: self.connectionMode.runMode)
	}
	
	func reloadNetworks() {
		self.networks = self.loadNetworks()
	}
	
	func loadRemotes() -> [RemoteEntry] {
		if let result = try? Self.loadRemotes(client: self.serviceClient, runMode: self.connectionMode.runMode) {
			return result
		}
		
		return []
	}
	
	func reloadRemotes() {
		self.remotes = self.loadRemotes()
	}
	
	func loadTemplates() -> [TemplateEntry] {
		if let result = try? Self.loadTemplates(client: self.serviceClient, runMode: self.connectionMode.runMode) {
			return result
		}
		
		return []
	}
	
	func reloadTemplates() {
		self.templates = self.loadTemplates()
	}
	
	func loadImages(remote: String) async -> [ImageInfo] {
		if let result = try? await Self.loadImages(client: self.serviceClient, remote: remote, runMode: self.connectionMode.runMode) {
			return result
		}
		
		return []
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
		
		_ = try NetworksHandler.create(client: self.serviceClient, networkName: network.name, network: vzNetwork, runMode: self.connectionMode.runMode)
		
		self.reloadNetworks()
	}
	
	func startNetwork(networkName: String) -> StartedNetworkReply {
		NetworksHandler.start(client: self.serviceClient, networkName: networkName, runMode: self.connectionMode.runMode)
	}
	
	func stopNetwork(networkName: String) -> StoppedNetworkReply {
		NetworksHandler.stop(client: self.serviceClient, networkName: networkName, runMode: self.connectionMode.runMode)
	}
	
	func createTemplate(templateName: String) throws -> CreateTemplateReply {
		guard let currentDocument = self.currentDocument else {
			throw ServiceError(String(localized: "No VM found"))
		}
		
		guard currentDocument.status.isStopped else {
			throw ServiceError(String(localized: "VM is running"))
		}
		
		return try TemplateHandler.createTemplate(client: self.serviceClient, vmURL: currentDocument.url, templateName: templateName, runMode: self.connectionMode.runMode)
	}
	
	func templateExists(name: String) -> Bool {
		TemplateHandler.exists(client: self.serviceClient, name: name, runMode: self.connectionMode.runMode)
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
			guard let vm = try? VirtualMachineDocument.createVirtualMachineDocument(vmURL: vmURL, connectionMode: self.connectionMode, listenAddress: self.listenAddress, password: self.password, tls: self.tls) else {
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
			guard let vm = try? VirtualMachineDocument.createVirtualMachineDocument(vmURL: url, connectionMode: self.connectionMode, listenAddress: self.listenAddress, password: self.password, tls: self.tls) else {
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
	
	func installAgent(_ url: URL) throws -> Bool {
		let reply = try InstallAgentHandler.installAgent(client: self.serviceClient, vmURL: url, timeout: 2, runMode: self.connectionMode.runMode)
		
		return reply.installed
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
				let templateResult = try TemplateHandler.createTemplate(client: self.serviceClient, vmURL: vm.url, templateName: txt.stringValue, runMode: self.connectionMode.runMode)
				
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
	
	@discardableResult
	func startVirtualMachine(vmURL: URL, screenSize: GRPCLib.ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartHandler.StartMode, recoveryMode: Bool) throws -> StartedReply {
		let result = try StartHandler.startVM(client: self.serviceClient, vmURL: vmURL, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, recoveryMode: recoveryMode, runMode: self.connectionMode.runMode)
		
		if result.started == false {
			throw ServiceError(String(localized: "Failed to start VM"))
		}
		
		return result
	}
	
	@discardableResult
	func restartVirtualMachine(vmURL: URL, force: Bool = false, waitIPTimeout: Int = 30) throws -> RestartReply {
		let result = try RestartHandler.restart(client: self.serviceClient, vmURL: vmURL, force: force, waitIPTimeout: 30, runMode: self.connectionMode.runMode)
		
		if result.success == false {
			throw ServiceError(String(localized: "Failed to restart VM"))
		}
		
		return result
	}
	
	@discardableResult
	func stopVirtualMachine(vmURL: URL, force: Bool = false) throws -> StopReply {
		let result = try StopHandler.stopVM(client: self.serviceClient, vmURL: vmURL, force: force, runMode: self.connectionMode.runMode)
		
		if result.success == false {
			throw ServiceError(String(localized: "Failed to stop VM"))
		}
		
		return result
	}
	
	@discardableResult
	func suspendVirtualMachine(vmURL: URL) throws -> SuspendReply {
		let result = try SuspendHandler.suspendVM(client: self.serviceClient, vmURL: vmURL, runMode: self.connectionMode.runMode)
		
		if result.success == false {
			throw ServiceError(String(localized: "Failed to suspend VM"))
		}
		
		return result
	}
	
	func setVncScreenSize(vmURL: URL, screenSize: ViewSize) async {
		do {
			let result = try ScreenSizeHandler.setScreenSize(client: self.serviceClient, vmURL: vmURL, width: Int(screenSize.width), height: Int(screenSize.height), runMode: self.connectionMode.runMode)
			
			if result.success == false {
				await alertError(String(localized: "Failed to set VM screen size"), result.reason)
			}
		} catch {
			await alertError(error)
		}
	}
	
	func getVncScreenSize(vmURL: URL, _ defaultSize: ViewSize = .zero) -> ViewSize {
		do {
			let result = try ScreenSizeHandler.getScreenSize(client: self.serviceClient, vmURL: vmURL, runMode: self.connectionMode.runMode)
			
			if result.success == false {
				DispatchQueue.main.async {
					alertError(String(localized: "Failed to get VM screen size"), result.reason)
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
	
	func vncInfos(vmURL: URL) throws -> VNCInfos {
		try VNCInfosHandler.vncInfos(client: self.serviceClient, vmURL: vmURL, runMode: self.connectionMode.runMode)
	}
	
	func virtualMachineInfos(vmURL: URL) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {
		try InfosHandler.infos(client: self.serviceClient, vmURL: vmURL, runMode: self.connectionMode.runMode)
	}
	
	func buildVirtualMachine(options: BuildOptions, queue: DispatchQueue? = nil, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async throws -> BuildedReply {
		try await BuildHandler.build(client: self.serviceClient, options: options, runMode: self.connectionMode.runMode, queue: queue, progressHandler: progressHandler)
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
				let result = try DuplicateHandler.duplicate(client: self.serviceClient, vmURL: vm.url, to: txt.stringValue, resetMacAddress: true, runMode: self.connectionMode.runMode)
				if result.duplicated {
					if self.serviceClient == nil {
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
		do {
			if self.serviceClient != nil && vm.url.isFileURL == false {
				let reply = ConfigureHandler.configure(name: vm.name, options: vm.virtualMachineConfig.configureOptions(), runMode: self.connectionMode.runMode)
				
				if reply.configured == false {
					throw ServiceError(String(localized: "Failed to save VM configuration: \(reply.reason)"))
				}
				
			} else if let virtualMachine = vm.virtualMachine {
				try vm.virtualMachineConfig.saveLocally(virtualMachine.config)
			} else if let location = vm.location {
				try vm.virtualMachineConfig.saveLocally(location)
			} else {
				throw ServiceError(String(localized: "Failed to save VM configuration, Unexpected error"))
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
		
		alert.messageText = String(localized: "Delete virtual machine")
		alert.informativeText = String(localized: "Are you sure you want to delete \(vm.name)? This action cannot be undone.")
		alert.alertStyle = .critical
		alert.addButton(withTitle: String(localized: "Delete"))
		alert.addButton(withTitle: String(localized: "Cancel"))
		
		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				NotificationCenter.default.post(name: VirtualMachineDocument.DeleteVirtualMachine, object: vm, userInfo: ["document": vm.url!])
				
				let result = try DeleteHandler.delete(client: self.serviceClient, vmURL: vm.url, runMode: self.connectionMode.runMode)
				
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
			let result = NetworksHandler.delete(networkName: name, runMode: self.connectionMode.runMode)
			
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
			let result = TemplateHandler.deleteTemplate(templateName: name, runMode: self.connectionMode.runMode)
			
			if result.deleted {
				self.reloadTemplates()
			} else {
				DispatchQueue.main.async {
					alertError(String(localized: "Delete failed"), result.reason)
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
			let result = RemoteHandler.deleteRemote(name: name, runMode: self.connectionMode.runMode)
			
			if result.deleted {
				self.reloadTemplates()
			} else {
				DispatchQueue.main.async {
					alertError(String(localized: "Delete failed"), result.reason)
				}
			}
		}
	}
	
}
