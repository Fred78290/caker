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
//
//  VirtualMachineDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import SwiftUI
import UniformTypeIdentifiers

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

struct ScreenshotLoader: Hashable, Identifiable {
	private let screenshotURL: URL
	private let date: Date = .init()

	var id: URL {
		self.screenshotURL
	}

	static func == (lhs: ScreenshotLoader, rhs: ScreenshotLoader) -> Bool {
		return lhs.screenshotURL == rhs.screenshotURL
	}

	init(screenshotURL: URL) {
		self.screenshotURL = screenshotURL
	}

	var nsImage: NSImage? {
		guard let exist = try? screenshotURL.exists(), exist else {
			return nil
		}

		return NSImage(contentsOfFile: screenshotURL.path)
	}

	@ViewBuilder
	var image: some View {
		GeometryReader { geom in
			if let image = self.nsImage {
				Rectangle()
					.fill(.black)
					.frame(size: geom.size)
					.overlay {
						Image(nsImage: image)
							.resizable()
							.blur(radius: 8)
							.aspectRatio(contentMode: .fit)
							.scaledToFit()
					}
					.clipped()
			} else {
				Rectangle()
					.fill(.black)
					.frame(size: geom.size)
			}
		}
	}
}

// MARK: - VirtualMachineDocument
final class VirtualMachineDocument: @unchecked Sendable, ObservableObject, Equatable, Identifiable {
	typealias ShellHandlerResponse = (Cakeagent_CakeAgent.ExecuteResponse) -> Void
	
	static func == (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		lhs.virtualMachine == rhs.virtualMachine
	}
	
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
	
	enum Status: Int, CustomStringConvertible {
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
	}
	
	private var _infosClient: CakeAgentHelper!
	private var shellClient: CakeAgentClient!
	private var stream: CakeAgentExecuteStream!
	private var shellHandlerResponse: ShellHandlerResponse!
	private var monitor: FileMonitor?
	private var inited = false
	private let logger = Logger("VirtualMachineDocument")
	private var agentMonitoring: Task<Void, Never>?

	let id = UUID().uuidString
	
	var vncView: NSVNCView?
	var virtualMachine: VirtualMachine!
	var location: VMLocation!
	var name: String = ""
	var description: String {
		name
	}
	
