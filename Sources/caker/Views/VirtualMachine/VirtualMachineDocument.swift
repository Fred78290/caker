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

extension VNCConnection.Status: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
			case .connected:
			return "connected"
		case .connecting:
			return "connecting"
		case .disconnected:
			return "Disconnected"
		case .disconnecting:
			return "disconnecting"
		}
	}
}

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
	}

	private var client: CakeAgentClient!
	private var stream: CakeAgentExecuteStream!
	private var shellHandlerResponse: ShellHandlerResponse!
	private var monitor: FileMonitor?
	private var inited = false
	private let logger = Logger("VirtualMachineDocument")

	var vncView: NSVNCView?
	var virtualMachine: VirtualMachine!
	var location: VMLocation?
	var name: String = ""
	var description: String {
		name
	}

	@Published var virtualMachineConfig: VirtualMachineConfig = .init()
	@Published var externalRunning: Bool = false
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
	@Published var documentSize: CGSize = .zero
	@Published var documentWidth: CGFloat = .zero
	@Published var documentHeight: CGFloat = .zero

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
				func loadVM() throws {
					if loadVirtualMachine(from: location.rootURL) == false {
						throw ServiceError("Unable to load virtual machine")
					} else {
						AppState.shared.replaceVirtualMachineDocument(location.rootURL, with: self)
					}
				}

				if Thread.isMainThread {
					try loadVM()
				} else {
					try DispatchQueue.main.sync {
						try loadVM()
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
		self.vncView = nil
		self.vncURL = nil
		self.vncStatus = .disconnected

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

	@MainActor
	func setStateAsStopped(_ status: Status = .stopped) {
		self.canStart = true
		self.canStop = false
		self.canPause = false
		self.canResume = false
		self.canRequestStop = false
		self.suspendable = false
		self.vncURL = nil
		self.vncStatus = .disconnected
		self.status = status
		self.externalRunning = false
		self.connection?.disconnect()
	}

	@MainActor
	func setStateAsRunning(suspendable: Bool, vncURL: URL?) {
		self.canStart = false
		self.canStop = true
		self.canPause = true
		self.canResume = false
		self.canRequestStop = true
		self.suspendable = suspendable
		self.vncURL = vncURL
		self.status = .running
	}

	private func setDocumentSize(_ size: CGSize) {
		self.logger.info("Setting document size to \(size)")
		self.documentSize = size
		self.documentWidth = size.width
		self.documentHeight = size.height
		self.virtualMachineConfig.display.width = Int(size.width)
		self.virtualMachineConfig.display.height = Int(size.height)
	}

	func loadVirtualMachine(from location: VMLocation) -> URL? {
		do {
			let config = try location.config()

			self.virtualMachineConfig = VirtualMachineConfig(vmname: location.name, config: config)
			self.location = location
			self.agent = config.agent ? .installed : .none
			self.name = location.name
			self.externalRunning = location.pidFile.isPIDRunning(Home.cakedCommandName)
			self.setDocumentSize(self.virtualMachineConfig.display.size)

			if externalRunning {
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
		guard self.status == .stopped else {
			return
		}

		if AppState.shared.launchVMExternally {
			if let location {
				do {
					let config = try location.config()
					let vncPassword = config.vncPassword
					let vncPort = try Utilities.findFreePort()
					let vncURL = URL(string: "vnc://:\(vncPassword)@localhost:\(vncPort)")

					self.externalRunning = true
					self.status = .starting
					self.vncURL = vncURL

					Task {
						do {
							let promise = Utilities.group.next().makePromise(of: String.self)
							let suspendable = config.suspendable

							promise.futureResult.whenSuccess { _ in
								self.logger.info("VM \(self.name) terminated")

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
							
							let extras = [
								"--vncPassword=\(vncPassword)",
								"--vncPort=\(vncPort)",
								"--screenSize=\(self.documentSize.width)x\(self.documentSize.height)"
							]
							let runningIP = try StartHandler.internalStartVM(location: location, config: config, waitIPTimeout: 120, startMode: .service, runMode: .user, promise: promise, extras: extras)
							let url = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).vncURL()

							self.logger.info("VM started on \(runningIP)")
							self.logger.info("Found VNC URL: \(String(describing: url))")

							DispatchQueue.main.async {
								self.setStateAsRunning(suspendable: suspendable, vncURL: url)
							}
						} catch {
							self.status = .stopped
							
							DispatchQueue.main.async {
								alertError(error)
							}
						}
					}
				} catch {
					DispatchQueue.main.async {
						alertError(error)
					}
				}
			}
		} else {
			self.externalRunning = false

			if let virtualMachine = self.virtualMachine {
				virtualMachine.startFromUI()
			}
		}
	}

	func restartFromUI() {
		guard self.status == .running else {
			return
		}

		if self.externalRunning {
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
					let result = try StopHandler.stopVM(name: self.name, force: force, runMode: .app)
					
					if result.stopped == false {
						await alertError(ServiceError(result.reason))
					} else {
						await self.setStateAsStopped()
					}
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
					let result = try SuspendHandler.suspendVM(name: self.name, runMode: .app)
					
					if result.suspended == false {
						await alertError(ServiceError(result.reason))
					} else {
						await self.setStateAsStopped(.paused)
					}
				} catch {
					await alertError(error)
				}
			}
		} else if let virtualMachine = self.virtualMachine {
			virtualMachine.suspendFromUI()
		}
	}

	func createTemplateFromUI(name: String) -> CreateTemplateReply {
		guard self.status == .running else {
			return .init(name: name, created: false, reason: "VM is running")
		}

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
				DispatchQueue.main.async {
					if file.isPIDRunning(Home.cakedCommandName) {
						self.retrieveVNCURL()
					} else {
						self.setStateAsStopped()
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

extension VirtualMachineDocument: VNCConnectionDelegate {
	func setScreenSize(_ size: CGSize) {
		if size.width == 0 && size.height == 0 {
			return
		}

		self.setDocumentSize(size)

		if self.externalRunning && (self.vncStatus == .connected || self.vncStatus == .ready) {
			self.logger.debug("resizeScreen: \(size)")

			Task {
				try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).setScreenSize(width: Int(size.width), height: Int(size.height))
			}
		}
	}

	func retrieveVNCURLAsync() {
		Task {
			let url = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).vncURL()

			self.logger.info("Found VNC URL: \(String(describing: url))")
			
			DispatchQueue.main.async {
				self.vncURL = url
			}
		}
	}

	func retrieveVNCURL() {
		MainActor.assumeIsolated {
			self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: nil)
			self.retrieveVNCURLAsync()
		}
	}

	func tryVNCConnect() {
		if connection != nil {
			return
		}

		if let vncURL = self.vncURL {
			// Create settings
			let settings = VNCConnection.Settings(isDebugLoggingEnabled: Logger.LoggingLevel() == .debug,
												  hostname: vncURL.host()!,
												  port: UInt16(vncURL.port ?? 5900),
												  isShared: true,
												  isScalingEnabled: true,
												  useDisplayLink: true,
												  inputMode: .forwardAllKeyboardShortcutsAndHotKeys,
												  isClipboardRedirectionEnabled: true,
												  colorDepth: .depth24Bit,
												  frameEncodings: .default)

			let connection = VNCConnection(settings: settings, logger: VNCConnectionLogger())

			self.connection = connection
			self.vncStatus = .connecting
			
			self.logger.info("Connect VNC \(vncURL)...")

			connection.delegate = self
			connection.connect()
		}
	}

	func connection(_ connection: VNCConnection, stateDidChange connectionState: VNCConnection.ConnectionState) {
		self.logger.debug("Connection state changed to \(connectionState.status.description)")

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
				self.connection = nil

				if self.status == .starting || self.status == .running {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
						self.tryVNCConnect()
					}
					newStatus = .connecting
				} else {
					self.vncView = nil
				}
			}
			
			self.vncStatus = newStatus

			if newStatus == .ready, let vncView = self.vncView {
				let size = vncView.frame.size
				self.setScreenSize(size)
			}
		}
	}
	
	func connection(_ connection: VNCConnection, credentialFor authenticationType: VNCAuthenticationType, completion: @escaping ((any VNCCredential)?) -> Void) {
		self.logger.debug("Connection need credential")

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
		self.logger.info("Connection create framebuffer size: \(framebuffer.cgSize)")

		DispatchQueue.main.async {
			self.logger.info("vnc ready")
			self.vncStatus = .ready
		}
	}
	
	func connection(_ connection: VNCConnection, didResizeFramebuffer framebuffer: VNCFramebuffer) {
		self.logger.info("VNC framebuffer size changed: \(framebuffer.cgSize)")

		self.vncView?.connection(connection, didResizeFramebuffer: framebuffer)

		DispatchQueue.main.async {
			self.setDocumentSize(framebuffer.cgSize)

			NotificationCenter.default.post(name: NSNotification.VNCFramebufferSizeChanged, object: framebuffer.cgSize)
		}
	}
	
	func connection(_ connection: VNCConnection, didUpdateFramebuffer framebuffer: VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
		vncView?.connection(connection, didUpdateFramebuffer: framebuffer, x: x, y: y, width: width, height: height)
	}

	func connection(_ connection: VNCConnection, didUpdateCursor cursor: VNCCursor) {
		vncView?.connection(connection, didUpdateCursor: cursor)
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
	static let VNCFramebufferSizeChanged = NSNotification.Name("VNCFramebufferSizeChanged")
}
