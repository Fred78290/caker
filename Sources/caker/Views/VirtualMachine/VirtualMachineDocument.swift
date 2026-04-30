//
//  VirtualMachineDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import SwiftUI
import UniformTypeIdentifiers
import CakeAgentLib
import CakedLib
import Dynamic
import FileMonitor
import FileMonitorShared
import Foundation
import GRPC
import GRPCLib
import NIO
import RoyalVNCKit
import SwiftTerm

extension CakeAgentLib.Status {
	init(_ from: String) {
		let from = from.lowercased()

		if from == "running" {
			self = .running
		} else if from == "stopped" {
			self = .stopped
		} else {
			self = .unknown
		}
	}
}

extension VNCConnection.Status: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
		case .connected:
			return String(localized: "connected")
		case .connecting:
			return String(localized: "connecting")
		case .disconnected:
			return String(localized: "disconnected")
		case .disconnecting:
			return String(localized: "disconnecting")
		}
	}
}

extension UTType {
	static var virtualMachine: UTType {
		UTType(importedAs: "com.aldunelabs.caker.\(VMLocation.scheme)")
	}

	static var iso9660: UTType {
		UTType(filenameExtension: "iso")!
	}

	static var cdr: UTType {
		UTType(filenameExtension: "cdr")!
	}

	static var ipsw: UTType {
		UTType(filenameExtension: "ipsw")!
	}

	static var sshPublicKey: UTType {
		UTType(filenameExtension: "pub")!
	}

	static var unixSocketAddress: UTType {
		UTType(importedAs: "public.socket-address")
	}
}

// MARK: - VirtualMachineDocument
final class VirtualMachineDocument: @unchecked Sendable, ObservableObject, Equatable, Identifiable {
	typealias ShellHandlerResponse = (Cakeagent_CakeAgent.ExecuteResponse) -> Void
	
	static func == (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		lhs.url == rhs.url && rhs.connectionManager == lhs.connectionManager
	}
	
	enum AgentStatus: Int, Sendable {
		case none = 0
		case installed = 1
		case installing = 2
	}
	
	enum VncStatus: Int {
		case disconnected
		case connecting
		case connected
		case disconnecting
		case ready
		
		init(vncStatus: VNCConnection.Status) {
			switch vncStatus {
			case .disconnected:
				self = .disconnected
			case .connecting:
				self = .connecting
			case .connected:
				self = .connected
			case .disconnecting:
				self = .disconnecting
			}
		}
	}
	
	enum Status: Int, CustomStringConvertible {
		var isStopped: Bool {
			switch self {
			case .running, .starting, .pausing, .resuming, .stopping, .saving, .restoring:
				return false
			default:
				return true
			}
		}
		
		var isRunning: Bool {
			switch self {
			case .running, .starting, .pausing, .resuming, .stopping, .saving, .restoring:
				return true
			default:
				return false
			}
		}
		
		var description: String {
			switch self {
			case .running:
				return "running"
			case .stopped:
				return "stopped"
			case .starting:
				return "starting"
			case .pausing:
				return "pausing"
			case .resuming:
				return "resuming"
			case .stopping:
				return "stopping"
			case .saving:
				return "saving"
			case .restoring:
				return "restoring"
			case .none:
				return "none"
			case .paused:
				return "paused"
			case .error:
				return "error"
			}
		}
		
		case none = -1
		case stopped = 0
		case running = 1
		case paused = 2
		case error = 3
		case starting = 4
		case pausing = 5
		case resuming = 6
		case stopping = 7
		case saving = 8
		case restoring = 9
		
		init(_ from: CakeAgentLib.Status) {
			switch from {
				
			case .running:
				self = .running
			case .stopped:
				self = .stopped
			case .unknown:
				self = .error
			}
		}

		init(_ from: Caked_VirtualMachineStatus) {
			switch from {
			case .stopped, .new:
				self = .stopped
			case .running, .agentReady:
				self = .running
			case .paused:
				self = .paused
			case .deleted:
				self = .stopped
			case .error:
				self = .error
			case .UNRECOGNIZED(_):
				self = .none
			}
		}
	}
	
	private var monitor: FileMonitor?
	private var inited = false
	private let logger = Logger("VirtualMachineDocument")
	private var agentMonitoring: Task<Void, Never>?
	private var inView: Bool = false

	let id = UUID().uuidString
	
	var connectionManager = ConnectionManager.appConnectionManager
	var interactiveShell: InteractiveShell? = nil
	weak var vncView: NSVNCView? = nil
	var virtualMachine: VirtualMachine!
	var location: VMLocation!
	var url: URL!
	var name: String = String.empty
	var description: String {
		self.name
	}
	
	var isLaunchVMExternally: Bool {
		guard self.url.isFileURL else {
			return true
		}

		guard self.connectionManager.connectionMode == .app else {
			return true
		}
		
		guard let launchVMExternally = self.launchVMExternally else {
			return AppState.shared.launchVMExternally
		}
		
		return launchVMExternally
	}
	