	var isLaunchVMExternally: Bool {
		guard let launchVMExternally = self.launchVMExternally else {
			return AppState.shared.launchVMExternally
		}
		
		return launchVMExternally
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
	@Published var documentSize: ViewSize = .zero
	@Published var launchVMExternally: Bool? = nil
	@Published var vmInfos: VMInformations? = nil
	@Published var agentCondition: (title: String, needUpdate: Bool, disabled: Bool) = ("Install agent", false, true)

	private var screenshot: ScreenshotLoader!
	
	var lastScreenshot: NSImage? {
		self.screenshot?.nsImage
	}
	
	var osImage: some View {
		var name = "linux"
		
		if self.virtualMachineConfig.os == .darwin {
			name = "mac"
		} else if let config = try? self.location.config(), let osName = config.osName {
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
		self.stopAgentMonitoring()

		if let monitor = self.monitor {
			monitor.stop()
		}
		
		if let client = self.shellClient {
			_ = client.close()
		}
	}
	
	init() {
		self.virtualMachine = nil
		self.virtualMachineConfig = VirtualMachineConfig()
	}
	
	init(location: VMLocation) throws {
		let config = try VirtualMachineConfig(location: location)
		let monitor = try FileMonitor(directory: location.rootURL, delegate: self)
		
		self.name = location.name
		self.location = location
		self.virtualMachineConfig = config
		self.screenshot = .init(screenshotURL: location.screenshotURL)
		self.agent = config.agent ? config.firstLaunch ? AgentStatus.installing : AgentStatus.installed : AgentStatus.none
		self.externalRunning = location.pidFile.isPIDRunning(Home.cakedCommandName)
		self.monitor = monitor
		
		if self.externalRunning {
			self.documentSize = self.getVncScreenSize()
		} else {
			self.documentSize = ViewSize(size: config.display.size)
		}
		
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
	
	init(name: String, config: VirtualMachineConfig) {
		self.name = name
		self.virtualMachineConfig = config
	}
}

// MARK: - Core
extension VirtualMachineDocument {
	func disconnect() {
#if DEBUG
		self.logger.debug("Disconnecting \(self.name)")
#endif

		self.vncURL = nil
		self.vncStatus = .disconnected
		
		if self.externalRunning == false {
			self.status = .stopped
		}
		
		if let connection = self.connection {
			self.connection = nil
			connection.disconnect()
		}
		
		self.closeShell()
	}

	func close() {
#if DEBUG
		self.logger.debug("Closing \(self.name)")
#endif
		
		self.virtualMachine = nil
		self.inited = false
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
		
		self.closeShell()
	}
	
	@MainActor
	func setStateAsStopped(_ status: Status = .stopped, _line: UInt = #line, _file: String = #file) {
#if DEBUG
		self.logger.debug("setStateAsStopped to \(status) at \(_file):\(_line)")
#endif
		
		// Stop agent monitoring when VM is stopped
		self.stopAgentMonitoring()

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
		self.agentCondition = ("Install agent", false, true)
		self.vmInfos = nil

		if let connection = self.connection {
			self.connection = nil
			connection.disconnect()
		}
	}
	
	@MainActor
	func setStateAsRunning(suspendable: Bool, vncURL: URL?, _line: UInt = #line, _file: String = #file) {
#if DEBUG
		self.logger.debug("setStateAsRunning, suspendable: \(suspendable) at \(_file):\(_line)")
#endif

		self.canStart = false
		self.canStop = true
		self.canPause = true
		self.canResume = false
		self.canRequestStop = true
		self.suspendable = suspendable
		self.vncURL = vncURL
		self.status = .running
		self.agentCondition = ("Install agent", false, self.agent != .none)

		// Start agent monitoring when VM is running
		if self.agent == .installed {
			self.startAgentMonitoring()
		}
	}
	
	func setState(suspendable: Bool, status: Status, vncURL: URL? = nil, _line: UInt = #line, _file: String = #file) {
#if DEBUG
		self.logger.debug("setState to \(status) at \(_file):\(_line)")
#endif
		
		self.status = status
		self.canStart = status == .stopped || status == .paused
		self.canStop = status == .running
		self.canPause = status == .running
		self.canResume = status == .paused
		self.canRequestStop = status == .running
		self.vncURL = vncURL
		self.suspendable = suspendable
	}
	
	func setDocumentSize(_ size: ViewSize, _line: UInt = #line, _file: String = #file) {
		if self.documentSize != size {
#if DEBUG
			self.logger.debug("Setting document size to \(size.description) at \(_file):\(_line)")
#endif
			
			self.documentSize = size
		}
	}
	
	private func createVirtualMachine() throws {
		let config = try! location.config()
		let virtualMachine = try VirtualMachine(location: location, config: config, screenSize: config.display.cgSize, runMode: .app)
		
		self.virtualMachine = virtualMachine
		self.vncURL = nil
		self.didChangedState(virtualMachine)
		
		virtualMachine.delegate = self
	}
	
	private func loadVirtualMachine(from location: VMLocation) -> URL? {
#if DEBUG
		self.logger.debug("Load VM from: \(location.rootURL)")
#endif
		
		do {
			self.virtualMachineConfig = try VirtualMachineConfig(location: location)
			self.location = location
			self.agent = self.virtualMachineConfig.agent ? (self.virtualMachineConfig.firstLaunch ? .installing : .installed) : .none
			self.name = location.name
			self.externalRunning = location.pidFile.isPIDRunning(Home.cakedCommandName)
			
			if self.isLaunchVMExternally && self.externalRunning {
				self.setDocumentSize(self.getVncScreenSize())
			} else {
				self.setDocumentSize(.init(size: self.virtualMachineConfig.display.size))
			}
			
			if externalRunning {
				retrieveVNCURL()
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
	
	func loadVirtualMachine() -> URL? {
		guard let virtualMachine = self.virtualMachine else {
			if let location = self.location {
				return self.loadVirtualMachine(from: location)
			}
			
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
}

// MARK: - UI Actions
extension VirtualMachineDocument {
	func startFromUI() {
		guard self.status == .stopped else {
			return
		}

		if self.isLaunchVMExternally {
			if let location {
				do {
					let config = try location.config()
					let vncPassword = config.vncPassword
					let vncPort = try Utilities.findFreePort()
					let vncURL = URL(string: "vnc://:\(vncPassword)@localhost:\(vncPort)")

					self.externalRunning = true

					self.setState(suspendable: config.suspendable, status: .starting, vncURL: vncURL)

					Task {
						do {
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

							let extras = [
								"--vnc-password=\(vncPassword)",
								"--vnc-port=\(vncPort)",
								"--screen-size=\(Int(self.documentSize.width))x\(Int(self.documentSize.height))",
							]
							let runningIP = try StartHandler.internalStartVM(location: location, config: config, waitIPTimeout: 120, startMode: .service, runMode: .user, promise: promise, extras: extras)
							let url = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).vncURL()

							#if DEBUG
								self.logger.debug("VM started on \(runningIP)")
								self.logger.debug("Found VNC URL: \(String(describing: url))")
							#endif

							DispatchQueue.main.async {
								self.setStateAsRunning(suspendable: suspendable, vncURL: url)
							}
						} catch {
							if location.pidFile.isPIDRunning(Home.cakedCommandName) == false {
								DispatchQueue.main.async {
									self.setStateAsStopped()
									alertError(error)
								}
							} else if self.vncURL == nil {
								let url = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).vncURL()
								DispatchQueue.main.async {
									self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: url)
								}
							} else {
								DispatchQueue.main.async {
									self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: self.vncURL)
								}
							}
						}
					}
				} catch {
					DispatchQueue.main.async {
						self.setStateAsStopped()
						alertError(error)
					}
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
				self.setState(suspendable: virtualMachineConfig.suspendable, status: .starting)

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

		return TemplateHandler.createTemplate(on: Utilities.group.next(), sourceName: self.virtualMachine!.location.name, templateName: name, runMode: .app)
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
				if let screenshot = self.screenshot.nsImage {
					DispatchQueue.main.async {
						NotificationCenter.default.post(name: VirtualMachineDocument.NewScreenshot, object: screenshot, userInfo: ["document": self])
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
				try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).setScreenSize(width: Int(screenSize.width), height: Int(screenSize.height))
			}
		}
	}

	func getVncScreenSize() -> ViewSize {
		var screenSize = ViewSize(width: CGFloat(self.virtualMachineConfig.display.width), height: CGFloat(self.virtualMachineConfig.display.height))

		if let size = try? createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).getScreenSize() {
			screenSize = ViewSize(width: CGFloat(size.0), height: CGFloat(size.1))
		}

		#if DEBUG
			self.logger.debug("getVncScreenSize: \(screenSize.description)")
		#endif

		return screenSize
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

	func retrieveVNCURLAsync() {
		Task {
			do {
				if let url = try createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).vncURL() {
					self.logger.info("Found VNC URL: \(url)")

					await self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: url)
				} else {
					await self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: nil)
				}
			} catch {
				self.logger.error("Failed to retrieve VNC URL: \(error)")
			}
		}
	}

	func retrieveVNCURL() {
		MainActor.assumeIsolated {
			do {
				if let url = try createVMRunServiceClient(VMRunHandler.serviceMode, location: self.location!, runMode: .app).vncURL() {
					self.logger.info("Found VNC URL: \(url)")

					self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: url)
					self.tryVNCConnect()
				} else {
					self.setStateAsRunning(suspendable: self.virtualMachineConfig.suspendable, vncURL: nil)
				}
			} catch {
				self.logger.error("Failed to retrieve VNC URL: \(error)")
			}
		}
	}

	func tryVNCConnect() {
		if connection != nil {
			return
		}

		if let vncURL = self.vncURL {
			// Create settings
			let vncPort = vncURL.port ?? 5900
			let vncHost = vncURL.host()!
			#if DEBUG
				let isDebugLoggingEnabled = AppState.shared.debugVNCMessageEnabled
			#else
				let isDebugLoggingEnabled = Logger.LoggingLevel() == .debug
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
			let connection = RoyalVNCKit.VNCConnection(settings: settings, logger: VNCConnectionLogger())

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

	func connection(_ connection: RoyalVNCKit.VNCConnection, didCreateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		if self.vncStatus != .ready {
			let size = ViewSize(size: framebuffer.cgSize)

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
				self.setDocumentSize(.init(size: framebuffer.cgSize))

				NotificationCenter.default.post(name: VirtualMachineDocument.VNCFramebufferSizeChanged, object: framebuffer.cgSize, userInfo: ["document": self.name])
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

// MARK: - Shell
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
		func closeClient() {
			if let shellClient {
				self.shellClient = nil

				shellClient.close().whenComplete { _ in
					DispatchQueue.main.async {
						completionHandler?()
					}
				}
			}
		}

		guard let stream else {
			closeClient()
			return
		}

		self.stream = nil

		let promise = stream.eventLoop.makePromise(of: Void.self)

		promise.futureResult.whenComplete { _ in
			closeClient()
		}

		stream.cancel(promise: promise)
	}

	@MainActor
	func heartBeatShell(rows: Int, cols: Int) {
		do {
			let helper = try self.createCakeAgentHelper()
				
			_ = try helper.info()

			DispatchQueue.main.async {
				self.stream = self.shellClient.execute(callOptions: CallOptions(timeLimit: .none)) { response in
					self.shellHandlerResponse(response)
				}

				self.stream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
				self.stream.sendShell()
			}
		} catch {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				self.heartBeatShell(rows: rows, cols: cols)
			}
		}
	}

	func startShell(rows: Int, cols: Int, handler: @escaping (Cakeagent_CakeAgent.ExecuteResponse) -> Void) throws {
		self.shellHandlerResponse = handler

		guard self.stream == nil else {
			return
		}

		if self.shellClient == nil {
			self.shellClient = try Utilities.createCakeAgentClient(on: Utilities.group.next(), runMode: .app, name: name)
		}

		Task { [weak self] in
			await self?.heartBeatShell(rows: rows, cols: cols)
		}
	}
}

// MARK: - Agent Monitoring
extension VirtualMachineDocument {
	private func createCakeAgentHelper(connectionTimeout: Int64 = 1) throws -> CakeAgentHelper {
		// Create a short-lived client for the health check
		let eventLoop = Utilities.group.next()
		let client = try Utilities.createCakeAgentClient(
			on: eventLoop,
			runMode: .app,
			name: self.name,
			connectionTimeout: connectionTimeout,
			retries: .upTo(1)
		)

		return CakeAgentHelper(on: eventLoop, client: client)
	}

	func installAgent(updateAgent: Bool, _ done: @escaping () -> Void) {
		if let virtualMachine = self.virtualMachine {
			self.agent = .installing
			
			Task {
				var agent: AgentStatus = .installing
				
				do {
					agent = try await virtualMachine.installAgent(updateAgent: updateAgent, timeout: 2, runMode: .app) ? .installed : .none
					
					if agent == .none {
						throw ServiceError("Failed to install agent.")
					}
				} catch {
					await alertError(error)
					
					agent = .none
				}
				
				self.agent = agent

				DispatchQueue.main.async {
					done()
				}
			}
		}
	}

	@MainActor
	private func agentMonitoringSuccess(infos: InfoReply) {
		#if DEBUG
			self.logger.debug("Agent monitoring: VM \(self.name) agent is responding")
		#endif

		self.vmInfos = .init(from: infos)

		if infos.agentVersion.isEmpty == false && infos.agentVersion.contains(CAKEAGENT_SNAPSHOT) == false {
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
		guard agentMonitoring == nil else {
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
		guard let document = notification.userInfo?["document"] as? VirtualMachineDocument, document.id == self.id else {
			return nil
		}

		return notification.object as? T
	}
}

