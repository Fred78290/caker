//
//  HostVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/05/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

func viewLog(_ text: String) -> some View {
	Logger("View").debug(text)

	return EmptyView()
}

extension View {
	func log(_ label: String = "View", text: String) -> some View {
		Logger(label).debug(text)
		return self
	}

	func frame(_ label: String = "View", minSize: CGSize, idealSize: CGSize) -> some View {
		Logger(label).debug("frame(minSize: \(minSize), idealSize: \(idealSize))")
		
		return frame(minWidth: minSize.width, idealWidth: idealSize.width, maxWidth: .infinity, minHeight: minSize.height, idealHeight: idealSize.height, maxHeight: .infinity)
	}
	
	func frame(_ label: String = "View", minSize: CGSize) -> some View {
		Logger(label).debug("frame(minSize: \(minSize)")

		return frame(minWidth: minSize.width, maxWidth: .infinity, minHeight: minSize.height, maxHeight: .infinity)
	}
}

class CustomWindowDelegate: NSObject, NSWindowDelegate {
	override init() {
		super.init()
	}

	func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
		return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
	}
}

struct HostVirtualMachineView: View {
	enum ExternalModeView: Int, Hashable {
		case none
		case terminal
		case vnc
	}

	@AppStorage("VMLaunchMode") var launchVMExternally = false
	@AppStorage("NoShutdownVMOnClose") var isNoShutdownVMOnClose = false

	@Environment(\.appearsActive) var appearsActive
	@Environment(\.scenePhase) var scenePhase
	@Environment(\.openWindow) private var openWindow
	@Environment(\.dismiss) var dismiss

	@Binding var appState: AppState
	@StateObject var document: VirtualMachineDocument

	@State var window: NSWindow? = nil
	@State var displaySettings: Bool = false
	@State var createTemplate: Bool = false
	@State var virtualMachineConfig: VirtualMachineConfig = VirtualMachineConfig()
	@State var displayFontPanel: Bool = false
	@State var terminalColor: Color = .blue
	@State var externalModeView: ExternalModeView
	@State var documentSize: ViewSize
	@State var liveResizeWindow: Bool = false
	@State var needsResize: Bool = false
	@State var launchExternally: Bool = false

	private let logger = Logger("HostVirtualMachineView")
	private let delegate: CustomWindowDelegate = CustomWindowDelegate()
	private let minSize: CGSize
	private let id: String = UUID().uuidString

	init(appState: Binding<AppState>, document: VirtualMachineDocument) {
		self._appState = appState
		self._document = StateObject(wrappedValue: document)
		self.minSize = CGSize(width: 800, height: 600)
		self.launchExternally = document.isLaunchVMExternally
		self.externalModeView = document.externalRunning ? (document.vncURL != nil ? .vnc : .terminal) : .none
		self.documentSize = ViewSize(size: document.documentSize.cgSize)
	}

	private var installAgentDisabled: (title: String, disabled: Bool) {
		let title = "Install agent into virtual machine"

		if self.appState.isStopped {
			return (title, true)
		}

		if let agentVersion = self.document.vmInfos?.agentVersion {
			if agentVersion != CAKEAGENT_SNAPSHOT {
				return ("Update agent into virtual machine", false)
			}
		}

		return (title, self.document.agent != .none)
	}