	@Published var virtualMachineConfig: VirtualMachineConfig = .init()
	@Published var externalRunning: Bool = false
	@Published var canStart: Bool = false
	@Published var canStop: Bool = false
	@Published var canPause: Bool = false
	@Published var canResume: Bool = false
	@Published var canRequestStop: Bool = false
	@Published var suspendable: Bool = false
	@Published var vncURL: [URL]? = nil
	@Published var agent = AgentStatus.none
	@Published var agentReady: Bool = false
	@Published var connection: VNCConnection! = nil
	@Published var vncStatus: VncStatus = .disconnected
	@Published var documentSize: ViewSize = .zero
	@Published var launchVMExternally: Bool? = nil
	@Published var cpuInfos = CpuInfos()
	@Published var memoryInfos = MemoryInfo()
	@Published var agentCondition: (title: LocalizedStringKey, needUpdate: Bool, disabled: Bool) = ("Install agent", false, true)
	@Published var ipaddresses: [String] = []
	@Published var screenshot: Data!
	@Published var status: Status = .none {
		didSet {
			guard AppState.sharedLoaded else {
				return
			}

			if AppState.shared.currentDocument == self {
				AppState.shared.updateState()
			}
		}
	}

	@Published var recoveryMode: Bool = false {
		didSet {
			if let virtualMachine = self.virtualMachine {
				virtualMachine.recoveryMode = self.recoveryMode
			}
		}
	}

	var lastScreenshot: NSImage? {
		guard let screenshot else {
			return nil
		}

		return NSImage(data: screenshot)
	}
	
	var osImage: some View {
		var name = "linux"
		
		if self.virtualMachineConfig.os == .darwin {
			name = "mac"
		} else if let osName = self.virtualMachineConfig.osName {
			let osNames = [
				"almalinux",
				"alpine",
				"arch-linux",
				"backtrack",
				"centos",
				"debian",
				"elementary-os",
				"fedora",
				"gentoo",
				"knoppix",
				"kubuntu",
				"linux",
				"lubuntu",
				"mac",
				"mandriva",
				"mint",
				"openwrt",
				"pop-os",
				"red-hat",
				"slackware",
				"suse",
				"syllable",
				"ubuntu",
				"webos",
				"xubuntu",
			]
			
			for value in osNames {
				if osName.lowercased().contains(value) {
					name = value
					break
				}
			}
		}
		
		return Image(name).resizable().aspectRatio(contentMode: .fit)
	}
	
	deinit {
		self.logger.debug("Release document: \(self.url!)")
		self.stopAgentMonitoring()
		
		if let monitor = self.monitor {
			monitor.stop()
		}
	}
	
	private init() {
		self.virtualMachine = nil
		self.virtualMachineConfig = VirtualMachineConfig()
	}
	
	private init(location: VMLocation) throws {
		let config = try VirtualMachineConfig(name: location.name, config: location.config())
		let monitor = try FileMonitor(directory: location.rootURL, delegate: self)

		self.name = location.name
		self.url = location.rootURL
		self.location = location
		self.virtualMachineConfig = config
		self.screenshot = nil
		self.agent = config.agent ? config.firstLaunch ? AgentStatus.installing : AgentStatus.installed : AgentStatus.none
		self.externalRunning = location.pidFile.isPIDRunning(Home.cakedCommandName)
		self.monitor = monitor
		self.documentSize = ViewSize(config.display.cgSize)

		switch location.status {
		case .running:
			self.status = .running
		case .stopped:
			self.status = .stopped
		case .paused:
			self.status = .paused
		}
		
		try monitor.start()
	}

	private convenience init(vmURL: URL, infos: VMInformations, config: any VirtualMachineConfiguration, connectionManager: ConnectionManager) throws {
		let status = Status(infos.status)
		
		try self.init(vmURL: vmURL, status: status, vncURL: infos.vncURL, config: config, connectionManager: connectionManager)
	}

	private init(vmURL: URL, status: Status, vncURL: [String]?, config: any VirtualMachineConfiguration, connectionManager: ConnectionManager) throws {
		let name = vmURL.vmName

		self.name = name
		self.url = vmURL
		self.virtualMachineConfig = VirtualMachineConfig(name: name, config: config)
		self.agent = config.agent ? config.firstLaunch ? AgentStatus.installing : AgentStatus.installed : AgentStatus.none
		self.connectionManager = connectionManager

		self.setDocumentSize(.init(self.virtualMachineConfig.display.cgSize))
		self.updateCurrentStatus(status, suspendable: config.suspendable, vncURL: vncURL?.compactMap { URL(string: $0) })
	}
	
	static func anyVirtualMachineDocument() throws -> VirtualMachineDocument {
		guard let location = try StorageLocation(runMode: .app).list().values.first else {
			throw ServiceError(String(localized: "No virtual machines"))
		}

		return try VirtualMachineDocument(location: location)
	}

