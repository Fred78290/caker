//
//  VirtualMachineDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
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
import SwiftUI
import UniformTypeIdentifiers

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

	#if arch(arm64)
		static var ipsw: UTType {
			UTType(filenameExtension: "ipsw")!
		}
	#endif

	static var sshPublicKey: UTType {
		UTType(filenameExtension: "pub")!
	}

	static var unixSocketAddress: UTType {
		UTType(importedAs: "public.socket-address")
	}
}

// MARK: - VirtualMachineDocument
@Observable final class VirtualMachineDocument: @unchecked Sendable, Equatable, Identifiable, Comparable {
	typealias ShellHandlerResponse = (Cakeagent_CakeAgent.ExecuteResponse) -> Void

	static func == (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		//lhs.url == rhs.url && rhs.connectionManager == lhs.connectionManager
		lhs.virtualMachineConfig.instanceID == rhs.virtualMachineConfig.instanceID
	}

	static func < (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		lhs.name < rhs.name
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
			case .running, .starting, .pausing, .resuming, .stopping, .saving, .restoring, .provisioning, .restarting:
				return false
			default:
				return true
			}
		}

		var isRunning: Bool {
			switch self {
			case .running, .starting, .pausing, .resuming, .stopping, .saving, .restoring, .provisioning, .restarting:
				return true
			default:
				return false
			}
		}

		var humanReadable: LocalizedStringKey {
			switch self {
			case .running:
				return "Running"
			case .stopped:
				return "Stopped"
			case .starting:
				return "Starting"
			case .pausing:
				return "Pausing"
			case .resuming:
				return "Resuming"
			case .stopping:
				return "Stopping"
			case .saving:
				return "Saving"
			case .restoring:
				return "Restoring"
			case .none:
				return "None"
			case .paused:
				return "Paused"
			case .error:
				return "Error"
			case .provisioning:
				return "Provisioning"
			case .deleted:
				return "Deleted"
			case .restarting:
				return "Restarting"
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
			case .provisioning:
				return "provisioning"
			case .deleted:
				return "deleted"
			case .restarting:
				return "restarting"
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
		case provisioning = 10
		case deleted = 11
		case restarting = 12

		init(_ from: VMInformations.Status) {
			switch from {
			case .running:
				self = .running
			case .stopped:
				self = .stopped
			case .provisioning:
				self = .provisioning
			case .unknown:
				self = .none
			case .restarting:
				self = .restarting
			}
		}

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
				self = .deleted
			case .error:
				self = .error
			case .provisioning:
				self = .provisioning
			case .restarting:
				self = .restarting
			case .UNRECOGNIZED(_):
				self = .none
			}
		}

		init(_ from: VMLocation.Status) {
			switch from {
			case .stopped:
				self = .stopped
			case .running(let mode):
				if mode == .provision {
					self = .provisioning
				} else {
					self = .running
				}
			case .paused:
				self = .paused
			}
		}
	}

	private var monitor: FileMonitor?
	private let logger = Logger("VirtualMachineDocument")
	private var agentMonitoring: Task<Void, Never>?
	/// Identifies the agent installation in flight for the current VM run. Cleared when the VM stops,
	/// so an installation that outlives its run can't overwrite the agent state of the next one.
	private var agentInstallToken: UUID?
	/// Identifies the start (or resume) in flight. `cancelPendingStart()` clears it, so a start that
	/// completes afterwards sees it no longer matches and stops the VM instead of marking it running.
	private var startToken: UUID?
	/// True while an embedded VM is being restarted (stop then start). The stop removes the PID file, and without this the
	/// file watcher would treat it as a real stop and drop `virtualMachine`, leaving the view on "Virtual machine not loaded".
	private var isRestarting = false
	private var inView: Bool = false
	/// When this document last wrote its own configuration (see `saveConfiguration(_:)`). File
	/// events are delivered asynchronously, after the save has returned, so a flag cleared at the
	/// end of the save can't filter them: `updateConfiguration()` ignores config file events
	/// arriving within `configurationSaveGracePeriod` of this instead.
	private var lastConfigurationSave: Date?
	private static let configurationSaveGracePeriod: TimeInterval = 2

	/// Held for the duration of a `startRecording(output:)`/`stopRecording()` session — see the
	/// "Recording" extension below. `nil` whenever `isRecording == false`.
	private var actionRecorder: ActionRecorder?
	private var recordingOutputURL: URL?

	/// Use the document URL as the stable identity so that `ForEach` can recognise
	/// the same VM across dictionary replacements (e.g. after a mode switch) and
	/// update existing views in-place rather than destroying and re-creating them.
	/// Updating in-place releases the old reference immediately,
	/// preventing the retain of stale documents in `VirtualMachinesView` and
	/// `CakerMenuBarExtraScene`.
	var id: String {
		url.absoluteString
	}

	private(set) var connectionManager = ConnectionManager.appConnectionManager
	private(set) var interactiveShell: InteractiveShell? = nil
	weak var vncView: NSVNCView? = nil
	private(set) var virtualMachine: VirtualMachine!
	private(set) var location: VMLocation!
	private(set) var url: URL
	private(set) var name: String = String.empty
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

	private(set) var virtualMachineConfig: VirtualMachineConfig = .init() {
		didSet {
			self.updateSeamlessTunnel()
		}
	}
	private(set) var externalRunning: Bool = false
	private(set) var canStart: Bool = false
	private(set) var canStop: Bool = false
	private(set) var canPause: Bool = false
	private(set) var canResume: Bool = false
	private(set) var canRequestStop: Bool = false
	private(set) var suspendable: Bool = false
	private(set) var isRecording: Bool = false

	/// Mirrors `RecordHandler.Session`'s equivalent published state (`Sources/cakedlib/Handlers/RecordHandler.swift`)
	/// so `HostVirtualMachineView`'s recording toolbar can offer the same locate-mode/reset/VoiceOver
	/// controls `caked record`'s own `RecordingControls` does — see the "Recording" extension below.
	private(set) var isLocateModeActive: Bool = false
	private(set) var isVoiceOverActived: Bool = false
	private(set) var hasRecordedActions: Bool = false
	private(set) var vncURL: [URL]? = nil
	private(set) var agentReady: Bool = false
	private(set) var connection: VNCConnection! = nil
	private(set) var vncTunnel: VNCTunnel? = nil
	private(set) var vncStatus: VncStatus = .disconnected
	var documentSize: ViewSize = .zero
	var launchVMExternally: Bool? = nil
	var cpuInfos: CpuInfos
	var memoryInfos: MemoryInfo
	var agentCondition: (title: LocalizedStringKey, needUpdate: Bool, disabled: Bool) = ("Install agent", false, true)
	var ipaddresses: [String] = []
	var screenshot: Data!
	private(set) var haveRequestStop: Bool = false

	/// The windows of a Linux VM run by a caked service, relayed through its `SeamlessTunnel` (see `SeamlessTunnelSession`).
	@ObservationIgnored private var seamlessSession: SeamlessTunnelSession?

	private(set) var agent = AgentStatus.none {
		didSet {
			#if DEBUG
				self.logger.trace("Agent state for \(self.name): \(self.agent)")
			#endif

			guard AppState.sharedLoaded else {
				return
			}

			if AppState.shared.currentDocument == self {
				AppState.shared.updateState()
			}
		}
	}

	private(set) var status: Status = .none {
		didSet {
			self.logger.debug("Set status for \(self.name): \(self.status)")

			self.updateSeamlessTunnel()

			// Before the `sharedLoaded` guard on purpose: documents are created while `AppState.init()` loads the
			// VMs, i.e. before `AppState.shared` is assigned, and monitoring doesn't depend on AppState.
			self.reconcileAgentMonitoring()

			guard AppState.sharedLoaded else {
				return
			}

			if let vm = self.virtualMachine {
				if vm.status.isProvisioning {
					self.canStart = false
					self.canStop = false
					self.canPause = false
					self.canResume = false
					self.canRequestStop = false
				} else {
					let virtualMachine = vm.virtualMachine

					self.canStart = virtualMachine.canStart
					self.canStop = virtualMachine.canStop
					self.canPause = virtualMachine.canPause
					self.canResume = virtualMachine.canResume
					self.canRequestStop = virtualMachine.canRequestStop
				}
			} else {
				if status == .provisioning {
					self.canStart = false
					self.canStop = false
					self.canPause = false
					self.canResume = false
					self.canRequestStop = false
				} else {
					self.canStart = status == .stopped || status == .paused
					self.canStop = status == .running
					self.canPause = status == .running
					self.canResume = status == .paused
					self.canRequestStop = status == .running
				}
			}

			MainApp.app?.updateStateVirtualMachineDocument(with: self)

			if AppState.shared.currentDocument == self {
				AppState.shared.updateState()
			}

			NotificationCenter.default.post(name: VirtualMachineDocument.StatusChangedVirtualMachine, object: self, userInfo: ["document": self.url])
		}
	}

	var recoveryMode: Bool = false {
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

	var internalRunning: Bool {
		self.status == .running && self.url.isFileURL && self.externalRunning == false && self.virtualMachine != nil
	}

	deinit {
		self.logger.debug("Release document: \(self.url)")
		self.stopAgentMonitoring()

		if let session = self.seamlessSession {
			Task { @MainActor in session.stop() }
		}

		MainApp.app?.removeStateVirtualMachineDocument(with: self.url)

		if let monitor = self.monitor {
			monitor.stop()
		}
	}

	private init(location: VMLocation) throws {
		let config = try VirtualMachineConfig(name: location.name, config: location.config())

		self.name = location.name
		self.url = location.rootURL
		self.location = location
		self.virtualMachineConfig = config
		self.screenshot = nil
		self.agent = config.agent ? config.firstLaunch ? AgentStatus.installing : AgentStatus.installed : AgentStatus.none
		self.documentSize = ViewSize(config.display.cgSize)
		self.cpuInfos = CpuInfos(from: config)
		self.memoryInfos = MemoryInfo(from: config)
		self.suspendable = config.suspendable && config.os == .darwin
		self.monitor = try FileMonitor(directory: location.rootURL, delegate: self)

		MainApp.app?.addStateVirtualMachineDocument(with: self)

		try monitor?.start()

		// Read the authoritative on-disk state only *after* the monitor is already watching, not
		// before: a VM that's built and started in one uninterrupted sequence — e.g. `compose up`,
		// which builds then immediately launches a brand-new VM the app has never seen before —
		// can write its PID file within a very short window of this document first being created.
		// Reading here first and arming the watcher after would let a PID-file write in that gap
		// slip past both: the one-time read (already stale by the time it runs) and the monitor
		// (which only delivers changes that happen after it starts), permanently stuck reporting
		// the VM as stopped in HomeView until the app relaunches. Starting the monitor first closes
		// that window — either this read already sees the fresh state, or the monitor (already
		// live) catches the write as a real event moments later.
		self.externalRunning = location.pidFile.isPIDRunning(Home.cakedCommandName)
		self.status = .init(location.status)

		// Property observers don't run for assignments made inside the type's own initializer, so the
		// `status` didSet never saw this first value: a VM already running when the document is created
		// (the PID file existed before the monitor started, so no "added" event will follow either)
		// would never get its agent monitored.
		self.reconcileAgentMonitoring()
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
		self.externalRunning = connectionManager.connectionMode != .app && status.isRunning
		self.cpuInfos = CpuInfos(from: config)
		self.memoryInfos = MemoryInfo(from: config)
		self.suspendable = config.suspendable && config.os == .darwin
		self.setDocumentSize(.init(self.virtualMachineConfig.display.cgSize))
		self.updateCurrentStatus(status, vncURL: vncURL?.compactMap { URL(string: $0) })

		MainApp.app?.addStateVirtualMachineDocument(with: self)
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

			return try VirtualMachineDocument(
				vmURL: vmURL,
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
					guard let fqn = info.fqn.first, let vmURL = URL(spaced: fqn) else {
						throw ServiceError(String(localized: "Internal error"))
					}

					guard let config = info.config else {
						throw ServiceError(String(localized: "Internal error"))
					}

					if let vm = try? VirtualMachineDocument(vmURL: connectionManager.vmURL(vmURL.vmName), status: .init(CakeAgentLib.Status(info.state)), vncURL: info.vncURL, config: config, connectionManager: connectionManager) {
						partialResult[vm.url] = vm
					}
				}
			} else {
				let storage = StorageLocation(runMode: connectionManager.connectionMode.runMode)

				vms = result.infos.reduce(into: vms) { (partialResult, info) in
					guard let fqn = info.fqn.first, let vmURL = URL(spaced: fqn) else {
						return
					}

					if let location = try? storage.find(vmURL.vmName), let vm = try? VirtualMachineDocument(location: location) {
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
	func setAgentReady(_ ready: Bool) {
		if self.agentReady != ready {
			self.logger.debug("Agent ready for \(self.name): \(ready)")
			self.agentReady = ready
		}

		// Every path that learns the agent answers (status stream, usage stream, agent monitoring) goes through
		// here, so the shell is recreated after a restart whichever of them sees the agent first.
		if ready && self.interactiveShell == nil && self.inView {
			self.interactiveShell = InteractiveShell(self.url, connectionManager: self.connectionManager)
		}
	}

	func setAgentState(_ state: AgentStatus) {
		if self.agent != state {
			self.agent = state
		}
	}

	func setStatus(_ state: Status) {
		if self.status != state {
			self.status = state
		}
	}

	@MainActor func setScreenshot(_ data: Data) {
		self.screenshot = data

		NotificationCenter.default.post(name: VirtualMachineDocument.NewScreenshot, object: data, userInfo: ["document": self.url])
	}

	private func disconnectVNC() {
		self.vncURL = nil
		self.vncStatus = .disconnected

		if let connection = self.connection {
			self.connection = nil
			connection.disconnect()
		}

		if let vncTunnel = self.vncTunnel {
			self.vncTunnel = nil
			try? vncTunnel.close().wait()
		}
	}

	func disconnect() {
		#if DEBUG
			self.logger.debug("Disconnecting \(self.name)")
		#endif

		self.inView = false
		self.stopAgentMonitoring()
		if let location = self.location {
			self.setStatus(.init(location.status))
		}

		disconnectVNC()

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
		self.inView = false
		self.vncView = nil

		if let location = self.location {
			self.setStatus(.init(location.status))
		}

		disconnectVNC()

		AppState.shared.closeVirtualMachineDocument(self)
	}

	func updateCurrentStatus(_ newStatus: Status, vncURL: [URL]? = nil) {
		self.setStatus(newStatus)
		self.vncURL = vncURL
	}

	/// Shows the windows of a Linux VM whose seamless windows are on while the caked service runs it (a local or a
	/// remote one): the service relays the guest's stream, there is no process of ours that could listen for it.
	/// In `.app` mode the VM runs in this process, which listens itself.
	func updateSeamlessTunnel() {
		let name = self.name
		let connectionManager = self.connectionManager

		Task { @MainActor in
			// Decided when the task runs, not when it was queued: a start queued while the VM was running must not
			// open a session for a document that has stopped since (and the stop must not be discarded because the
			// session did not exist yet when it was asked).
			let wanted = connectionManager.connectionMode != .app && self.virtualMachineConfig.os == .linux && self.virtualMachineConfig.seamless && self.status == .running

			guard wanted || self.seamlessSession != nil else { return }

			if wanted {
				if self.seamlessSession == nil {
					self.seamlessSession = SeamlessTunnelSession(vmName: name, connectionManager: connectionManager)
				}

				self.seamlessSession?.start()
			} else if let session = self.seamlessSession {
				session.stop()
				self.seamlessSession = nil
			}
		}
	}

	func setStateAsRestarting() {
		#if DEBUG
			self.logger.debug("setStateAsRestarting")
		#endif
		self.interactiveShell?.cancelShell()
		self.interactiveShell = nil
		self.setState(.restarting)
	}

	/// A restart failed: the request may or may not have reached the VM, so take the status from where it is
	/// authoritative instead of leaving the document on "restarting".
	@MainActor
	private func reconcileAfterFailedRestart() {
		let current: Status

		if let location = self.location {
			current = Status(location.status)
		} else if let infos = try? self.connectionManager.virtualMachineInfos(vmURL: self.url) {
			current = Status(infos.infos.status)
		} else {
			current = .running
		}

		switch current {
		case .running, .restarting, .none:
			self.setState(.running)
		case .stopped, .error, .deleted:
			self.setStateAsStopped(current)
		default:
			self.setOtherState(status: current)
		}
	}

	@MainActor
	func setStateAsStopped(_ status: Status = .stopped) {
		#if DEBUG
			self.logger.debug("setStateAsStopped to \(status)")
		#endif

		// Stop agent monitoring when VM is stopped
		self.stopAgentMonitoring()
		self.agentInstallToken = nil
		self.interactiveShell?.cancelShell()

		self.updateCurrentStatus(status, vncURL: nil)
		self.haveRequestStop = false
		self.interactiveShell = nil
		self.externalRunning = false
		self.agentCondition = ("Install agent", false, true)
		self.virtualMachine = nil

		self.setAgentReady(false)

		disconnectVNC()

		if self.inView == false {
			AppState.shared.closeVirtualMachineDocument(self)
		}
	}

	@MainActor
	func setStateAsRunning(_ status: Status, vncURL: [URL]?) {
		guard self.status != .running else {
			if self.agentReady {
				if self.interactiveShell == nil && self.inView {
					self.interactiveShell = InteractiveShell(self.url, connectionManager: self.connectionManager)
				}
			}

			// A repeated running event must not discard a pending "Update agent" condition
			// (set by agent monitoring or installAgent); only refresh the default one.
			if self.agentCondition.needUpdate == false {
				self.agentCondition = ("Install agent", false, self.agent != .none)
			}

			self.vncURL = vncURL
			return
		}

		#if DEBUG
			self.logger.debug("setStateAsRunning: \(status) vncURL: \(vncURL?.map { $0.absoluteString } ?? [])")
		#endif

		self.updateCurrentStatus(status, vncURL: vncURL)

		self.setAgentReady(false)
		self.agentCondition = ("Install agent", false, self.agent != .none)

		AppState.shared.openVirtualMachineDocument(self)
	}

	func setOtherState(status: Status, vncURL: [URL]? = nil) {
		self.updateCurrentStatus(status, vncURL: vncURL)
	}

	func setState(_ status: Caked_VirtualMachineStatus) {
		let newStatus = Status(status)

		logger.debug("setState to \(status) -> \(newStatus)")

		func agentIsReady() {
			// An installAgent run in flight owns `agent` until its completion.
			if self.agentInstallToken == nil {
				self.setAgentState(.installed)
			}

			self.setAgentReady(true)

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

		// `agentReady` is a running VM whose agent answers: it can arrive straight from "starting" or "restarting"
		// (the VM process sends it on its first usage report), and must not be taken for a stop.
		if newStatus == .running {
			self.updateCurrentStatus(newStatus, vncURL: self.vncURL)

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

			if status == .agentReady {
				agentIsReady()
			}
		} else {
			self.updateCurrentStatus(newStatus, vncURL: nil)

			self.interactiveShell?.cancelShell()
			self.interactiveShell = nil
			self.agentCondition = ("Install agent", false, true)
			self.setAgentReady(false)

			disconnectVNC()
		}
	}

	func setDocumentSize(_ size: ViewSize) {
		if self.documentSize != size {
			self.documentSize = size
		}
	}

	func setScreenSize(_ size: ViewSize) {
		if size.width == 0 && size.height == 0 {
			return
		}

		self.setDocumentSize(size)
		self.setVncScreenSize(size)
	}
}

// MARK: - Embeded VirtualMachine
extension VirtualMachineDocument {
	@discardableResult @MainActor
	private func createVirtualMachine() throws -> VirtualMachine {
		let config = try! location.config()
		let virtualMachine = try VirtualMachine(
			location: location,
			config: config,
			display: .ui,
			screenSize: config.display.cgSize,
			mode: self.recoveryMode ? .recovery : .normal,
			runMode: .app)

		self.virtualMachine = virtualMachine
		self.vncURL = nil
		self.didChangedState(virtualMachine)

		virtualMachine.delegate = self

		return virtualMachine
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
			self.name = location.name
			self.setAgentState(self.virtualMachineConfig.agent ? (self.virtualMachineConfig.firstLaunch ? .installing : .installed) : .none)

			if monitor == nil {
				let monitor = try FileMonitor(directory: location.rootURL, delegate: self)
				try monitor.start()

				self.monitor = monitor
			}

			// Read after the monitor is already watching, not before — see the matching comment in
			// `init(location:)` for why: a PID-file write racing ahead of a one-time disk read is
			// otherwise permanently missed by a monitor that only starts watching afterward.
			self.externalRunning = location.pidFile.isPIDRunning(Home.cakedCommandName)
			self.setStatus(.init(location.status))

			if self.isLaunchVMExternally && self.externalRunning {
				self.setDocumentSize(self.getVncScreenSize())
			} else {
				self.setDocumentSize(.init(self.virtualMachineConfig.display.cgSize))
			}

			retrieveVNCURL()

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
	func startRemotely(location: URL, token: UUID? = nil) async throws {
		let vncPassword = self.virtualMachineConfig.vncPassword
		let vncPort = try Utilities.findFreePort()
		let screenSize = GRPCLib.ViewSize(width: Int(self.documentSize.width), height: Int(self.documentSize.height))

		let result = try self.connectionManager.startVirtualMachine(vmURL: location, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: 120, startMode: .service, recoveryMode: self.recoveryMode)

		if let token, self.startToken != token {
			await self.finishCancelledStart()
		} else if result.started {
			let vncInfos = try self.connectionManager.vncInfos(vmURL: location)

			#if DEBUG
				self.logger.debug("VM started on \(result.ip)")
				self.logger.debug("Found VNC URL: \(vncInfos.urls)")
			#endif

			await self.setStateAsRunning(.running, vncURL: vncInfos.urls.compactMap { URL(string: $0) })
		} else {
			self.logger.error("VM \(self.name) failed to start: \(result.reason)")
			await self.setStateAsStopped()
		}
	}

	func startLocally(location: VMLocation, token: UUID? = nil) async throws {
		let config = try location.config()
		let vncPassword = config.vncPassword ?? UUID().uuidString
		let vncPort = try Utilities.findFreePort()
		let vncURL = URL(string: "vnc://:\(vncPassword)@localhost:\(vncPort)")!
		let screenSize = GRPCLib.ViewSize(width: Int(self.documentSize.width), height: Int(self.documentSize.height))
		let result = try self.connectionManager.startVirtualMachine(vmURL: location.rootURL, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: 120, startMode: .service, recoveryMode: self.recoveryMode)

		if let token, self.startToken != token {
			await self.finishCancelledStart()
		} else if result.started {
			#if DEBUG
				self.logger.debug("VM started on \(result.ip)")
				self.logger.debug("Found VNC URL: \(vncURL)")
			#endif

			await self.tryVNCConnect(vncURL: vncURL)
			await self.setStateAsRunning(.running, vncURL: [vncURL])
		} else {
			self.logger.error("VM \(self.name) failed to start: \(result.reason)")
		}
	}

	func resumeFromUI() {
		guard self.status == .paused else {
			return
		}

		let token = self.beginStart()

		func completion(_ result: Result<VirtualMachine, any Error>) {
			Task {
				if self.startToken != token {
					await self.finishCancelledStart()
				} else if case .failure(let error) = result {
					await self.setStateAsStopped(.error)
					await alertError(error)
				} else {
					await self.setStateAsRunning(.running, vncURL: self.vncURL)
				}
			}
		}

		if self.isLaunchVMExternally {
			self.setOtherState(status: .starting, vncURL: vncURL)
			self.externalRunning = true

			Task {
				do {
					if let location {
						try await self.startLocally(location: location, token: token)
					} else {
						try await self.startRemotely(location: url, token: token)
					}
				} catch {
					await self.setStateAsStopped()
					await alertError(error)
				}
			}
		} else if let virtualMachine = self.virtualMachine {
			self.externalRunning = false

			self.setOtherState(status: .starting)

			virtualMachine.resumeVMFromUI(completionHandler: completion)
		} else {
			self.setOtherState(status: .starting)

			Task {
				do {
					let virtualMachine = try await self.createVirtualMachine()

					guard self.startToken == token else {
						await self.setStateAsStopped()
						return
					}

					virtualMachine.restoreStateVMFromUI(completionHandler: completion)
				} catch {
					await self.setStateAsStopped()
					await alertError(error)
				}
			}
		}
	}

	func startFromUI() {
		guard self.status == .stopped else {
			return
		}

		let token = self.beginStart()

		if self.isLaunchVMExternally {
			self.setOtherState(status: .starting, vncURL: vncURL)
			self.externalRunning = true

			Task {
				do {
					if let location {
						try await self.startLocally(location: location, token: token)
					} else {
						try await self.startRemotely(location: url, token: token)
					}
				} catch {
					await self.setStateAsStopped()
					await alertError(error)
				}
			}
		} else {
			self.externalRunning = false

			if let virtualMachine = self.virtualMachine {
				self.setOtherState(status: .starting)

				virtualMachine.startFromUI { _ in
					Task {
						if self.startToken != token {
							await self.finishCancelledStart()
						}
					}
				}
			} else {
				self.setOtherState(status: .starting)

				Task {
					do {
						let virtualMachine = try await self.createVirtualMachine()

						guard self.startToken == token else {
							await self.setStateAsStopped()
							return
						}

						virtualMachine.startFromUI { _ in
							Task {
								if self.startToken != token {
									await self.finishCancelledStart()
								}
							}
						}
					} catch {
						await self.setStateAsStopped()
						await alertError(error)
					}
				}
			}
		}
	}

	func restartFromUI() {
		guard self.status == .running else {
			return
		}

		// Nothing can dispatch the restart: leave the running state alone.
		guard self.externalRunning || self.virtualMachine != nil else {
			return
		}

		self.setStateAsRestarting()

		if self.externalRunning {
			Task {
				do {
					try self.connectionManager.restartVirtualMachine(vmURL: self.url)
				} catch {
					await self.reconcileAfterFailedRestart()
					await alertError(error)
				}
			}
		} else if let virtualMachine = self.virtualMachine {
			self.isRestarting = true
			// The restart never goes through `setStateAsStopped()` (the file watcher ignores the PID removal while
			// restarting), so invalidate any agent installation of the run being replaced here, or it could
			// overwrite the agent state of the next run.
			self.agentInstallToken = nil

			virtualMachine.restartFromUI { result in
				DispatchQueue.main.async {
					self.isRestarting = false

					if case .failure(let error) = result {
						self.reconcileAfterFailedRestart()
						alertError(error)
					}
				}
			}
		}
	}

	/// Starts a new start/resume attempt and returns the token identifying it.
	private func beginStart() -> UUID {
		let token = UUID()

		self.startToken = token

		return token
	}

	/// Stop pressed while the VM is still starting: invalidate the pending start so its completion
	/// can't mark the VM running, and stop the VM as soon as it can be (right away when it is already
	/// up, otherwise from the start's own completion via `finishCancelledStart()`).
	private func cancelPendingStart(_ completionHandler: CompletionHandler?) {
		self.startToken = nil
		self.setOtherState(status: .stopping)

		if self.externalRunning {
			Task {
				// Best effort: the VM process may not exist yet, in which case the start's completion stops it.
				_ = try? self.connectionManager.stopVirtualMachine(vmURL: self.url)
				completionHandler?(nil)
			}
		} else {
			completionHandler?(nil)
		}
	}

	/// Called once a start that was cancelled in the meantime has finished: make sure the VM is not left running.
	@MainActor
	private func finishCancelledStart() async {
		if self.externalRunning {
			_ = try? self.connectionManager.stopVirtualMachine(vmURL: self.url)
			self.setStateAsStopped()
		} else if let virtualMachine = self.virtualMachine {
			virtualMachine.stopFromUI { _ in
				Task { @MainActor in
					self.setStateAsStopped()
				}
			}
		} else {
			self.setStateAsStopped()
		}
	}

	func stopFromUI(force: Bool, _ completionHandler: CompletionHandler? = nil) {
		if self.status == .starting {
			self.cancelPendingStart(completionHandler)
			return
		}

		guard self.status == .running else {
			return
		}

		self.setOtherState(status: .stopping)

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
			if force || self.haveRequestStop {
				virtualMachine.stopFromUI(completionHandler: completionHandler)
			} else {
				self.haveRequestStop = true

				if self.virtualMachineConfig.os != .darwin {
					virtualMachine.requestStopFromUI { result in
						Task { @MainActor in
							self.setStateAsStopped()
							completionHandler?(result)
						}
					}
				} else if self.virtualMachineConfig.agent == false {
					virtualMachine.suspendFromUI { result in
						Task { @MainActor in
							self.setStateAsStopped()
							completionHandler?(result)
						}
					}
				} else if let location = self.location {
					Task {
						do {
							try location.stopVirtualMachine(force: false, runMode: .app)
							await MainActor.run {
								completionHandler?(nil)
							}
						} catch {
							await MainActor.run {
								completionHandler?(error)
							}
						}
					}
				}
			}
		}
	}

	typealias CompletionHandler = (Error?) -> Void

	func suspendFromUI(_ completionHandler: CompletionHandler? = nil) {
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
			virtualMachine.suspendFromUI { error in
				Task {
					if let error {
						await self.setStateAsStopped(.error)
						await alertError(error)
						completionHandler?(error)
					} else {
						await self.setStateAsStopped(.paused)
						completionHandler?(nil)
					}
				}
			}
		}
	}

	func deleteVirtualMachine() throws -> DeleteReply {
		try self.connectionManager.deleteVirtualMachine(vmURL: self.url)
	}

	func duplicateVirtualMachine(to: String) throws -> DuplicatedReply {
		try self.connectionManager.duplicateVirtualMachine(vmURL: self.url, to: to, resetMacAddress: true)
	}

	func renameVirtualMachine(to: String) throws -> RenameReply {
		try self.connectionManager.renameVirtualMachine(vmURL: self.url, to: to)
	}

	func updateConfiguration() {
		if let lastConfigurationSave, Date().timeIntervalSince(lastConfigurationSave) < Self.configurationSaveGracePeriod {
			return
		}

		if let location = self.location, let newConfig = try? location.reloadConfig() {
			let config = VirtualMachineConfig(name: self.name, config: newConfig)

			if config != self.virtualMachineConfig {
				self.virtualMachineConfig = config
			}
		}
	}

	func saveConfiguration(_ config: VirtualMachineConfig) {
		let connectionMode = self.connectionManager.connectionMode

		// Stamped once the save has written to disk (whether it succeeded or not), so the
		// grace period covers the file events that write produces.
		defer {
			self.lastConfigurationSave = Date()
		}

		self.virtualMachineConfig = config

		do {
			if connectionMode != .app {
				var allowReconfigureDisk = true

				if Bundle.isApplicationSandboxed && self.virtualMachineConfig.diskSizeIsChanged && self.virtualMachineConfig.diskFormat == .asif {
					let informativeText: String
					let command: String

					if connectionMode == .remote {
						command = "diskutil image resize --size=\(virtualMachineConfig.diskSizeInGiB)G \"$(caked home)/vms/\(self.name).cakedvm/disk.img\""
						informativeText = String(localized: "Resize disk is not available in sandboxed mode with remote connection. To resize the disk, run the following command on the target machine:")
					} else {
						let home = try Utils.getHome(runMode: connectionMode.runMode, createItIfNotExists: true).appendingPathComponent("vms/\(self.name).cakedvm/disk.img")

						command = "diskutil image resize --size=\(virtualMachineConfig.diskSizeInGiB)G \"\(home.path(percentEncoded: false))\""
						informativeText = String(localized: "Resize disk is not available in sandboxed mode via service. To resize the disk, run the following command in Terminal:")
					}

					DispatchQueue.main.async {
						showDiskResizeAlert(
							informativeText: informativeText,
							command: command
						)
					}

					allowReconfigureDisk = false
				}

				let options = self.virtualMachineConfig.configureOptions(allowReconfigureDisk: allowReconfigureDisk)
				let reply = try ConfigureHandler.configure(client: self.connectionManager.serviceClient, name: self.name, options: options, runMode: connectionMode.runMode)

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

			MainApp.app?.updateStateVirtualMachineDocument(with: self)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
}

// MARK: - Recording
extension VirtualMachineDocument {
	/// Mirrors the exact condition under which `HostVirtualMachineView.vmView(_:)` renders an
	/// `InternalVirtualMachineView` — i.e. there's a real, live `VNCVirtualMachineView` (this
	/// document's `virtualMachine.vzMachineView`) on screen for a tap to be armed against. Recording
	/// makes no sense for an externally-launched or remote VM: there's no local view there to tap.
	var canRecord: Bool {
		self.connectionManager.connectionMode == .app && self.externalRunning == false && self.virtualMachine != nil
	}

	/// Arms an `ActionRecorder` directly on this document's already-live `VNCVirtualMachineView`
	/// (`virtualMachine.createVirtualMachineView()`, memoized to the exact same view
	/// `CakerVZVirtualMachineView.attachtoDocument` already set as `virtualMachine.vzMachineView` —
	/// see `InternalVirtualMachineView.swift`) — no new capture mechanism, this reuses the tap
	/// `caked record` itself already relies on (`VNCVirtualMachineView.actionRecorder`, see
	/// CLAUDE.md's PackerLite/`caked record` section). Credential scrubbing, token mapping, and
	/// wait-gap handling are all `ActionRecorder`'s own responsibility, unchanged here.
	@MainActor
	func startRecording(output: URL) {
		guard self.canRecord else {
			DispatchQueue.main.async {
				alertError(String(localized: "Unable to start recording"), String(localized: "Recording is only available for a virtual machine running locally inside Caker."))
			}
			return
		}

		guard self.isRecording == false else {
			return
		}

		guard let targetView = self.virtualMachine?.vzMachineView else {
			DispatchQueue.main.async {
				alertError(String(localized: "Unable to start recording"), String(localized: "The VM view is not ready yet — please try again once the VM display is visible."))
			}
			return
		}

		let recorder = ActionRecorder(targetView, os: self.virtualMachineConfig.os, username: self.virtualMachineConfig.configuredUser, password: self.virtualMachineConfig.configuredPassword)

		targetView.actionRecorder = { [weak self] sender, action in
			self?.handleRecordedAction(sender, action)
		}

		self.actionRecorder = recorder
		self.recordingOutputURL = output
		self.isRecording = true
		self.isLocateModeActive = false
		self.isVoiceOverActived = false
		self.hasRecordedActions = false

		#if DEBUG
			self.logger.debug("Started recording \(self.name) to \(output.path)")
		#endif
	}

	/// The armed tap: forwards to the recorder, then keeps `hasRecordedActions` in sync so the
	/// toolbar's Reset button can enable/disable live — mirrors `RecordHandler.Session.handleRecordedAction`
	/// exactly, since `ActionRecorder` itself isn't observable.
	private func handleRecordedAction(_ sender: NSView, _ action: RecordedAction) {
		guard let recorder = self.actionRecorder else {
			return
		}

		recorder.record(sender, action)

		let hasRecordedActions = recorder.hasRecordedActions

		if hasRecordedActions != self.hasRecordedActions {
			if Thread.isMainThread {
				self.hasRecordedActions = hasRecordedActions
			} else {
				DispatchQueue.main.async {
					self.hasRecordedActions = hasRecordedActions
				}
			}
		}
	}

	/// Arms/disarms the OCR-assist "locate mode" overlay — see `RecordHandler.Session.toggleLocateMode()`.
	@MainActor
	func toggleRecordingLocateMode() {
		guard self.isRecording, let recorder = self.actionRecorder, let targetView = self.virtualMachine?.vzMachineView else {
			return
		}

		self.isLocateModeActive.toggle()
		recorder.setLocateModeActive(self.isLocateModeActive, sender: targetView)
	}

	/// Toggles VoiceOver in the guest via the recorder's `<voiceOverOn>`/`<voiceOverOff>` token
	/// sequence — see `RecordHandler.Session.toggleVoiceOver(confirm:)`. Only meaningful for
	/// Darwin VMs; the toolbar hides this control entirely for non-macOS guests.
	@MainActor
	func toggleRecordingVoiceOver(confirm: Bool) {
		guard self.isRecording, let recorder = self.actionRecorder else {
			return
		}

		self.isVoiceOverActived.toggle()
		recorder.toggleVoiceOver(confirm: confirm)
		self.hasRecordedActions = true
	}

	/// Discards recorded steps and starts over without stopping the session — see
	/// `RecordHandler.Session.reset()`.
	@MainActor
	func resetRecording() {
		guard self.isRecording, let recorder = self.actionRecorder else {
			return
		}

		recorder.reset()
		self.hasRecordedActions = false
		self.isVoiceOverActived = false
	}

	/// Disarms the tap, serializes the captured actions (`ActionRecorder.finish()`), and writes the
	/// resulting `boot_command:` YAML to the output location chosen when recording started —
	/// mirroring `RecordHandler.Session.stopAndSave()`'s exact pattern (`Sources/cakedlib/Handlers/RecordHandler.swift`).
	func stopRecording() {
		guard self.isRecording, let recorder = self.actionRecorder else {
			return
		}

		self.virtualMachine?.vzMachineView?.actionRecorder = nil

		let yaml = recorder.finish()
		let destination = self.recordingOutputURL

		self.actionRecorder = nil
		self.recordingOutputURL = nil
		self.isRecording = false
		self.isLocateModeActive = false
		self.isVoiceOverActived = false
		self.hasRecordedActions = false

		guard let destination else {
			return
		}

		do {
			try yaml.write(to: destination, atomically: true, encoding: .utf8)

			self.logger.info("Recorded template saved to \(destination.path)")

			DispatchQueue.main.async {
				alertError(
					String(localized: "Recording saved"),
					String(
						format: String(localized: "Recorded template saved to %@\n\nThis is a first draft — review it and consider hardening timing-sensitive waits with <locate> anchors before relying on it for unattended --autoinstall runs."),
						destination.path
					))
			}
		} catch {
			self.logger.error("Failed to write recorded template to \(destination.path): \(error)")

			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
}

// MARK: - VirtualMachineDelegate
extension VirtualMachineDocument: VirtualMachineDelegate {
	func didChangedState(_ vm: VirtualMachine) {
		#if DEBUG
			self.logger.debug("didChangedState: \(vm.virtualMachine.state.description)")
		#endif

		guard let status = Status(rawValue: vm.virtualMachine.state.rawValue) else {
			self.setStatus(.none)
			return
		}

		self.setStatus(status)
		self.virtualMachineConfig.agent = vm.config.agent
		self.virtualMachineConfig.firstLaunch = vm.config.firstLaunch
		self.setAgentState(vm.config.agent ? vm.config.firstLaunch ? .installing : .installed : .none)
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
			if file.lastPathComponent == location.pidFile.lastPathComponent || file.lastPathComponent == location.restartURL.lastPathComponent {
				DispatchQueue.main.async {
					let status = location.status

					switch location.status {
					case .running(let mode):
						switch mode {
						case .caked:
							self.externalRunning = true
							self.setStatus(.running)
							self.retrieveVNCURL()
						case .caker:
							self.externalRunning = false
							self.setStateAsRunning(.running, vncURL: nil)
						case .provision:
							self.externalRunning = true
							self.setStatus(.provisioning)
							self.retrieveVNCURL()
						case .restart:
							self.setStateAsRestarting()
						case .none:
							break
						}
					case .stopped:
						// The PID file is removed by the stop half of a restart: the VM is coming back, keep it loaded.
						// `isRestarting` covers a restart of the embedded VM, the marker one run by caked.
						guard self.isRestarting == false && location.restartURL.fileExists == false else {
							break
						}

						self.externalRunning = false
						self.setStateAsStopped()
					default:
						self.setOtherState(status: .init(status))
					}
				}
			} else if file.lastPathComponent == location.screenshotURL.lastPathComponent {
				if let screenshot = try? Data(contentsOf: location.screenshotURL) {
					DispatchQueue.main.async {
						self.setScreenshot(screenshot)
					}
				}
			} else if file.lastPathComponent == location.configURL.lastPathComponent || file.lastPathComponent == location.cakeURL.lastPathComponent {
				DispatchQueue.main.async {
					self.updateConfiguration()
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
		if self.externalRunning && self.status.isRunning {
			#if DEBUG
				self.logger.debug("setVncScreenSize: \(screenSize.description)")
			#endif

			// One channel at a time. The VNC view asks for its own size, the one the framebuffer has to fill; sending
			// the window's size over gRPC as well gives the server two different sizes (they differ by the toolbar)
			// and it switches from one to the other for ever. gRPC is only for a VM whose view is not connected yet.
			if let vncView = self.vncView {
				vncView.setDesktopSize()
			} else if self.connectionManager.connectionMode != .remote {
				Task {
					await self.connectionManager.setVncScreenSize(vmURL: self.url, screenSize: screenSize)
				}
			}
		}
	}

	func getVncScreenSize() -> ViewSize {
		let screenSize = ViewSize(width: CGFloat(self.virtualMachineConfig.display.width), height: CGFloat(self.virtualMachineConfig.display.height))
		return self.connectionManager.getVncScreenSize(vmURL: self.url, screenSize)
	}

	func retrieveVNCURL() {
		guard self.externalRunning && (self.status == .running || self.status == .provisioning) else {
			return
		}

		MainActor.assumeIsolated {
			if let vncInfos = try? self.connectionManager.vncInfos(vmURL: self.url) {
				self.logger.info("Retrieved VNC URL, current state \(self.status): \(vncInfos.urls)")

				self.setStateAsRunning(
					self.status,
					vncURL: vncInfos.urls.compactMap {
						URL(string: $0)
					})

				if let screenSize = vncInfos.screenSize {
					self.setDocumentSize(.init(width: CGFloat(screenSize.width), height: CGFloat(screenSize.height)))
				}

				if self.inView {
					self.tryVNCConnect()
				}
			} else {
				self.setStateAsRunning(self.status, vncURL: nil)
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
				if let tunnel = try? client.createVNCTunnel(eventLoopGroup: Utilities.group, vmName: self.name) {
					self.vncTunnel = tunnel
					var components = URLComponents()

					components.scheme = "vnc"
					components.host = "127.0.0.1"
					components.port = tunnel.localPort

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
				if self.status == .starting || self.status == .running || self.status == .provisioning {
					newStatus = .connecting
				}
			} else if connectionState.status == .disconnected {
				if self.connection != nil {
					self.connection = nil

					if self.status == .starting || self.status == .running || self.status == .provisioning {
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

		self.vncView?.connection(connection, didResizeFramebuffer: framebuffer)

		DispatchQueue.main.async {
			self.setDocumentSize(.init(framebuffer.cgSize))

			NotificationCenter.default.post(name: VirtualMachineDocument.VNCFramebufferSizeChanged, object: framebuffer.cgSize, userInfo: ["document": self.url])
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

		let token = UUID()

		@MainActor func finish(_ status: AgentStatus) {
			guard self.agentInstallToken == token else {
				// The VM run this installation belongs to is over (stopped, possibly restarted):
				// leave the current run's agent state alone. Still release the caller unless a newer
				// installation is in flight, whose own completion will do it.
				if self.agentInstallToken == nil {
					done(self.agent)
				}

				return
			}

			self.agentInstallToken = nil
			self.setAgentState(status)

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

		self.agentInstallToken = token
		self.setAgentState(.installing)

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

			// Only `finish` updates the document, once it has checked the run this installation belongs to.
			await finish(agent)
		}
	}

	@MainActor
	private func agentMonitoringSuccess(infos: VMInformations) {
		#if DEBUG
			self.logger.debug("Agent monitoring: VM \(self.name) agent is responding")
		#endif

		// The probe answered after its monitoring was cancelled (the VM is restarting or stopped): it describes the run
		// that is going away and must not mark the agent ready nor create a shell.
		guard Task.isCancelled == false && self.status == .running else {
			return
		}

		self.setAgentReady(true)
		self.ipaddresses = infos.ipaddresses
		self.cpuInfos.update(infos.cpuInfos)
		self.memoryInfos.update(infos.memory)

		if let firstIP = infos.ipaddresses.first {
			self.logger.debug("VM \(self.name) is ready with IP: \(firstIP)")
		}

		if infos.agentVersion != CAKEAGENT_VERSION {
			#if DEBUG
				self.logger.debug("Agent monitoring: VM \(self.name) agent need to be updated")
			#endif
			self.agentCondition = ("Update agent", true, false)
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
			let infos = try self.connectionManager.virtualMachineInfos(vmURL: self.url, callOptions: CallOptions(timeLimit: .timeout(.seconds(10))))

			// The infos fall back to the VM's offline description when the agent doesn't answer, so a reply
			// alone doesn't prove the agent is up: only one that carries the agent's version does.
			guard let agentVersion = infos.infos.agentVersion, agentVersion.isEmpty == false else {
				return true
			}

			await agentMonitoringSuccess(infos: infos.infos)
		} catch {
			return agentMonitoringFailure(error: error)
		}

		return false
	}

	/// Starts agent monitoring while the VM runs and stops it as soon as it isn't running (stopped, deleted, but
	/// also restarting, paused...). Stopping drops the task, which stays assigned once it has seen the agent, so
	/// monitoring starts again when the VM is back to running. Both calls are idempotent.
	func reconcileAgentMonitoring() {
		if self.status == .running {
			self.startAgentMonitoring()
		} else {
			self.stopAgentMonitoring()
		}
	}

	func startAgentMonitoring() {
		guard agentMonitoring == nil && self.status == .running && self.agent != .none else {
			return
		}

		self.agentMonitoring = Task {
			var isWaitingForAgent = true

			await withTaskCancellationHandler(
				operation: {
					while Task.isCancelled == false && isWaitingForAgent {
						isWaitingForAgent = await self.performAgentMonitoring()

						// Readiness is written by agentMonitoringSuccess() only: the loop also ends on a failure
						// that retrying won't change, and that must not read as "ready".
						if isWaitingForAgent {
							try? await Task.sleep(nanoseconds: 1_000_000_000)
						}
					}
				},
				onCancel: {
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
	static let StatusChangedVirtualMachine = NSNotification.Name("StatusChangedVirtualMachine")
	static let OpenVirtualMachine = NSNotification.Name("OpenVirtualMachine")
	static let StartVirtualMachine = NSNotification.Name("StartVirtualMachine")
	static let DeleteVirtualMachine = NSNotification.Name("DeleteVirtualMachine")
	static let NewScreenshot = NSNotification.Name("NewScreenshot")
	static let VNCFramebufferSizeChanged = NSNotification.Name("VNCFramebufferSizeChanged")
}

// MARK: - Usage update
extension VirtualMachineDocument {
	/// Update the document's usage information with new VMUsage data asynchronously on the main actor
	@MainActor
	public func setUsage(_ usage: Caked_CurrentUsageReply) async {
		// An installAgent run in flight owns `agent` until its completion.
		if self.agentInstallToken == nil {
			self.setAgentState(.installed)
		}

		self.setAgentReady(true)
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
		if self.connectionManager.connectionMode == .remote {
			disconnectVNC()

			if let interactiveShell {
				self.interactiveShell = nil
				interactiveShell.cancelShell()
			}
		}
	}
}