	var body: some View {
		GeometryReader { geom in
			let view = vmView(geom.size)
				.windowAccessor($window) {
					self.logger.debug("\(self.id) Attaching window accessor: \(String(describing: $0))")

					if let window = $0 {
						if self.needsResize {
							let size = self.document.documentSize.cgSize

							DispatchQueue.main.async {
								self.setContentSize(size, animated: true)
							}

						}

						if #unavailable(macOS 15.0) {
							window.delegate = self.delegate
						}
					}
				}
				.frame(size: geom.size)
				.presentedWindowToolbarStyle(.unifiedCompact)
				.onAppear {
					handleAppear()
				}.onDisappear {
					handleDisappear()
				}.onReceive(NSWindow.willStartLiveResizeNotification) { notification in
					handleStartLiveResizeNotification(notification)
				}.onReceive(NSWindow.didEndLiveResizeNotification) { notification in
					handleDidResizeNotification(notification)
				}.onReceive(NSWindow.willCloseNotification) { notification in
					handleWillCloseNotification(notification)
				}.onReceive(VirtualMachineDocument.VNCFramebufferSizeChanged) { notification in
					handleVNCFramebufferSizeChangedNotification(notification)
				}.onReceive(VirtualMachineDocument.StartVirtualMachine) { notification in
					handleStartVirtualMachineNotification(notification)
				}.onReceive(VirtualMachineDocument.DeleteVirtualMachine) { notification in
					handleDeleteVirtualMachineNotification(notification)
				}.onChange(of: appearsActive) { _, newValue in
					handleAppStateChangedNotification(newValue)
				}.onChange(of: self.document.externalRunning) { _, newValue in
					handleDocumentExternalRunningChangedNotification(newValue)
				}.onChange(of: self.document.status) { _, newValue in
					handleDocumentStatusChangedNotification(newValue)
				}.onChange(of: self.document.vncStatus) { _, newValue in
					handleVncStatusChangedNotification(newValue)
				}.onChange(of: self.externalModeView) { _, newValue in
					handleExternalModeChangedNotification(newValue)
				}.onChange(of: self.launchVMExternally) { _, newValue in
					self.launchExternally = self.document.isLaunchVMExternally
				}
				.toolbar {
					ToolbarItemGroup(placement: .navigation) {
						if document.status == .stopping {
							Button("Force stop", systemImage: "power") {
								document.stopFromUI(force: true)
							}
							.help("Force to stop virtual machine")
							.disabled(document.agent == .installing)
						} else if document.status == .running {
							Button("Request to stop", systemImage: "stop") {
								document.stopFromUI(force: false)
							}
							.help("Request to stop virtual machine")
							.disabled(document.agent == .installing)
						} else if document.status == .paused {
							Button("Resume", systemImage: "playpause") {
								document.startFromUI()
							}.help("Resumes virtual machine")
						} else {
							Button("Start", systemImage: "play.fill") {
								document.startFromUI()
							}
							.help("Start virtual machine")
							.disabled(document.status == .starting || document.status == .stopping)
						}
						
						Button("Pause", systemImage: "pause") {
							document.suspendFromUI()
						}
						.help("Suspends virtual machine")
						.disabled(document.suspendable == false || document.agent == .installing)
						
						Button("Restart", systemImage: "arrow.trianglehead.clockwise") {
							document.restartFromUI()
						}
						.help("Restart virtual machine")
						.disabled(self.appState.isStopped || document.agent == .installing)
						
						Button("Create template", systemImage: "archivebox") {
							createTemplate = true
						}
						.help("Create template from virtual machine")
						.disabled(self.appState.isRunning)
					}
					
					ToolbarItemGroup(placement: .primaryAction) {
						if self.document.status == .stopped {
							if self.launchExternally {
								Button("Run hosted", systemImage: "personalhotspot.slash") {
									launchExternally.toggle()
									document.launchVMExternally = false
								}
								.help("Launch machine in detached mode")
							} else {
								Button("Run detached", systemImage: "personalhotspot") {
									launchExternally.toggle()
									document.launchVMExternally = true
								}
								.help("Launch machine inside app")
							}
						}

						let agentCondition = self.document.agentCondition

						Button(action: {
							self.appState.isAgentInstalling = true
							
							self.document.installAgent(updateAgent: agentCondition.needUpdate) {
								self.appState.isAgentInstalling = false
							}
						}, label: {
							ZStack {
								Image(systemName:agentCondition.needUpdate ? "person.2.badge.plus" : "person.badge.plus")
									.opacity(self.appState.isAgentInstalling ? 0 : 1)
								
								if self.appState.isAgentInstalling {
									ProgressView().frame(height: 10).scaleEffect(0.5)
								}
							}
						})
						.help(agentCondition.title)
						.disabled(agentCondition.disabled)
						
						Button("Delete", systemImage: "trash") {
							self.appState.deleteVirtualMachine(document: self.document)
						}
						.help("Delete virtual machine")
						.disabled(self.appState.isRunning || self.appState.isPaused)
					}

					if let vmInfos = document.vmInfos, vmInfos.cpuInfos != nil {
						ToolbarItemGroup(placement: .status) {
							// CPU Usage Status Bar
							CPUUsageView(vmInfos: vmInfos)
						}
					}

					ToolbarItemGroup(placement: .primaryAction) {
						
						Button("Settings", systemImage: "gear") {
							displaySettings = true
						}
						.help("Configure virtual machine")
						.disabled(self.document.virtualMachine == nil)
					}
				}.sheet(isPresented: $displaySettings) {
					VirtualMachineSettingsView(config: $document.virtualMachineConfig).frame(width: 700)
				}.alert("Create template", isPresented: $createTemplate) {
					CreateTemplateView(appState: $appState)
				}.onGeometryChange(for: CGRect.self) { proxy in
					proxy.frame(in: .global)
				} action: { newValue in
					if needsResize == false && window != nil {
						self.setDocumentSize(newValue.size)
					}
				}

			if #available(macOS 15.0, *) {
				view.windowToolbarFullScreenVisibility(.onHover)
			}
		}
	}

	func setContentSize(_ size: CGSize, animated: Bool) {
		if let window = self.window {
			self.logger.debug("\(self.id) Resize window: \(size)")
			self.needsResize = false

			let titleBarHeight: CGFloat = window.frame.height - window.contentLayoutRect.height
			var frame = window.frame

			frame = window.frameRect(forContentRect: NSMakeRect(frame.origin.x, frame.origin.y, size.width, size.height + titleBarHeight))
			frame.origin.y += window.frame.size.height
			frame.origin.y -= frame.size.height

			if frame != window.frame {
				window.setFrame(frame, display: true, animate: animated)
			}
		}
	}

	func setDocumentSize(_ size: CGSize) {
		self.documentSize.cgSize = size

		if self.liveResizeWindow == false {
			Logger(self).info("onGeometryChange: \(size), window: \(String(describing: window))")

			self.document.setDocumentSize(self.documentSize)
		}
	}

	func isMyWindowKey(_ notification: Notification) -> Bool {
		if let window = notification.object as? NSWindow, window.windowNumber == self.window?.windowNumber {
			return true
		}

		return false
	}

	func handleAppear() {
		NSWindow.allowsAutomaticWindowTabbing = false
		self.appState.currentDocument = self.document
		
		if let window = self.window {
			self.document.setScreenSize(.init(size: window.contentLayoutRect.size))
		} else {
			self.needsResize = true
		}
	}

	func handleDisappear() {
		if self.appState.currentDocument == self.document {
			self.appState.currentDocument = nil
		}
	}

	func handleStartLiveResizeNotification(_ notification: Notification) {
		if isMyWindowKey(notification) {
			self.logger.debug("handleStartLiveResizeNotification: \(notification)")

			self.liveResizeWindow = true
		}
	}

	func handleDidResizeNotification(_ notification: Notification) {
		if isMyWindowKey(notification) {
			self.logger.debug("handleDidResizeNotification: \(notification)")

			if self.liveResizeWindow {
				self.liveResizeWindow = false

				self.document.setDocumentSize(self.documentSize)
			}
		}
	}

	func handleWillCloseNotification(_ notification: Notification) {
		if self.document.externalRunning == false && self.isNoShutdownVMOnClose == false {
			if isMyWindowKey(notification) {
				if document.status == .running {
					document.stopFromUI(force: false)
				}
				
				DispatchQueue.main.async {
					self.document.close()
				}
			}
		}
	}

	func isNotificationConcerned(_ notification: Notification) -> Bool {
		guard let userInfos = notification.userInfo else {
			return false
		}

		guard let document = userInfos["document"] as? String else {
			return false
		}
		
		guard document == self.document.name else {
			return false
		}

		return true
	}

	func handleVNCFramebufferSizeChangedNotification(_ notification: Notification) {
		guard self.isNotificationConcerned(notification) else {
			return
		}

		if let size = notification.object as? CGSize {
			self.logger.debug("\(self.id) VNCFramebufferSizeChanged: \(size) \(String(describing: window))")

			if let window = self.window {
				if window.styleMask.contains(NSWindow.StyleMask.fullScreen) == false {
					DispatchQueue.main.async {
						self.setContentSize(size, animated: true)
					}
				}
			}
		}
	}

	func handleStartVirtualMachineNotification(_ notification: Notification) {
		guard self.isNotificationConcerned(notification) else {
			return
		}

		if document.status != .running {
			document.startFromUI()
		}
	}

	func handleDeleteVirtualMachineNotification(_ notification: Notification) {
		guard self.isNotificationConcerned(notification) else {
			return
		}

		if self.appState.currentDocument == self.document {
			self.appState.currentDocument = nil
		}
		
		if document.status == .running {
			document.stopFromUI(force: false)
		}
		
		dismiss()
	}

	func handleAppStateChangedNotification(_ newValue: Bool) {
		if newValue {
			self.appState.currentDocument = self.document
			self.appState.isAgentInstalling = self.document.agent == .installing
			self.appState.isStopped = document.status == .stopped || document.status == .stopping
			self.appState.isRunning = document.status == .running || document.status == .starting
			self.appState.isPaused = document.status == .paused || document.status == .pausing
			self.appState.isSuspendable = document.status == .running && document.suspendable
		} else if self.appState.currentDocument == self.document {
			self.appState.currentDocument = nil
		}
	}

	func handleDocumentExternalRunningChangedNotification(_ newValue: Bool) {
		if newValue {
			self.externalModeView = document.vncURL != nil ? .vnc : .terminal
		} else {
			self.externalModeView = .none
		}
	}

	func handleDocumentStatusChangedNotification(_ newValue: VirtualMachineDocument.Status) {
		if self.appearsActive {
			self.appState.isAgentInstalling = self.document.agent == .installing
			self.appState.isStopped = newValue == .stopped || newValue == .stopping
			self.appState.isRunning = newValue == .running || newValue == .starting
			self.appState.isPaused = newValue == .paused || newValue == .pausing
			self.appState.isSuspendable = newValue == .running && document.suspendable
		}
	}

	func handleVncStatusChangedNotification(_ newValue: VirtualMachineDocument.VncStatus) {
		if let connection = self.document.connection, let framebuffer = connection.framebuffer {
			self.logger.debug("VNC status changed: \(newValue), framebuffer size: \(framebuffer.size)")
		}
	}

	func handleExternalModeChangedNotification(_ newValue: ExternalModeView) {
		if newValue == .vnc && self.document.externalRunning {
			self.document.tryVNCConnect()
		}
	}

	@ViewBuilder public func tryIt(
		@ViewBuilder try success: () throws -> some View,
		@ViewBuilder catch failure: (any Error) -> some View
	) -> some View {
		switch Result(catching: success) {
		case .success(let success): success
		case .failure(let error): failure(error)
		}
	}

	@ViewBuilder
	func terminalView(_ size: CGSize) -> some View {
		if self.document.agent == .installed {
			ExternalVirtualMachineView(document: document, size: size, dismiss: dismiss)
				.colorPicker(placement: .secondaryAction)
				.fontPicker(placement: .secondaryAction)
				.frame(size: size)
		} else if self.document.agent == .installing {
			LabelView("Installing agent...", size: size)
		} else {
			LabelView("Agent not installed. Please install the agent first.", size: size)
		}
	}

	@ViewBuilder
	func externalView(_ size: CGSize) -> some View {
		if self.document.vncURL == nil || self.externalModeView == .terminal {
			self.terminalView(size)
		} else {
			switch self.document.vncStatus {
			case .connecting:
				LabelView("Connecting to VNC", size: size, progress: true)
			case .disconnected:
				LabelView("VNC not connected", size: size)
			case .connected:
				LabelView("VNC connected", size: size)
			case .disconnecting:
				LabelView("VNC disconnecting", size: size)
			case .ready:
				VNCView(document: self.document).frame(size: size)
			}
		}
	}
	
	@ViewBuilder
	func vmView(_ size: CGSize) -> some View {
		if self.document.externalRunning {
			externalView(size)
				.frame(size: size)
				.toolbar {
					ToolbarItem(placement: .secondaryAction) {
						Picker("Mode", selection: $externalModeView) {
							Image(systemName: "apple.terminal").tag(ExternalModeView.terminal)
							if self.document.vncURL != nil {
								Image(systemName: "play.display").tag(ExternalModeView.vnc)
							}
						}.pickerStyle(.segmented).labelsHidden()
					}
				}
		} else if self.document.isLaunchVMExternally {
			LabelView(self.vmStatus(), progress: self.document.status == .starting)
		} else if document.virtualMachine != nil {
			if self.document.status != .running {
				LabelView(self.vmStatus(), progress: false)
			} else {
				InternalVirtualMachineView(document: document)
					.frame(size: size)
			}
		} else {
			LabelView("Virtual machine not loaded", size: size)
		}
	}

	func vmStatus() -> String {
		switch self.document.status {
		case .running:
			return "VM is running"
		case .paused:
			return "VM is paused"
		case .stopped:
			return "VM is stopped"
		case .saving:
			return "VM is saving"
		case .none:
			return "VM is undefined"
		case .error:
			return "VM on error"
		case .starting:
			return "VM is starting"
		case .pausing:
			return "VM is pausing"
		case .resuming:
			return "VM is resuming"
		case .stopping:
			return "VM is stopping"
		case .restoring:
			return "VM is restoring"
		}
	}

	func settings() {
		self.openWindow(id: "settings", value: self.document.virtualMachine!.location.name)
	}

	func promptToSave() {

	}
}