	static func openVirtualMachineDocument(_ vmURL: URL, connectionManager: ConnectionManager) throws -> VirtualMachineDocument {
		if vmURL.isFileURL {
			return try VirtualMachineDocument(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: .app))
		} else if connectionManager.connectionMode == .app {
			return try VirtualMachineDocument(location: StorageLocation(runMode: .app).find(vmURL.vmName))
		} else {
			//let connectionManager = ConnectionManager.connectionManager(vmURL, connectionMode: connectionMode)
			let infos = try connectionManager.virtualMachineInfos(vmURL: vmURL)
			
			return try VirtualMachineDocument(vmURL: vmURL,
											  infos: infos.infos,
											  config: infos.config,
											  connectionManager: connectionManager)
		}
	}
	
	static func loadVirtualMachineDocuments(connectionManager: ConnectionManager) throws -> [URL: VirtualMachineDocument] {
		let client = connectionManager.serviceClient
		var vms: [URL: VirtualMachineDocument] = [:]

		let result = try ListHandler.list(client: client, vmonly: true, includeConfig: connectionManager.connectionMode != .app, runMode: connectionManager.connectionMode.runMode)

		if result.success {
			if client != nil {
				vms = try result.infos.reduce(into: vms) { (partialResult, info) in
					guard let vmURL = URL(string: info.fqn.first!), let config = info.config else {
						throw ServiceError(String(localized: "Internal error"))
					}

					if let vm = try? VirtualMachineDocument(vmURL: connectionManager.vmURL(vmURL.vmName), status: .init(CakeAgentLib.Status(info.state)), vncURL: info.vncURL, config: config, connectionManager: connectionManager) {
						partialResult[vm.url] = vm
					}
				}
			} else {
				let storage = StorageLocation(runMode: connectionManager.connectionMode.runMode)

				vms = result.infos.reduce(into: vms) { (partialResult, info) in
					if let vmURL = URL(string: info.fqn.first!), let location = try? storage.find(vmURL.vmName), let vm = try? VirtualMachineDocument(location: location) {
						partialResult[vm.url] = vm
					}
				}
			}
		}

		return vms
	}
}

// MARK: - Core
extension VirtualMachineDocument {
	@MainActor func setScreenshot(_ data: Data) {
		self.screenshot = data

		NotificationCenter.default.post(name: VirtualMachineDocument.NewScreenshot, object: data, userInfo: ["document": self.url!])
	}

	func disconnect() {
#if DEBUG
		self.logger.debug("Disconnecting \(self.name)")
#endif

		self.vncURL = nil
		self.inView = false
		self.vncStatus = .disconnected
		self.stopAgentMonitoring()
		if self.externalRunning == false {
			self.status = .stopped
		}
		
		if let connection = self.connection {
			self.connection = nil
			connection.disconnect()
		}

		AppState.shared.closeVirtualMachineDocument(self)
	}

	func enterView() {
		self.interactiveShell = InteractiveShell(self.url, connectionManager: connectionManager)
		self.inView = true

		DispatchQueue.main.async {
			AppState.shared.openVirtualMachineDocument(self)
			self.tryVNCConnect()
		}
	}

	func leaveView() {
		self.interactiveShell?.cancelShell()

		self.inView = false
		self.interactiveShell = nil
	}

	func close() {
#if DEBUG
		self.logger.debug("Closing \(self.name)")
#endif
		
		self.virtualMachine = nil
		self.inited = false
		self.inView = false
		self.vncView = nil
		self.vncURL = nil
		self.vncStatus = .disconnected
		
		if self.externalRunning == false {
			self.status = .stopped
		}
		
		if let connection = self.connection {
			self.connection = nil
			connection.disconnect()
		}

		AppState.shared.closeVirtualMachineDocument(self)
	}
	
	func updateCurrentStatus(_ newStatus: Status, suspendable: Bool, vncURL: [URL]? = nil) {
		self.status = newStatus
		self.canStart = newStatus == .stopped || newStatus == .paused
		self.canStop = newStatus == .running
		self.canPause = newStatus == .running
		self.canResume = newStatus == .paused
		self.canRequestStop = newStatus == .running
		self.vncURL = vncURL
		self.suspendable = suspendable
	}

	@MainActor
	func setStateAsStopped(_ status: Status = .stopped, _line: UInt = #line, _file: String = #file) {
#if DEBUG
		self.logger.debug("setStateAsStopped to \(status) at \(_file):\(_line)")
#endif
		
		// Stop agent monitoring when VM is stopped
		self.stopAgentMonitoring()
		self.interactiveShell?.cancelShell()

		self.updateCurrentStatus(status, suspendable: false, vncURL: nil)

		self.interactiveShell = nil
		self.vncStatus = .disconnected
		self.externalRunning = false
		self.agentCondition = ("Install agent", false, true)
		self.agentReady = false

		if let connection = self.connection {
			self.connection = nil
			connection.disconnect()
		}
	}

	@MainActor
	func setStateAsRunning(suspendable: Bool, vncURL: [URL]?, _line: UInt = #line, _file: String = #file) {
#if DEBUG
		self.logger.debug("setStateAsRunning, suspendable: \(suspendable) at \(_file):\(_line)")
#endif

		self.updateCurrentStatus(.running, suspendable: suspendable, vncURL: vncURL)

		self.agentReady = false
		self.agentCondition = ("Install agent", false, self.agent != .none)

		// Start agent monitoring when VM is running
		self.startAgentMonitoring()
		AppState.shared.openVirtualMachineDocument(self)
	}
	
	func setOtherState(suspendable: Bool, status: Status, vncURL: [URL]? = nil, _line: UInt = #line, _file: String = #file) {
#if DEBUG
		self.logger.debug("setOtherState to \(status) at \(_file):\(_line)")
#endif
		
		self.updateCurrentStatus(status, suspendable: suspendable, vncURL: vncURL)
	}

