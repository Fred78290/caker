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

	@ViewBuilder
	var image: some View {
		GeometryReader { geom in
			if let exist = try? screenshotURL.exists(), exist == false {
				Rectangle()
					.fill(.black)
					.frame(size: geom.size)
			} else if let image = NSImage(contentsOfFile: screenshotURL.path) {
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
	@Published var screenshot: ScreenshotLoader!
	@Published var vmInfos: VMInformations!
	@Published var firstIP: String!

	// Agent monitoring
	private var agentMonitorTimer: Timer!
	private var isMonitoringAgent: Bool = false
	private var isWaitingForAgent: Bool = false

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
		stopAgentMonitoring()

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

	func disconnect() {
		self.logger.debug("Disconnecting \(self.name)")

		stopAgentMonitoring()

		self.vncURL = nil
		self.vncStatus = .disconnected

		if self.externalRunning == false {
			self.status = .stopped
		}

		if let connection = self.connection {
			connection.disconnect()
		}

		self.closeShell()
	}

	func close() {
		self.logger.debug("Closing \(self.name)")

		stopAgentMonitoring()

		self.virtualMachine = nil
		self.inited = false
		self.vncView = nil
		self.vncURL = nil
		self.vncStatus = .disconnected

		if self.externalRunning == false {
			self.status = .stopped
		}

		if let connection = self.connection {
			connection.disconnect()
		}

		self.closeShell()
	}

	@MainActor
	func setStateAsStopped(_ status: Status = .stopped, _line: UInt = #line, _file: String = #file) {
		self.logger.debug("setStateAsStopped to \(status) at \(_file):\(_line)")

		// Stop agent monitoring when VM is stopped
		stopAgentMonitoring()

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
	func setStateAsRunning(suspendable: Bool, vncURL: URL?, _line: UInt = #line, _file: String = #file) {
		self.logger.debug("setStateAsRunning, suspendable: \(suspendable) at \(_file):\(_line)")
		self.canStart = false
		self.canStop = true
		self.canPause = true
		self.canResume = false
		self.canRequestStop = true
		self.suspendable = suspendable
		self.vncURL = vncURL
		self.status = .running

		// Start agent monitoring when VM is running
		if self.agent == .installed {
			startAgentMonitoring(interval: 1.0)
		}
	}

	func setState(suspendable: Bool, status: Status, vncURL: URL? = nil, _line: UInt = #line, _file: String = #file) {
		self.logger.debug("setState to \(status) at \(_file):\(_line)")

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
			self.logger.debug("Setting document size to \(size.description) at \(_file):\(_line)")

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
		self.logger.debug("Load VM from: \(location.rootURL)")

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
			} else if self.virtualMachine == nil {
				try createVirtualMachine()
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

				DispatchQueue.main.async {
					self.agent = agent

					// Start agent monitoring if VM is running and agent was successfully installed
					if agent == .installed && self.status == .running {
						self.startAgentMonitoring(interval: 1.0)
					}

					done()
				}
			}
		}
	}

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
								self.logger.debug("VM \(self.name) terminated")

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

							self.logger.debug("VM started on \(runningIP)")
							self.logger.debug("Found VNC URL: \(String(describing: url))")

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
						self.setState(suspendable: false, status: .stopped)
						alertError(error)
					}
				}
			}
		} else {
			self.externalRunning = false

			if self.virtualMachine == nil {
				try? createVirtualMachine()
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

		self.logger.debug("didChangedState: \(virtualMachine.state)")

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

	func didScreenshot(_ vm: CakedLib.VirtualMachine, data: NSImage) {
		try? vm.saveScreenshot()
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
				DispatchQueue.main.async {
					self.screenshot = ScreenshotLoader(screenshotURL: location.screenshotURL)
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

// MARK: - VNCConnectionDelegate
extension VirtualMachineDocument: VNCConnectionDelegate {
	func setVncScreenSize(_ screenSize: ViewSize) {
		if self.externalRunning && self.status == .running {
			self.logger.debug("setVncScreenSize: \(screenSize.description)")

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

		self.logger.debug("getVncScreenSize: \(screenSize.description)")

		return screenSize
	}

	func setScreenSize(_ size: ViewSize, _line: UInt = #line, _file: String = #file) {
		self.logger.debug("Setting screen size to \(size.description) at \(_file):\(_line)")

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
			let settings = RoyalVNCKit.VNCConnection.Settings(
				isDebugLoggingEnabled: false,  //Logger.LoggingLevel() == .debug,
				hostname: vncHost,
				port: UInt16(vncPort),
				isShared: true,
				isScalingEnabled: true,
				useDisplayLink: true,
				inputMode: .forwardAllKeyboardShortcutsAndHotKeys,
				isClipboardRedirectionEnabled: true,
				colorDepth: .depth24Bit,
				frameEncodings: .default)
			let connection = RoyalVNCKit.VNCConnection(settings: settings, logger: VNCConnectionLogger())

			self.connection = connection
			self.vncStatus = .connecting

			connection.delegate = self

			Task {
				if Utilities.waitPortReady(host: vncHost, port: vncPort) {
					connection.connect()
					self.logger.debug("Connected to: \(vncURL)...")
				}
			}
		}
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, stateDidChange connectionState: RoyalVNCKit.VNCConnection.ConnectionState) {
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

			if newStatus == .ready {
				self.setScreenSize(self.documentSize)
			}
		}
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, credentialFor authenticationType: VNCAuthenticationType, completion: @escaping ((any VNCCredential)?) -> Void) {
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

	func connection(_ connection: RoyalVNCKit.VNCConnection, didCreateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		if self.vncStatus != .ready {
			let size = ViewSize(size: framebuffer.cgSize)

			self.logger.debug("Connection create framebuffer size: \(size.description)")

			DispatchQueue.main.async {
				self.logger.debug("vnc ready")
				self.vncStatus = .ready
			}
		}
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, didResizeFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		self.logger.debug("VNC framebuffer size changed: \(framebuffer.cgSize)")

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
			_ = try self.infosClient().info()

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
	@MainActor
	private func infosClient() throws -> CakeAgentHelper {
		if _infosClient == nil {
			// Create a short-lived client for the health check
			let eventLoop = Utilities.group.next()
			let client = try Utilities.createCakeAgentClient(
				on: eventLoop,
				runMode: .app,
				name: self.name,
				connectionTimeout: 5,
				retries: .upTo(1)
			)

			self._infosClient = CakeAgentHelper(on: eventLoop, client: client)
		}

		return _infosClient
	}

	var agentCondition: (title: String, needUpdate: Bool, disabled: Bool) {
		let title = "Install agent"

		if self.status != .running {
			return (title, false, true)
		}

		if let agentVersion = self.vmInfos?.agentVersion {
			if agentVersion.isEmpty == false && agentVersion.contains(CAKEAGENT_SNAPSHOT) {
				return ("Update agent", true, false)
			}
		}

		return (title, false, self.agent != .none)
	}

	private func startAgentMonitoring(interval: TimeInterval) {
		guard !isMonitoringAgent, agent == .installed, status == .running else {
			return
		}

		self.logger.debug("Starting agent monitoring for VM: \(self.name)")
		isMonitoringAgent = true

		agentMonitorTimer?.invalidate()

		// Schedule periodic monitoring every seconds
		agentMonitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
			self?.monitorAgent()
		}
	}

	private func stopAgentMonitoring() {
		guard isMonitoringAgent else {
			return
		}

		self.logger.debug("Stopping agent monitoring for VM: \(self.name)")
		vmInfos = nil
		firstIP = nil
		isMonitoringAgent = false

		agentMonitorTimer?.invalidate()
		agentMonitorTimer = nil
	}

	private func monitorAgent() {
		guard self.location != nil else {
			return
		}

		guard isMonitoringAgent, agent == .installed, status == .running else {
			stopAgentMonitoring()
			return
		}

		Task { [weak self] in
			await self?.performAgentHealthCheck()
		}
	}

	private func performAgentHealthCheck() async {
		do {
			// Perform info request with short timeout
			let callOptions = CallOptions(timeLimit: .timeout(.seconds(10)))
			let infos = try await self.infosClient().info(callOptions: callOptions)

			self.logger.debug("Agent health check successful for VM: \(self.name)")

			DispatchQueue.main.async {
				self.handleAgentHealthCheckSuccess(info: infos)
			}
		} catch {
			self.logger.debug("Failed to create agent client for health check: \(error)")
			self.handleAgentHealthCheckFailure(error: error)
		}
	}

	private func handleAgentHealthCheckSuccess(info: InfoReply) {
		// Agent is responding - optionally update VM info if needed
		// For example, you could update IP addresses or system info
		self.logger.debug("Agent monitoring: VM \(self.name) is healthy, uptime: \(info.uptime ?? 0)s")

		self.vmInfos = .init(from: info)

		// Update IP addresses if they changed
		if let firstIP = info.ipaddresses.first, firstIP != self.firstIP {
			self.firstIP = firstIP

			self.logger.info("VM \(self.name) current IP address: \(firstIP)")
		}
		
		if self.isWaitingForAgent {
			self.isWaitingForAgent = false
			self.stopAgentMonitoring()
			agentMonitorTimer?.invalidate()
			// Schedule periodic monitoring every seconds
			agentMonitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
				self?.monitorAgent()
			}
		}
	}

	private func handleAgentHealthCheckFailure(error: Error) {
		if let grpcError = error as? GRPCStatus {
			switch grpcError.code {
			case .unavailable, .cancelled:
				// These could be temporary - continue monitoring
				if self.isWaitingForAgent == false {
					self.isWaitingForAgent = true
					agentMonitorTimer?.invalidate()
					// Schedule periodic monitoring every seconds
					agentMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
						self?.monitorAgent()
					}
				}
				break
			case .deadlineExceeded:
				// Timeout - VM might be under heavy load
				self.logger.info("Agent monitoring: VM \(self.name) agent timeout - VM might be busy")
			default:
				// Other errors might indicate serious issues
				self.logger.error("Agent monitoring: VM \(self.name) agent error: \(grpcError)")
			}
		} else {
			// Agent is not responding - could indicate VM issues
			self.logger.debug("Agent monitoring: VM \(self.name) agent not responding: \(error)")  // Check if it's a permanent failure (connection refused, etc.)
		}

		if let infosClient = self._infosClient {
			_ = infosClient.close()
			self._infosClient = nil
		}
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
	static let VNCFramebufferSizeChanged = NSNotification.Name("VNCFramebufferSizeChanged")

	func issuedNotificationFromDocument<T>(_ notification: Notification) -> T? {
		guard let document = notification.userInfo?["document"] as? VirtualMachineDocument, document.id == self.id else {
			return nil
		}

		return notification.object as? T
	}
}