// MARK: - CPU Usage View Component
struct CPUUsageView: View {
	let vmInfos: VMInformations
	
	var body: some View {
		Group {
			if let cpuInfos = vmInfos.cpuInfos {
				HStack(spacing: 2) {
					if let firstIP = vmInfos.ipaddresses.first {
						Image(systemName: "network")
							.foregroundColor(.secondary)
							.font(.caption)
						Text(firstIP)
							.foregroundColor(.secondary)
							.font(.caption)
					}
					Image(systemName: "cpu")
						.foregroundColor(.secondary)
						.font(.caption)
					
					// Vertical bars for each CPU core
					HStack(spacing: 1) {
						ForEach(Array(cpuInfos.cores.enumerated()), id: \.offset) { index, core in
							VStack(spacing: 0) {
								Spacer()
								
								Rectangle()
									.frame(width: 8, height: max(2, core.usagePercent / 100.0 * 16))
									.foregroundColor(cpuUsageColor(core.usagePercent))
								
								Rectangle()
									.frame(width: 8, height: max(0, 16 - (core.usagePercent / 100.0 * 16)))
									.foregroundColor(Color.clear)
							}
							.frame(height: 16)
							.help("Core \(index): \(Int(core.usagePercent))%\nUser: \(String(format: "%.1f", core.user))%\nSystem: \(String(format: "%.1f", core.system))%\nIdle: \(String(format: "%.1f", core.idle))%")
						}
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
				.background(Color.secondary.opacity(0.1))
				.cornerRadius(4)
				.help("CPU Cores Usage (\(cpuInfos.cores.count) cores total)")
			} else {
				HStack(spacing: 4) {
					Image(systemName: "cpu")
						.foregroundColor(.secondary)
						.font(.caption)
					
					// Placeholder bars when no data
					HStack(spacing: 1) {
						ForEach(0..<4, id: \.self) { _ in
							Rectangle()
								.frame(width: 4, height: 16)
								.foregroundColor(.secondary.opacity(0.3))
						}
					}
				}
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
				.help("CPU usage unavailable")
			}
		}
	}
	
	private func cpuUsageColor(_ usage: Double) -> Color {
		switch usage {
		case 0..<30:
			return .green
		case 30..<70:
			return .yellow
		case 70..<90:
			return .orange
		default:
			return .red
		}
	}
}

#Preview {
	HostVirtualMachineView(appState: .constant(AppState()), document: VirtualMachineDocument())
}