	func setState(_ status: Caked_VirtualMachineStatus) {
		let newStatus = Status(status)

		func agentIsReady() {
			self.agent = .installed
			self.agentReady = true

			if self.interactiveShell == nil && self.inView {
				self.interactiveShell = InteractiveShell(self.url, connectionManager: self.connectionManager)
			}

			if let infos = try? self.connectionManager.virtualMachineInfos(vmURL: self.url) {
				self.ipaddresses = infos.infos.ipaddresses
				self.virtualMachineConfig = .init(name: self.name, config: infos.config)

				if let vncURL = infos.infos.vncURL {
					self.vncURL = vncURL.compactMap {
						URL(string: $0)
					}
				}
			}
		}

		guard self.status != newStatus else {
			if status == .agentReady {
				agentIsReady()
			}

			return
		}

		if newStatus != .running {
			self.interactiveShell?.cancelShell()
		}

		if status == .running {
			self.updateCurrentStatus(newStatus, suspendable: self.suspendable, vncURL: self.vncURL)

			AppState.shared.openVirtualMachineDocument(self)

			if let vncInfos = try? self.connectionManager.vncInfos(vmURL: self.url) {
				self.vncURL = vncInfos.urls.compactMap {
					URL(string: $0)
				}

				if let screenSize = vncInfos.screenSize {
					self.setDocumentSize(.init(width: CGFloat(screenSize.width), height: CGFloat(screenSize.height)))
				}
			}

			if self.inView {
				self.tryVNCConnect()
			}
		} else {
			self.updateCurrentStatus(newStatus, suspendable: false, vncURL: nil)

			self.interactiveShell?.cancelShell()

			self.interactiveShell = nil
			self.vncStatus = .disconnected
			self.agentCondition = ("Install agent", false, true)
			self.agentReady = false

			if let connection = self.connection {
				self.connection = nil
				connection.disconnect()
			}
		}
	}

	func setDocumentSize(_ size: ViewSize, _line: UInt = #line, _file: String = #file) {
		if self.documentSize != size {
#if DEBUG
			self.logger.debug("Setting document \(self.name) size to \(size.description) at \(_file):\(_line)")
#endif
			
			self.documentSize = size
		}
	}
	
	func setScreenSize(_ size: ViewSize, _line: UInt = #line, _file: String = #file) {
		#if DEBUG
			self.logger.debug("Setting screen size to \(size.description) at \(_file):\(_line)")
		#endif

		if size.width == 0 && size.height == 0 {
			return
		}

		self.setDocumentSize(size)
		self.setVncScreenSize(size)
	}
}

// MARK: - Embeded VirtualMachine
extension VirtualMachineDocument {
	private func createVirtualMachine() throws {
		let config = try! location.config()
		let virtualMachine = try VirtualMachine(location: location, config: config, display: .ui, screenSize: config.display.cgSize, recoveryMode: self.recoveryMode, runMode: .app)
		
		self.virtualMachine = virtualMachine
		self.vncURL = nil
		self.didChangedState(virtualMachine)
		
		virtualMachine.delegate = self
	}

	func loadVirtualMachine(_ url: URL) -> URL? {
		self.externalRunning = true

		if self.status == .running {
			self.setDocumentSize(self.getVncScreenSize())
		} else {
			self.setDocumentSize(.init(self.virtualMachineConfig.display.cgSize))
		}

		retrieveVNCURL()

		return url
	}

	private func loadVirtualMachine(_ location: VMLocation) -> URL? {
#if DEBUG
		self.logger.debug("Load VM from: \(location.rootURL)")
#endif
		
		do {
			self.virtualMachineConfig = try VirtualMachineConfig(name: location.name, config: location.config())
			self.location = location
			self.agent = self.virtualMachineConfig.agent ? (self.virtualMachineConfig.firstLaunch ? .installing : .installed) : .none
			self.name = location.name
			self.externalRunning = location.pidFile.isPIDRunning(Home.cakedCommandName)
			
			if self.isLaunchVMExternally && self.externalRunning {
				self.setDocumentSize(self.getVncScreenSize())
			} else {
				self.setDocumentSize(.init(self.virtualMachineConfig.display.cgSize))
			}
			
			retrieveVNCURL()
			
			if monitor == nil {
				let monitor = try FileMonitor(directory: location.rootURL, delegate: self)
				try monitor.start()
				
				self.monitor = monitor
			}

			// Start agent monitoring if VM is running
			self.startAgentMonitoring()

			return location.rootURL
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
		
		return nil
	}
	
	func loadVirtualMachine() -> URL? {
		guard let virtualMachine = self.virtualMachine else {
			if let location = self.location {
				return self.loadVirtualMachine(location)
			}

			if self.url.isFileURL {
				if let location = try? VMLocation.newVMLocation(vmURL: self.url, runMode: AppState.shared.connectionMode.runMode) {
					return self.loadVirtualMachine(location)
				}
			} else {
				return self.loadVirtualMachine(self.url)
			}
			
			DispatchQueue.main.async {
				alertError(ServiceError(String(localized: "Unable to find virtual machine: \(self.name)")))
			}
			
			return nil
		}
		
		return virtualMachine.location.rootURL
	}
}

// MARK: - UI Actions
extension VirtualMachineDocument {
	func startRemotely(location: URL) async throws {
		let vncPassword = self.virtualMachineConfig.vncPassword
		let vncPort = try Utilities.findFreePort()
		let screenSize = GRPCLib.ViewSize(width: Int(self.documentSize.width), height: Int(self.documentSize.height))
		
		let result = try self.connectionManager.startVirtualMachine(vmURL: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: 120, startMode: .service, recoveryMode: self.recoveryMode)
		let vncInfos = try self.connectionManager.vncInfos(vmURL: location)
#if DEBUG
		self.logger.debug("VM started on \(result.ip)")
		self.logger.debug("Found VNC URL: \(vncInfos.urls)")
#endif
		
		await self.setStateAsRunning(suspendable: suspendable, vncURL: vncInfos.urls.compactMap { URL(string: $0) })
	}
	
