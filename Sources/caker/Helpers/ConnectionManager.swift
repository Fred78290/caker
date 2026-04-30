//
//  ConnectionManager.swift
//  Caker
//
//  Created by Frederic BOLTZ on 24/04/2026.
//
import Foundation
import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib

class ConnectionManager: Equatable {
	typealias AsyncThrowingStreamCurrentStatus = (stream: AsyncThrowingStream<[Caked_CurrentStatus], Error>, continuation: AsyncThrowingStream<[Caked_CurrentStatus], Error>.Continuation)

	static func == (lhs: ConnectionManager, rhs: ConnectionManager) -> Bool {
		return lhs.connectionMode == rhs.connectionMode
		&& lhs.serviceURL == rhs.serviceURL
	}
	
	static let appConnectionManager = ConnectionManager(connectionMode: .app)
	static let userConnectionManager = ConnectionManager(connectionMode: .user)
	static let systemConnectionManager = ConnectionManager(connectionMode: .system)

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
	
	let connectionMode: ConnectionMode
	let serviceURL: URL?

	private var gcd: ServerStreamingCall<Caked_Empty, Caked_Caked.Reply>? = nil
	private var currentStatus: AsyncThrowingStreamCurrentStatus? = nil
	private let logger = Logger("ConnectionManager")

	deinit {
		if let serviceURL = self.serviceURL {
			self.logger.debug("Release remote ConnectionManager: \(serviceURL.hiddenPasswordURL)")
		} else {
			self.logger.debug("Release local ConnectionManager: \(self.connectionMode)")
		}
		self.stopGrandCentral()
	}

	static func connectionManager(_ runMode: Utils.RunMode) -> ConnectionManager {
		switch runMode {
		case .system:
			return systemConnectionManager
		case .user:
			return userConnectionManager
		case .app:
			return appConnectionManager
		}
	}

	static func connectionManager(_ vmURL: URL, connectionMode: ConnectionMode) -> ConnectionManager {
		if vmURL.isFileURL || vmURL.scheme == nil {
			return self.appConnectionManager
		}

		guard vmURL.path.isEmpty else {
			return ConnectionManager(vmURL)
		}
		
		if connectionMode == .system {
			return systemConnectionManager
		} else if connectionMode == .user {
			return userConnectionManager
		} else {
			return appConnectionManager
		}
	}

	init(serviceURL: URL) {
		self.connectionMode = .remote
		self.serviceURL = serviceURL
	}

	private init(connectionMode: ConnectionMode) {
		self.connectionMode = connectionMode
		self.serviceURL = nil
	}

	private init(_ vmURL: URL) {
		var components = URLComponents(url: vmURL, resolvingAgainstBaseURL: false)!

		if components.path.isEmpty {
			self.serviceURL = nil
			self.connectionMode = .user
		} else {
			components.scheme = vmURL.scheme == VMLocation.scheme ? "tcp" : "tcps"
			components.path = ""
			self.serviceURL = components.url!
			self.connectionMode = .remote
		}
	}

	var serviceClient: CakedServiceClient? {
		if self.connectionMode == .app {
			return nil
		}
		
		if self.connectionMode != .remote {
			return try? ServiceHandler.createCakedServiceClient(tls: true, runMode: self.connectionMode.runMode)
		}
		
		return try? ServiceHandler.createCakedServiceClient(serviceURL: self.serviceURL!, runMode: connectionMode.runMode)
	}

	func vmURL(_ name: String) -> URL {
		var components = URLComponents()

		if self.connectionMode == .remote {
			components.scheme = ["tcps", "https"].contains(self.serviceURL!.scheme) ? "\(VMLocation.scheme)s" : VMLocation.scheme
			components.host = self.serviceURL!.host!
			components.port = self.serviceURL!.port
			components.password = self.serviceURL!.password(percentEncoded: false)
			components.path = "/\(name)"
		} else {
			components.scheme = VMLocation.scheme
			components.host = name
		}

		return components.url!
	}

	func loadNetworks() -> [BridgedNetwork] {
		guard let result = try? NetworksHandler.networks(client: self.serviceClient, runMode: self.connectionMode.runMode) else {
			return []
		}
		
		return result.networks.sorted(using: BridgedNetworkComparator())
	}
	
	func loadRemotes()throws  -> [RemoteEntry] {
		return try RemoteHandler.listRemote(client: self.serviceClient, runMode: self.connectionMode.runMode).remotes.sorted(using: RemoteHandlerComparator())
	}
	
	func loadTemplates() throws -> [TemplateEntry] {
		try TemplateHandler.listTemplate(client: self.serviceClient, runMode: self.connectionMode.runMode).templates.sorted(using: TemplateEntryComparator())
	}
	
	func loadImages(remote: String) async throws -> [ImageInfo] {
		try await ImageHandler.listImage(client: self.serviceClient, remote: remote, runMode: self.connectionMode.runMode).infos
	}
	
	func loadVirtualMachines() throws -> ([URL: VirtualMachineDocument]) {
		return try VirtualMachineDocument.loadVirtualMachineDocuments(connectionManager: self)
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
	}
	
	func startNetwork(networkName: String) -> StartedNetworkReply {
		NetworksHandler.start(client: self.serviceClient, networkName: networkName, runMode: self.connectionMode.runMode)
	}
	
	func stopNetwork(networkName: String) -> StoppedNetworkReply {
		NetworksHandler.stop(client: self.serviceClient, networkName: networkName, runMode: self.connectionMode.runMode)
	}
	
	func deleteNetwork(networkName: String) -> DeleteNetworkReply {
		NetworksHandler.delete(client: self.serviceClient, networkName: networkName, runMode: self.connectionMode.runMode)
	}
	
