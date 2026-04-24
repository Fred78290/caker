//
//  ConnectionManager.swift
//  Caker
//
//  Created by Frederic BOLTZ on 24/04/2026.
//
import Foundation
import CakedLib
import GRPCLib

struct ConnectionManager {
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
	let listenAddress: String?
	let password: String?
	let tls: Bool
	
	init(connectionMode: ConnectionMode = .app, listenAddress: String? = nil, password: String? = nil, tls: Bool = true) {
		self.connectionMode = connectionMode
		self.listenAddress = listenAddress
		self.password = password
		self.tls = tls
	}
	
	var serviceClient: CakedServiceClient? {
		if self.connectionMode == .app {
			return nil
		}
		
		if self.connectionMode != .remote {
			return ServiceHandler.serviceClient
		}
		
		return try? ServiceHandler.createCakedServiceClient(listenAddress: listenAddress, password: password, tls: tls, runMode: connectionMode.runMode)
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
		return try DuplicateHandler.duplicate(client: self.serviceClient, vmURL: vmURL, to: to, resetMacAddress: true, runMode: self.connectionMode.runMode)
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