	func startLocally(location: VMLocation) async throws {
		let config = try location.config()
		let vncPassword = config.vncPassword ?? UUID().uuidString
		let vncPort = try Utilities.findFreePort()
		let vncURL = URL(string: "vnc://:\(vncPassword)@localhost:\(vncPort)")!
		let promise = Utilities.group.next().makePromise(of: String.self)
		let suspendable = config.suspendable
		
		promise.futureResult.whenSuccess { _ in
#if DEBUG
			self.logger.debug("VM \(self.name) terminated")
#endif
			
			DispatchQueue.main.async {
				self.setStateAsStopped()
			}
		}
		
		promise.futureResult.whenFailure { result in
			self.logger.error("VM \(self.name) failed to start: \(result)")
			
			DispatchQueue.main.async {
				self.setStateAsStopped()
			}
		}
		
		await self.tryVNCConnect(vncURL: vncURL)
		
		let screenSize = GRPCLib.ViewSize(width: Int(self.documentSize.width), height: Int(self.documentSize.height))
		let runningIP = try StartHandler.internalStartVM(location: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: 120, startMode: .service, gcd: false, recoveryMode: self.recoveryMode, runMode: .user, promise: promise)
		
#if DEBUG
		self.logger.debug("VM started on \(runningIP)")
		self.logger.debug("Found VNC URL: \(vncURL)")
#endif
		
		await self.setStateAsRunning(suspendable: suspendable, vncURL: [vncURL])
	}
	
	func startFromUI() {
		guard self.status == .stopped else {
			return
		}
		
		if self.isLaunchVMExternally {
			self.setOtherState(suspendable: self.virtualMachineConfig.suspendable, status: .starting, vncURL: vncURL)
			self.externalRunning = true
			
			Task {
				do {
					if let location {
						try await self.startLocally(location: location)
					} else if let url {
						try await self.startRemotely(location: url)
					} else {
						throw ServiceError(String(localized: "Internal error: Virtual machine is not launched from a local or remote location."))
					}
				} catch {
					await self.setStateAsStopped()
					await alertError(error)
				}
			}
		} else {
			self.externalRunning = false
			
			if self.virtualMachine == nil {
				do {
					try createVirtualMachine()
				} catch {
					MainActor.assumeIsolated {
						alertError(error)
					}
					return
				}
			}
			
			if let virtualMachine = self.virtualMachine {
				self.setOtherState(suspendable: virtualMachineConfig.suspendable, status: .starting)
				
				virtualMachine.startFromUI()
			}
		}
	}
	
	func restartFromUI() {
		guard self.status == .running else {
			return
		}
		
		if self.externalRunning {
			Task {
				do {
					try self.connectionManager.restartVirtualMachine(vmURL: self.url)
				} catch {
					await alertError(error)
				}
			}
		} else if let virtualMachine = self.virtualMachine {
			virtualMachine.restartFromUI()
		}
	}
	
	func stopFromUI(force: Bool) {
		guard self.status == .running else {
			return
		}
		
		if self.externalRunning {
			Task {
				do {
					try self.connectionManager.stopVirtualMachine(vmURL: self.url)
					await self.setStateAsStopped()
				} catch {
					await alertError(error)
				}
			}
		} else if let virtualMachine = self.virtualMachine {
			if force {
				virtualMachine.stopFromUI()
			} else {
				virtualMachine.requestStopFromUI()
			}
		}
	}
	
	func suspendFromUI() {
		guard self.status == .running else {
			return
		}
		
		if self.externalRunning {
			Task {
				do {
					let result = try self.connectionManager.suspendVirtualMachine(vmURL: self.url)
					
					if result.success {
						await self.setStateAsStopped(.paused)
					} else {
						let reason = result.reason
						
						DispatchQueue.main.async {
							alertError(String(localized: "Failed to suspend VM"), reason)
						}
					}
					
				} catch {
					await alertError(error)
				}
			}
		} else if let virtualMachine = self.virtualMachine {
			virtualMachine.suspendFromUI()
		}
	}
	
	func deleteVirtualMachine() throws -> DeleteReply {
		try self.connectionManager.deleteVirtualMachine(vmURL: self.url)
	}
	
	func duplicateVirtualMachine(to: String) throws -> DuplicatedReply {
		try self.connectionManager.duplicateVirtualMachine(vmURL: self.url, to: to, resetMacAddress: true)
	}
	