	func createTemplate(vmURL: URL, templateName: String) throws -> CreateTemplateReply {
		return try TemplateHandler.createTemplate(client: self.serviceClient, vmURL: vmURL, templateName: templateName, runMode: self.connectionMode.runMode)
	}
	
	func deleteTemplate(templateName: String) throws -> DeleteTemplateReply {
		return try TemplateHandler.deleteTemplate(client: self.serviceClient, templateName: templateName, runMode: self.connectionMode.runMode)
	}
	
	func templateExists(name: String) -> Bool {
		TemplateHandler.exists(client: self.serviceClient, name: name, runMode: self.connectionMode.runMode)
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
		return try SuspendHandler.suspendVM(client: self.serviceClient, vmURL: vmURL, runMode: self.connectionMode.runMode)
	}
	
	func deleteVirtualMachine(vmURL: URL) throws -> DeleteReply {
		return try DeleteHandler.delete(client: self.serviceClient, vmURL: vmURL, runMode: self.connectionMode.runMode)
	}

	func duplicateVirtualMachine(vmURL: URL, to: String, resetMacAddress: Bool) throws -> DuplicatedReply {
		return try DuplicateHandler.duplicate(client: self.serviceClient, vmURL: vmURL, to: to, resetMacAddress: resetMacAddress, runMode: self.connectionMode.runMode)
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

	func installAgent(_ url: URL) throws -> Bool {
		let reply = try InstallAgentHandler.installAgent(client: self.serviceClient, vmURL: url, timeout: 2, runMode: self.connectionMode.runMode)
		
		return reply.installed
	}
	
	func deleteRemote(name: String) throws -> DeleteRemoteReply {
		try RemoteHandler.deleteRemote(client: self.serviceClient, name: name, runMode: self.connectionMode.runMode)
	}
}

extension ConnectionManager {
	public static let GrandCentralDidTerminateNotification = NSNotification.Name(rawValue: "GrandCentralDidTerminateNotification")
	public static let GrandCentralDidStartNotification = NSNotification.Name(rawValue: "GrandCentralDidStartNotification")

	func stopGrandCentral() {
		if let gcd = self.gcd {
			self.currentStatus?.continuation.finish(throwing: CancellationError())
			self.currentStatus = nil

			gcd.cancel(promise: nil)
			self.gcd = nil
			
			NotificationCenter.default.post(name: Self.GrandCentralDidTerminateNotification, object: self)
		}
	}

	func startGrandCentral() {
		guard let serviceClient = self.serviceClient else {
			return
		}

		let gcdFuture = Utilities.group.next().makeFutureWithTask {
			await self.gdc(client: serviceClient)
		}
		
		gcdFuture.whenFailure { error in
			self.logger.error("GCD failed: \(error)")
		}
		
		gcdFuture.whenComplete { _ in
			self.logger.debug("GCD stopped")
			self.gcd = nil
		}

		NotificationCenter.default.post(name: Self.GrandCentralDidStartNotification, object: self)
	}

	private func receiveScreenshot(_ vmURL: URL, value: Data) async {
		if let document = AppState.shared.findVirtualMachineDocument(vmURL) {
			await document.setScreenshot(value)
		} else if AppState.shared.connectionManager == self {
			self.logger.debug("VM : \(vmURL.hiddenPasswordURL) not found for screenshot")
		}
	}
	
	private func receiveUsage(_ vmURL: URL, value: Caked_CurrentUsageReply) async {
		if let document = AppState.shared.findVirtualMachineDocument(vmURL) {
			await document.setUsage(value)
		} else if AppState.shared.connectionManager == self {
			self.logger.debug("VM : \(vmURL.hiddenPasswordURL) not found for usage")
		}
	}
	
	private func receiveStatus(_ vmURL: URL, value: Caked_VirtualMachineStatus) async {
		self.logger.debug("Handle new status \(value) for vm: \(vmURL.hiddenPasswordURL)")

		if let document = AppState.shared.findVirtualMachineDocument(vmURL) {
			await MainActor.run {
				document.setState(value)
				
				if value == .deleted {
					AppState.shared.removeVirtualMachineDocument(vmURL)
				}
			}
		} else if value == .new {
			AppState.shared.addVirtualMachineDocument(vmURL)
		} else if AppState.shared.connectionManager == self {
			self.logger.debug("VM : \(vmURL.hiddenPasswordURL) not found for status")
		}
	}

	private func gdc(client: CakedServiceClient) async {
		let asyncStream: AsyncThrowingStreamCurrentStatus = AsyncThrowingStream.makeStream(of: [Caked_CurrentStatus].self)
		
		let stream = client.grandCentralDispatcher(.init(), callOptions: .init(timeLimit: .none)) { reply in
			_ = asyncStream.continuation.yield(reply.status.statuses)
			// Consider calling asyncStream.continuation.finish() when the stream should end
		}

		self.currentStatus = asyncStream
		self.gcd = stream

		defer {
			if let serviceURL = self.serviceURL {
				self.logger.debug("GCD stopped: \(serviceURL.hiddenPasswordURL)")
			} else {
				self.logger.debug("GCD stopped: \(self.connectionMode)")
			}

			stream.cancel(promise: nil)
			self.gcd = nil
		}

		do {
			_ = try await stream.subchannel.get()

			for try await statuses in asyncStream.stream {
				for status in statuses {
					let vmURL = self.vmURL(status.name)

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
		} catch is CancellationError {
			// Silent
		} catch {
			self.logger.error("Error in gdc: \(error)")
		}
	}

}

