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
import FileMonitor
import FileMonitorShared
import GRPC
import GRPCLib
import NIO
import SwiftTerm
import RoyalVNCKit

extension UTType {
	static var virtualMachine: UTType {
		UTType(importedAs: "com.aldunelabs.caker.caked-vm")
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

class VirtualMachineDocument: FileDocument, VirtualMachineDelegate, FileDidChangeDelegate, ObservableObject, Equatable, Identifiable {
	typealias ShellHandlerResponse = (Cakeagent_CakeAgent.ExecuteResponse) -> Void

	static func == (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		lhs.virtualMachine == rhs.virtualMachine
	}

	static var readableContentTypes: [UTType] { [.virtualMachine] }

	enum AgentStatus: Int {
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

	enum Status: Int {
		case none = -2
		case external = -1
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
	}

	private var client: CakeAgentClient!
	private var stream: CakeAgentExecuteStream!
	private var shellHandlerResponse: ShellHandlerResponse!
	private var monitor: FileMonitor?
	private var inited = false
	private let logger = Logger("VirtualMachineDocument")

	weak var framebufferView: VNCFramebufferView? = nil

	var virtualMachine: VirtualMachine!
	var location: VMLocation?
	var name: String = ""
	var description: String {
		name
	}

	@Published var virtualMachineConfig: VirtualMachineConfig = .init()
	@Published var status: Status = .none
	@Published var canStart: Bool = false
	@Published var canStop: Bool = false
	@Published var canPause: Bool = false
	@Published var canResume: Bool = false
	@Published var canRequestStop: Bool = false
	@Published var suspendable: Bool = false
	@Published var vncURL: URL? = nil
	@Published var agent = AgentStatus.none
	@Published var connection: VNCConnection! = nil
	@Published var vncStatus: VncStatus = .disconnected

	init() {
		self.virtualMachine = nil
		self.virtualMachineConfig = VirtualMachineConfig()
	}

	init(name: String) {
		self.name = name
	}

	required init(configuration: ReadConfiguration) throws {
		let file = configuration.file

		guard file.isDirectory else {
			throw ServiceError("Internal error")
		}

		if let fileName = file.filename {
			let vmName = fileName.deletingPathExtension
			let location = StorageLocation(runMode: .app).location(vmName)

			if file.matchesContents(of: location.rootURL) {
				AppState.shared.replaceVirtualMachineDocument(location.rootURL, with: self)

				try DispatchQueue.main.sync {
					if loadVirtualMachine(from: location.rootURL) == false {
						throw ServiceError("Unable to load virtual machine")
					}
				}
			}
		}
	}

	func close() {
		self.logger.info("Closing \(self.name)")
		self.virtualMachine = nil
		self.inited = false
		self.status = .none
		self.agent = .none

		if let monitor = self.monitor {
			monitor.stop()
		}

		if let connection = self.connection {
			connection.disconnect()
		}

		if self.client != nil {
			self.client.close().whenComplete { _ in
				self.client = nil
				self.stream = nil
			}
		}
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		throw ServiceError("Unimplemented")
	}

	func loadVirtualMachine(from location: VMLocation) -> URL? {
		do {
			let config = try location.config()

			self.virtualMachineConfig = VirtualMachineConfig(vmname: location.name, config: config)
			self.location = location
			self.agent = config.agent ? .installed : .none
			self.name = location.name

			if location.pidFile.isPIDRunning("caked") {
				self.status = .external

				self.canStart = false
				self.canStop = true
				self.canPause = true
				self.canResume = false
				self.canRequestStop = true
				self.suspendable = config.suspendable
				
				retrieveVNCURL()
			} else {
				let virtualMachine = try VirtualMachine(location: location, config: config, runMode: .app)

				self.virtualMachine = virtualMachine
				self.vncURL = nil
				self.didChangedState(virtualMachine)
				virtualMachine.delegate = self
			}

			if monitor == nil {
				let monitor = try FileMonitor(directory: location.rootURL, delegate: self)
				try monitor.start()

				self.monitor = monitor
			}

			return location.rootURL
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}

		return nil
	}

	func loadVirtualMachine(from fileURL: URL) -> Bool {
		if inited {
			return true
		}

		defer {
			inited = true
		}

		do {
			return self.loadVirtualMachine(from: try VMLocation(rootURL: fileURL, template: false).validatate(userFriendlyName: fileURL.lastPathComponent)) != nil
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}

		return false
	}

	func loadVirtualMachine() -> URL? {
		guard let virtualMachine = self.virtualMachine else {
			if let location = try? StorageLocation(runMode: .app).find(name) {
				return self.loadVirtualMachine(from: location)
			}

			DispatchQueue.main.async {
				alertError(ServiceError("Unable to find virtual machine: \(self.name)"))
			}

			return nil
		}

		return virtualMachine.location.rootURL
	}

	func installAgent(_ done: @escaping () -> Void) {
		if let virtualMachine = self.virtualMachine {
			self.agent = .installing

			Task {
				var agent: AgentStatus = .installing

				do {
					agent = try await virtualMachine.installAgent(timeout: 2, runMode: .app) ? .installed : .none

					if agent == .none {
						throw ServiceError("Failed to install agent.")
					}
				} catch {
					await alertError(error)
					
					agent = .none
				}

				DispatchQueue.main.async {
					self.agent = agent
					done()
				}
			}
		}
	}

	func startFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.startFromUI()
		}
	}

	func restartFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.restartFromUI()
		} else if self.status == .external {
			do {
				let result = try StopHandler.restart(name: self.name, force: false, runMode: .app)

				if result.stopped == false {
					MainActor.assumeIsolated {
						alertError(ServiceError(result.reason))
					}
				}
			} catch {
				MainActor.assumeIsolated {
					alertError(error)
				}
			}
		}
	}

	func stopFromUI(force: Bool) {
		if let virtualMachine = self.virtualMachine {
			if force {
				virtualMachine.stopFromUI()
			} else {
				virtualMachine.requestStopFromUI()
			}
		} else if self.status == .external {
			do {
				let result = try StopHandler.stopVM(name: self.name, force: force, runMode: .app)

				if result.stopped == false {
					MainActor.assumeIsolated {
						alertError(ServiceError(result.reason))
					}
				}
			} catch {
				MainActor.assumeIsolated {
					alertError(error)
				}
			}
		}
	}

	func suspendFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.suspendFromUI()
		}
	}

	func createTemplateFromUI(name: String) -> CreateTemplateReply {
		do {
			return try TemplateHandler.createTemplate(on: Utilities.group.next(), sourceName: self.virtualMachine!.location.name, templateName: name, runMode: .app)
		} catch {
			guard let error = error as? ServiceError else {
				return .init(name: name, created: false, reason: error.localizedDescription)
			}

			return .init(name: name, created: false, reason: error.description)
		}
	}

	func didChangedState(_ vm: VirtualMachine) {
		let virtualMachine = vm.virtualMachine

		guard let status = Status(rawValue: virtualMachine.state.rawValue) else {
			self.status = .none
			return
		}

		self.canStart = virtualMachine.canStart
		self.canStop = virtualMachine.canStop
		self.canPause = virtualMachine.canPause
		self.canResume = virtualMachine.canResume
		self.canRequestStop = virtualMachine.canRequestStop
		self.suspendable = suspendable
		self.agent = vm.config.agent ? .installed : .none
		self.status = status
	}

	func fileDidChanged(event: FileChangeEvent) {
		guard let location = self.location, self.virtualMachine == nil else {
			return
		}

		let check: (URL) -> Void = { file in
			if file == location.pidFile {
				if file.isPIDRunning("caked") {
					self.status = .external

					self.canStart = false
					self.canStop = true
					self.canPause = true
					self.canResume = false
					self.canRequestStop = true
					self.suspendable = self.virtualMachineConfig.suspendable
					
					self.retrieveVNCURL()
				} else {
					self.status = .stopped

					self.canStart = true
					self.canStop = false
					self.canPause = false
					self.canResume = false
					self.canRequestStop = false
					self.suspendable = false
					self.vncStatus = .disconnected
					
					self.connection?.disconnect()
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

extension VirtualMachineDocument: VNCLogger {
	var isDebugLoggingEnabled: Bool {
		get {
			Logger.LoggingLevel() == .debug
		}

		set(newValue) {
			if newValue {
				Logger.setLevel(.debug)
			}
		}
	}
	
	func logDebug(_ message: String) {
		self.logger.debug(message)
	}
	
	func logInfo(_ message: String) {
		self.logger.info(message)
	}
	
	func logWarning(_ message: String) {
		self.logger.warn(message)
	}
	
	func logError(_ message: String) {
		self.logger.error(message)
	}
}

extension VirtualMachineDocument: VNCConnectionDelegate {
	func retrieveVNCURL() {
		Task {
			let url = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).vncURL()
			
			self.logger.info("Found VNC URL: \(String(describing: url))")

			DispatchQueue.main.async {
				self.vncURL = url
			}
		}
	}

	func tryVNCConnect() {
		if connection != nil {
			return
		}

		if let vncURL = self.vncURL {
			// Create settings
			let settings = VNCConnection.Settings(isDebugLoggingEnabled: true,
												  hostname: vncURL.host()!,
												  port: UInt16(vncURL.port ?? 5900),
												  isShared: true,
												  isScalingEnabled: true,
												  useDisplayLink: true,
												  inputMode: .forwardAllKeyboardShortcutsAndHotKeys,
												  isClipboardRedirectionEnabled: true,
												  colorDepth: .depth24Bit,
												  frameEncodings: .default)

			let connection = VNCConnection(settings: settings, logger: self)

			self.connection = connection
			self.vncStatus = .connecting
			
			connection.delegate = self
			connection.connect()
		}
	}

	func connection(_ connection: VNCConnection, stateDidChange connectionState: VNCConnection.ConnectionState) {
		self.logger.info("Connection state changed to \(connectionState.status)")

		DispatchQueue.main.async {
			var newStatus = VncStatus(vncStatus: connectionState.status)

			if connectionState.status == .connected {
				self.connection = connection

				if connection.framebuffer != nil {
					newStatus = .ready
				}
			} else if connectionState.status == .disconnected {
				self.connection = nil
			}
			
			self.vncStatus = newStatus
		}
	}
	
	func connection(_ connection: VNCConnection, credentialFor authenticationType: VNCAuthenticationType, completion: @escaping ((any VNCCredential)?) -> Void) {
		if let vncURL = self.vncURL {
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
	
	func connection(_ connection: VNCConnection, didCreateFramebuffer framebuffer: VNCFramebuffer) {
		DispatchQueue.main.async {
			self.logger.info("vnc ready")
			self.vncStatus = .ready
		}
	}
	
	func connection(_ connection: VNCConnection, didResizeFramebuffer framebuffer: VNCFramebuffer) {
	}
	
	func connection(_ connection: VNCConnection, didUpdateFramebuffer framebuffer: VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
		if let framebufferView = self.framebufferView {
			framebufferView.connection(connection, didUpdateFramebuffer: framebuffer, x: x, y: y, width: width, height: height)
		}
	}
	
	func connection(_ connection: VNCConnection, didUpdateCursor cursor: VNCCursor) {
		if let framebufferView = self.framebufferView {
			framebufferView.connection(connection, didUpdateCursor: cursor)
		}
	}
	
}

extension VirtualMachineDocument {
	func sendTerminalSize(rows: Int, cols: Int) {
		if let stream = self.stream {
			stream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
		}
	}

	func sendDatas(data: ArraySlice<UInt8>) {
		if let stream = self.stream {
			data.withUnsafeBytes { ptr in
				let message = CakeAgent.ExecuteRequest.with {
					$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
				}

				try? stream.sendMessage(message).wait()
			}
		}
	}

	func closeShell(_ completionHandler: (() -> Void)? = nil) {
		if self.stream == nil {
			return
		}

		self.client.close().whenComplete { _ in
			DispatchQueue.main.async {
				completionHandler?()
			}
		}
		self.client = nil
		self.stream = nil
	}

	func startShell(rows: Int, cols: Int, handler: @escaping (Cakeagent_CakeAgent.ExecuteResponse) -> Void) throws {
		self.shellHandlerResponse = handler

		guard self.stream == nil else {
			return
		}

		if self.client == nil {
			self.client = try Utilities.createCakeAgentClient(on: Utilities.group.next(), runMode: .app, name: name)
		}

		self.stream = client.execute(callOptions: CallOptions(timeLimit: .none)) { response in
			self.shellHandlerResponse(response)
		}

		stream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
		stream.sendShell()
	}
}

extension NSNotification {
	static let NewVirtualMachine = NSNotification.Name("NewVirtualMachine")
	static let OpenVirtualMachine = NSNotification.Name("OpenVirtualMachine")
	static let StartVirtualMachine = NSNotification.Name("StartVirtualMachine")
	static let DeleteVirtualMachine = NSNotification.Name("DeleteVirtualMachine")
	static let CreatedVirtualMachine = NSNotification.Name("CreatedVirtualMachine")
	static let FailCreateVirtualMachine = NSNotification.Name("FailCreateVirtualMachine")
	static let ProgressCreateVirtualMachine = NSNotification.Name("ProgressCreateVirtualMachine")
	static let ProgressMessageCreateVirtualMachine = NSNotification.Name("ProgressMessageCreateVirtualMachine")
}