	func saveConfiguration() {
		let connectionMode = self.connectionManager.connectionMode

		do {
			if connectionMode != .app {
				let reply = ConfigureHandler.configure(name: self.name, options: self.virtualMachineConfig.configureOptions(), runMode: connectionMode.runMode)
				
				if reply.configured == false {
					throw ServiceError(String(localized: "Failed to save VM configuration: \(reply.reason)"))
				}
				
			} else if let virtualMachine = self.virtualMachine {
				try self.virtualMachineConfig.saveLocally(virtualMachine.config)
			} else if let location = self.location {
				try self.virtualMachineConfig.saveLocally(location)
			} else {
				throw ServiceError(String(localized: "Failed to save VM configuration, Unexpected error"))
			}
			
			self.virtualMachineConfig.clearChangedFields()
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
}

// MARK: - VirtualMachineDelegate
extension VirtualMachineDocument: VirtualMachineDelegate {
	func didChangedState(_ vm: VirtualMachine) {
		let virtualMachine = vm.virtualMachine

		#if DEBUG
			self.logger.debug("didChangedState: \(virtualMachine.state)")
		#endif

		guard let status = Status(rawValue: virtualMachine.state.rawValue) else {
			self.status = .none
			return
		}

		self.virtualMachineConfig.agent = vm.config.agent
		self.virtualMachineConfig.firstLaunch = vm.config.firstLaunch

		self.canStart = virtualMachine.canStart
		self.canStop = virtualMachine.canStop
		self.canPause = virtualMachine.canPause
		self.canResume = virtualMachine.canResume
		self.canRequestStop = virtualMachine.canRequestStop
		self.suspendable = suspendable
		self.agent = vm.config.agent ? vm.config.firstLaunch ? .installing : .installed : .none
		self.status = status
	}

	func didScreenshot(_ vm: CakedLib.VirtualMachine, screenshot: NSImage) {
		try? screenshot.pngData?.write(to: self.location.screenshotURL)
	}
}

// MARK: - FileDidChangeDelegate
extension VirtualMachineDocument: FileDidChangeDelegate {
	func fileDidChanged(event: FileChangeEvent) {
		guard let location = self.location else {
			return
		}

		let check: (URL) -> Void = { file in
			if file.lastPathComponent == location.pidFile.lastPathComponent {
				DispatchQueue.main.async {
					let running = location.pidFile.isPIDRunning()

					if running.running == false {
						self.externalRunning = false
						self.setStateAsStopped()
					} else if running.processName.contains(Home.cakedCommandName) {
						self.externalRunning = true
						self.retrieveVNCURL()
					} else {
						self.externalRunning = false
						self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: nil)
					}
				}
			} else if file.lastPathComponent == location.screenshotURL.lastPathComponent {
				if let screenshot = try? Data(contentsOf: location.screenshotURL) {
					DispatchQueue.main.async {
						self.setScreenshot(screenshot)
					}
				}
			}
		}

		switch event {
		case .added(let file):
			check(file)
		case .deleted(let file):
			check(file)
		case .changed(let file):
			check(file)
		}
	}
}

// MARK: - VNC handling
extension VirtualMachineDocument {
	func setVncScreenSize(_ screenSize: ViewSize) {
		if self.externalRunning && self.status == .running {
			#if DEBUG
				self.logger.debug("setVncScreenSize: \(screenSize.description)")
			#endif

			Task {
				await self.connectionManager.setVncScreenSize(vmURL: self.url, screenSize: screenSize)
			}
		}
	}

	func getVncScreenSize() -> ViewSize {
		let screenSize = ViewSize(width: CGFloat(self.virtualMachineConfig.display.width), height: CGFloat(self.virtualMachineConfig.display.height))
		return self.connectionManager.getVncScreenSize(vmURL: self.url, screenSize)
	}

	func retrieveVNCURL() {
		guard self.externalRunning && self.status == .running else {
			return
		}

		MainActor.assumeIsolated {
			if let vncInfos = try? self.connectionManager.vncInfos(vmURL: self.url) {
				self.logger.info("Found VNC URL: \(vncInfos.urls)")

				self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: vncInfos.urls.compactMap {
					URL(string: $0)
				})

				if let screenSize = vncInfos.screenSize {
					self.setDocumentSize(.init(width: CGFloat(screenSize.width), height: CGFloat(screenSize.height)))
				}

				if self.inView {
					self.tryVNCConnect()
				}
			} else {
				self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: nil)
			}
		}
	}

	@MainActor
	private func tryVNCConnect(vncURL: URL) {
		self.vncURL = [vncURL]
		tryVNCConnect()
	}

	func tryVNCConnect() {
		guard let vncURL = self.vncURL, vncURL.isEmpty == false else {
			return
		}

		if connection != nil {
			return
		}

		func establishConnection(_ vncURL: URL) {
			// Create settings
			let vncPort = vncURL.port ?? 5900
			let vncHost = vncURL.host()!
			#if DEBUG
				let isDebugLoggingEnabled = AppState.shared.debugVNCMessageEnabled
			#else
				let isDebugLoggingEnabled = false
			#endif

			let settings = RoyalVNCKit.VNCConnection.Settings(
				isDebugLoggingEnabled: isDebugLoggingEnabled,
				hostname: vncHost,
				port: UInt16(vncPort),
				isShared: true,
				isScalingEnabled: true,
				useDisplayLink: true,
				inputMode: .forwardAllKeyboardShortcutsAndHotKeys,
				isClipboardRedirectionEnabled: AppState.shared.isClipboardRedirectionEnabled,
				colorDepth: .depth24Bit,
				frameEncodings: .default)
			let connection = RoyalVNCKit.VNCConnection(settings: settings, logger: VNCConnectionLogger(isDebugLoggingEnabled))

			self.connection = connection
			self.vncStatus = .connecting

			connection.delegate = self

			Task {
				if Utilities.waitPortReady(host: vncHost, port: vncPort) {
					connection.connect()

					#if DEBUG
						self.logger.debug("Connected to: \(vncURL)...")
					#endif
				}
			}
		}

		if self.connectionManager.connectionMode == .remote {
			let vncURL = vncURL.first!
			
			if let client = self.connectionManager.serviceClient {
				_ = try? client.createVNCTunnel(eventLoopGroup: Utilities.group, vmName: self.name) { (channel, port) in
					var components = URLComponents()
					components.scheme = "vnc"
					components.host = "127.0.0.1"
					components.port = port

					if let password = vncURL.password {
						components.password = password
					}

					if let tunneledVNCURL = components.url {
						establishConnection(tunneledVNCURL)
					}
				}
			}
		} else if let vncURL = VNCServer.findHostMatching(urls: self.vncURL) {
			establishConnection(vncURL)
		}
	}
}

