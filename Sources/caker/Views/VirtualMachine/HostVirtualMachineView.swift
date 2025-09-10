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
	Logger("View").info(text)

	return EmptyView()
}

extension View {
	func frame(_ label: String = "View", minSize: CGSize, idealSize: CGSize) -> some View {
		Logger(label).info("frame(minSize: \(minSize), idealSize: \(idealSize))")

		return frame(minWidth: minSize.width, idealWidth: idealSize.width, maxWidth: .infinity, minHeight: minSize.height, idealHeight: idealSize.height, maxHeight: .infinity)
		//return frame(size: idealSize)
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
	@State var documentSize: CGSize
	@State var automaticallyReconfiguresDisplay: Bool

	private let logger = Logger("HostVirtualMachineView")
	private let delegate: CustomWindowDelegate = CustomWindowDelegate()
	private let minSize: CGSize

	init(appState: Binding<AppState>, document: VirtualMachineDocument) {
		self._appState = appState
		self._document = StateObject(wrappedValue: document)
		self.documentSize = document.documentSize
		self.minSize = CGSize(width: 800, height: 600)
		self.automaticallyReconfiguresDisplay = document.virtualMachineConfig.displayRefit || (document.virtualMachineConfig.os == .darwin)
		self.externalModeView = document.externalRunning ? (document.vncURL != nil ? .vnc : .terminal) : .none
	}

	var body: some View {
		let view = vmView { window in
			if let window = window {
				self.window = window

				window.isRestorable = false

				if #unavailable(macOS 15.0) {
					window.delegate = self.delegate
				}
			}
		}
		//.frame("MainView", minSize: self.minSize, idealSize: self.documentSize)
		.onAppear {
			handleAppear()
		}.onDisappear {
			handleDisappear()
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
		}.onChange(of: appearsActive) { newValue in
			handleAppStateChangedNotification(newValue)
		}.onChange(of: self.document.externalRunning) { newValue in
			handleDocumentExternalRunningChangedNotification(newValue)
		}.onChange(of: self.document.status) { newValue in
			handleDocumentStatusChangedNotification(newValue)
		}.onChange(of: self.document.vncStatus) { newValue in
			handleVncStatusChangedNotification(newValue)
		}.onChange(of: self.externalModeView) { newValue in
			handleExternalModeChangedNotification(newValue)
		}.toolbar {
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
					Button("Start", systemImage: "play") {
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
				Button(action: {
					self.appState.isAgentInstalling = true
					
					self.document.installAgent {
						self.appState.isAgentInstalling = false
					}
				}, label: {
					ZStack {
						Image(systemName:"person.badge.plus").opacity(self.appState.isAgentInstalling ? 0 : 1)
						if self.appState.isAgentInstalling {
							ProgressView().frame(height: 10).scaleEffect(0.5)
						}
					}
				})
				.help("Install agent into virtual machine")
				.disabled(self.appState.isStopped || self.document.agent != .none)
				
				Button("Delete", systemImage: "trash") {
					self.appState.deleteVirtualMachine(document: self.document)
				}
				.help("Delete virtual machine")
				.disabled(self.appState.isRunning || self.appState.isPaused)
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
			self.documentSize = newValue.size
			self.document.setDocumentSize(newValue.size)
		}
		.presentedWindowToolbarStyle(.unifiedCompact)

		if #available(macOS 15.0, *) {
			view.windowToolbarFullScreenVisibility(.onHover)
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
	}

	func handleDisappear() {
		if self.appState.currentDocument == self.document {
			self.appState.currentDocument = nil
		}
	}

	func handleDidResizeNotification(_ notification: Notification) {
		if isMyWindowKey(notification) {
			self.document.setScreenSize(self.documentSize)
		}
	}
	
	func handleWillCloseNotification(_ notification: Notification) {
		if isMyWindowKey(notification) {
			if document.status == .running {
				document.stopFromUI(force: false)
			}

			DispatchQueue.main.async {
				self.document.close()
			}
		}
	}

	func handleVNCFramebufferSizeChangedNotification(_ notification: Notification) {
		if let size = notification.object as? CGSize {
			self.logger.info("VNCFramebufferSizeChanged: \(size)")
			self.documentSize = size
		}
	}

	func handleStartVirtualMachineNotification(_ notification: Notification) {
		if let name = notification.object as? String, name == document.name, document.status != .running {
			document.startFromUI()
		}
	}

	func handleDeleteVirtualMachineNotification(_ notification: Notification) {
		if let name = notification.object as? String, name == document.name {
			if self.appState.currentDocument == self.document {
				self.appState.currentDocument = nil
			}
			
			if document.status == .running {
				document.stopFromUI(force: false)
			}
			
			dismiss()
		}
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
		if newValue == .ready, let connection = self.document.connection, let framebuffer = connection.framebuffer {
			self.logger.info("VNC framebuffer size changed: \(framebuffer.size)")
			self.documentSize = framebuffer.cgSize
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
			ExternalVirtualMachineView(document: document, size: self.documentSize, dismiss: dismiss)
				.colorPicker(placement: .secondaryAction)
				.fontPicker(placement: .secondaryAction)
				//.frame(size: size)
		} else if self.document.agent == .installing {
			LabelView("Installing agent...")
		} else {
			LabelView("Agent not installed. Please install the agent first.")
		}
	}

	@ViewBuilder
	func externalView(_ size: CGSize) -> some View {
		if self.document.vncURL == nil || self.externalModeView == .terminal {
			self.terminalView(size)
		} else {
			switch self.document.vncStatus {
			case .connecting:
				LabelView("Connecting to VNC", progress: true)
			case .disconnected:
				LabelView("VNC not connected")
			case .connected:
				LabelView("VNC connected")
			case .disconnecting:
				LabelView("VNC disconnecting")
			case .ready:
				VNCView(document: self.document)//.frame(size: size)
			}
		}
	}
	
	@ViewBuilder
	func combinedView(_ size: CGSize) -> some View {
		externalView(size)
			//.frame(size: size)
			.toolbar {
				ToolbarItem(placement: .secondaryAction) {
					Picker("Mode", selection: $externalModeView) {
						Image(systemName: "apple.terminal").tag(ExternalModeView.terminal)
						Image(systemName: "play.display").tag(ExternalModeView.vnc)
					}.pickerStyle(.segmented).labelsHidden()
				}
			}
	}

	@ViewBuilder
	func vmView(callback: @escaping VMView.CallbackWindow) -> some View {
		GeometryReader { geom in
			HostingWindowFinder(callback)
			ViewThatFits {
				if self.document.externalRunning {
					self.combinedView(geom.size)
				} else if self.launchVMExternally {
					LabelView(self.vmStatus(), progress: self.document.status == .starting)
				} else {
					InternalVirtualMachineView(document: document, automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay)
						.frame(size: geom.size)
				}
			}.onAppear {
				self.document.setScreenSize(geom.size)
			}
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

#Preview {
	HostVirtualMachineView(appState: .constant(AppState()), document: VirtualMachineDocument())
}