// MARK: - VNCConnectionDelegate
extension VirtualMachineDocument: VNCConnectionDelegate {
	func connection(_ connection: RoyalVNCKit.VNCConnection, stateDidChange connectionState: RoyalVNCKit.VNCConnection.ConnectionState) {
		#if DEBUG
			self.logger.debug("Connection state changed to \(connectionState.status.description)")
		#endif

		DispatchQueue.main.async {
			var newStatus = VncStatus(vncStatus: connectionState.status)

			if connectionState.status == .connected {
				self.connection = connection

				if connection.framebuffer != nil {
					newStatus = .ready
				}
			} else if connectionState.status == .disconnecting {
				if self.status == .starting || self.status == .running {
					newStatus = .connecting
				}
			} else if connectionState.status == .disconnected {
				if self.connection != nil {
					self.connection = nil

					if self.status == .starting || self.status == .running {
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
							self.tryVNCConnect()
						}
						newStatus = .connecting
					} else {
						self.vncView = nil
					}
				} else {
					self.vncView = nil
				}
			}

			self.vncStatus = newStatus

			if newStatus == .ready {
				self.setScreenSize(self.documentSize)
			}
		}
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, credentialFor authenticationType: VNCAuthenticationType, completion: @escaping ((any VNCCredential)?) -> Void) {
		#if DEBUG
			self.logger.debug("Connection need credential")
		#endif

		if let vncURL = VNCServer.findHostMatching(urls: self.vncURL) {
			if authenticationType.requiresPassword && authenticationType.requiresUsername {
				if let userName = vncURL.user, let password = vncURL.password {
					completion(VNCUsernamePasswordCredential(username: userName, password: password))

					return
				}
			} else if authenticationType.requiresPassword {
				if let password = vncURL.password {
					completion(VNCPasswordCredential(password: password))

					return
				}
			}
		}

		completion(nil)
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, didCreateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		if self.vncStatus != .ready {
			let size = ViewSize(framebuffer.cgSize)

			#if DEBUG
				self.logger.debug("Connection create framebuffer size: \(size.description)")
			#endif

			DispatchQueue.main.async {
				self.logger.debug("vnc ready")
				self.vncStatus = .ready
			}
		}
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, didResizeFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		#if DEBUG
			self.logger.debug("VNC framebuffer size changed: \(framebuffer.cgSize)")
		#endif

		if framebuffer.size.width != 8192 && framebuffer.size.height != 4320 {
			self.vncView?.connection(connection, didResizeFramebuffer: framebuffer)

			DispatchQueue.main.async {
				self.setDocumentSize(.init(framebuffer.cgSize))

				NotificationCenter.default.post(name: VirtualMachineDocument.VNCFramebufferSizeChanged, object: framebuffer.cgSize, userInfo: ["document": self.url!])
			}
		}
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
		vncView?.connection(connection, didUpdateFramebuffer: framebuffer, x: x, y: y, width: width, height: height)
	}

	func connection(_ connection: VNCConnection, didUpdateCursor cursor: VNCCursor) {
		vncView?.connection(connection, didUpdateCursor: cursor)
	}
}

// MARK: - Agent Monitoring
extension VirtualMachineDocument {
	func createCakeAgentHelper(connectionTimeout: Int64 = 1, retries: ConnectionBackoff.Retries = .upTo(1)) throws -> CakeAgentHelper {
		try CakeAgentHelper.createCakeAgentHelper(vmURL: self.url, connectionTimeout: connectionTimeout, retries: retries, runMode: .app)
	}
	
	func installAgent(updateAgent: Bool, _ done: @escaping (_ agent: AgentStatus) -> Void) {
		guard self.status == .running else {
			done(.none)
			return
		}

		@MainActor func finish(_ status: AgentStatus) {
			self.agent = status

			if updateAgent {
				self.agentCondition = (status != .installed ? "Update agent" : "Install agent", status != .installed, status != .none)
			} else {
				self.agentCondition = ("Install agent", status != .installed, status != .none)
				
				if status == .installed {
					self.startAgentMonitoring()
				}
			}

			done(status)
		}

		self.agent = .installing

		Task {
			var agent: AgentStatus = .installing

			do {
				if let virtualMachine = self.virtualMachine {
					if try await virtualMachine.installAgent(updateAgent: updateAgent, timeout: 2, runMode: .app) == false {
						throw ServiceError(String(localized: "Failed to install agent."))
					}
				} else {
					if try self.connectionManager.installAgent(self.url) == false {
						throw ServiceError(String(localized: "Failed to install agent."))
					}
				}

				agent = .installed
			} catch {
				await alertError(error)
				
				agent = .none
			}

			await finish(agent)
		}
	}

	@MainActor
	private func agentMonitoringSuccess(infos: InfoReply) {
		#if DEBUG
			self.logger.debug("Agent monitoring: VM \(self.name) agent is responding")
		#endif

		self.agentReady = true
		self.ipaddresses = infos.ipaddresses
		self.cpuInfos.update(infos.cpuInfo)
		self.memoryInfos.update(infos.memory)

		if let firstIP = infos.ipaddresses.first {
			self.logger.debug("VM \(self.name) is ready with IP: \(firstIP)")
		}

		if infos.agentVersion.contains(CAKEAGENT_SNAPSHOT) == false {
			#if DEBUG
				self.logger.debug("Agent monitoring: VM \(self.name) agent need to be updated")
			#endif
			self.agentCondition = ("Update agent", true, false)
		}

		if self.interactiveShell == nil && self.inView {
			self.interactiveShell = InteractiveShell(self.url, connectionManager: self.connectionManager)
		}
	}

	private func agentMonitoringFailure(error: Error) -> Bool {
		if let grpcError = error as? GRPCStatus {
			switch grpcError.code {
			case .unavailable, .cancelled:
				// These could be temporary - continue monitoring
				break
			case .deadlineExceeded:
				// Timeout - VM might be under heavy load
				self.logger.info("Agent monitoring: VM \(self.name) agent timeout - VM might be busy")
			case .unimplemented:
				// unimplemented - Agent is too old, need update
				self.logger.info("Agent monitoring: VM \(self.name) agent is too old, need update")
			default:
				// Other errors might indicate serious issues
				self.logger.error("Agent monitoring: VM \(self.name) agent error: \(grpcError)")
			}
		} else {
			#if DEBUG
				// Agent is not responding - could indicate VM issues
				self.logger.debug("Agent monitoring: VM \(self.name) agent not responding: \(error)")  // Check if it's a permanent failure (connection refused, etc.)
			#endif
			
			return false
		}

		return true
	}

	private func performAgentMonitoring() async -> Bool {
		do {
			let helper = try self.createCakeAgentHelper()

			defer {
				try? helper.closeSync()
			}

			await agentMonitoringSuccess(infos: try helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(10)))))
		} catch {
			return agentMonitoringFailure(error: error)
		}

		return false
	}

	func startAgentMonitoring() {
		guard self.location != nil else {
			return
		}

		guard agentMonitoring == nil && self.status == .running && self.agent != .none else {
			return
		}
		
		self.agentMonitoring = Task {
			var isWaitingForAgent = true

			await withTaskCancellationHandler(operation: {
				while Task.isCancelled == false && isWaitingForAgent {
					isWaitingForAgent = await self.performAgentMonitoring()

					if isWaitingForAgent {
						try? await Task.sleep(nanoseconds: 1_000_000_000)
					}
				}
			}, onCancel: {
				self.agentMonitoring = nil
			})
		}
	}

	func stopAgentMonitoring() {
		self.agentMonitoring?.cancel()
		self.agentMonitoring = nil
	}
}

// MARK: - Notification messagge
extension VirtualMachineDocument {
	static let NewVirtualMachine = NSNotification.Name("NewVirtualMachine")
	static let OpenVirtualMachine = NSNotification.Name("OpenVirtualMachine")
	static let StartVirtualMachine = NSNotification.Name("StartVirtualMachine")
	static let DeleteVirtualMachine = NSNotification.Name("DeleteVirtualMachine")
	static let CreatedVirtualMachine = NSNotification.Name("CreatedVirtualMachine")
	static let FailCreateVirtualMachine = NSNotification.Name("FailCreateVirtualMachine")
	static let ProgressCreateVirtualMachine = NSNotification.Name("ProgressCreateVirtualMachine")
	static let ProgressMessageCreateVirtualMachine = NSNotification.Name("ProgressMessageCreateVirtualMachine")
	static let NewScreenshot = NSNotification.Name("NewScreenshot")
	static let VNCFramebufferSizeChanged = NSNotification.Name("VNCFramebufferSizeChanged")

	func issuedNotificationFromDocument<T>(_ notification: Notification) -> T? {
		guard let document = notification.userInfo?["document"] as? URL, document == self.url else {
			return nil
		}

		return notification.object as? T
	}
}

// MARK: - Usage update
extension VirtualMachineDocument {
	/// Update the document's usage information with new VMUsage data asynchronously on the main actor
	@MainActor
	public func setUsage(_ usage: Caked_CurrentUsageReply) async {
		self.agent = .installed
		self.agentReady = true
		if usage.hasCpuInfos {
			self.cpuInfos.update(usage.cpuInfos)
		}

		if usage.hasMemory {
			self.memoryInfos.update(usage.memory)
		}
	}
}

// MARK: - NSVNCViewDelegate
extension VirtualMachineDocument: NSVNCViewDelegate {
	func viewDidEndLiveResize(_ view: CakedLib.NSVNCView) {
		self.setScreenSize(.init(view.bounds.size))
	}
}

// MARK: - Grand central
extension VirtualMachineDocument {
	func grandCentralDidStart() {
		
	}
	
	func grandCentralDidStop() {
		
	}
}
