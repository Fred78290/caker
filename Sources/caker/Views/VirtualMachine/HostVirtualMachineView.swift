//
//  HostVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/05/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

extension View {
	func minSize(_ size: CGSize) -> some View {
		frame(minWidth: size.width, idealWidth: size.width, maxWidth: .infinity, minHeight: size.height, idealHeight: size.height, maxHeight: .infinity)
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

	@State var windowNumber: Int = 0
	@State var displaySettings: Bool = false
	@State var createTemplate: Bool = false
	@State var virtualMachineConfig: VirtualMachineConfig = VirtualMachineConfig()
	@State var displayFontPanel: Bool = false
	@State var terminalColor: Color = .blue
	@State var externalModeView: ExternalModeView
	@State var size: CGSize
	@State var automaticallyReconfiguresDisplay: Bool

	private let logger = Logger("HostVirtualMachineView")
	private let delegate: CustomWindowDelegate = CustomWindowDelegate()
	private let minSize: CGSize

	init(appState: Binding<AppState>, document: VirtualMachineDocument) {
		let config = document.virtualMachineConfig
		let display = config.display
		let size = CGSize(width: CGFloat(display.width), height: CGFloat(display.height))

		self._appState = appState
		self._document = StateObject(wrappedValue: document)
		self.size = size
		self.minSize = size
		self.automaticallyReconfiguresDisplay = config.displayRefit || (config.os == .darwin)
		self.externalModeView = document.externalRunning ? (document.vncURL != nil ? .vnc : .terminal) : .none
	}

	var body: some View {
		let view = vmView { window in
			if let window = window {
				windowNumber = window.windowNumber
				
				if #unavailable(macOS 15.0) {
					window.delegate = self.delegate
				}
			}
		}.onAppear {
			handleAppear()
		}.onDisappear {
			handleDisappear()
		}.onReceive(NSWindow.didEndLiveResizeNotification) { notification in
			handleDidResizeNotification(notification)
		}.onReceive(NSWindow.willCloseNotification) { notification in
			handleWillCloseNotification(notification)
		}.onReceive(NSNotification.VNCFramebufferSizeChanged) { notification in
			handleVNCFramebufferSizeChangedNotification(notification)
		}.onReceive(NSNotification.StartVirtualMachine) { notification in
			handleStartVirtualMachineNotification(notification)
		}.onReceive(NSNotification.DeleteVirtualMachine) { notification in
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
			self.size = newValue.size
		}.frame(minWidth: self.minSize.width, idealWidth: self.document.documentWidth, maxWidth: .infinity, minHeight: self.minSize.height, idealHeight: self.document.documentHeight, maxHeight: .infinity)

		if #available(macOS 15.0, *) {
			view.windowToolbarFullScreenVisibility(.onHover)
		}
	}

	func isMyWindowKey(_ notification: Notification) -> Bool {
		if let window = notification.object as? NSWindow, window.windowNumber == windowNumber {
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
			self.document.setScreenSize(self.size)
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
			self.size = size
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
			self.size = framebuffer.cgSize
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
	func terminalView(callback: @escaping VMView.CallbackWindow) -> some View {
		if self.document.agent == .installed {
			ExternalVirtualMachineView(document: _document, size: self.minSize, dismiss: dismiss, callback: callback)
				.colorPicker(placement: .secondaryAction)
				.fontPicker(placement: .secondaryAction)
		} else if self.document.agent == .installing {
			LabelView("Installing agent...", callback)
		} else {
			LabelView("Agent not installed. Please install the agent first.", callback)
		}
	}

	@ViewBuilder
	func combinedView(callback: @escaping VMView.CallbackWindow) -> some View {
		GeometryReader { geom in
			HStack {
				if self.externalModeView == .terminal {
					self.terminalView(callback: callback)
				} else {
					ZStack {
						switch self.document.vncStatus {
						case .connecting:
							HostingWindowFinder(callback)
							VStack(alignment: .center) {
								ProgressView().overlay {
									Color.white.mask {
										ProgressView()
									}
								}
								Text("Connecting to VNC")
									.foregroundStyle(.white)
									.font(.largeTitle)
							}
							.frame(size: geom.size)
							.background(.black, ignoresSafeAreaEdges: .bottom)
						case .disconnected:
							LabelView("VNC not connected", callback)
						case .connected:
							LabelView("VNC connected", callback)
						case .disconnecting:
							LabelView("VNC disconnecting", callback)
						case .ready:
							VNCView(document: self.document, size: geom.size, callback)
								.frame(size: geom.size)
								.onAppear {
									document.setScreenSize(geom.size)
								}
						}
					}
				}
			}.toolbar {
				ToolbarItem(placement: .secondaryAction) {
					Picker("Mode", selection: $externalModeView) {
						Image(systemName: "apple.terminal").tag(ExternalModeView.terminal)
						Image(systemName: "play.display").tag(ExternalModeView.vnc)
					}.pickerStyle(.segmented).labelsHidden()
				}
			}
		}
	}

	@ViewBuilder
	func vmView(callback: @escaping VMView.CallbackWindow) -> some View {
		if self.document.externalRunning {
			if self.document.vncURL == nil {
				self.terminalView(callback: callback)
			} else {
				self.combinedView(callback: callback)
			}
		} else if self.launchVMExternally {
			if self.document.status == .starting {
				GeometryReader { geom in
					HostingWindowFinder(callback)

					VStack(alignment: .center) {
						ProgressView().overlay {
							Color.white.mask {
								ProgressView()
							}
						}
						Text(self.vmStatus())
							.foregroundStyle(.white)
							.font(.largeTitle)
					}
					.frame(size: geom.size)
					.background(.black, ignoresSafeAreaEdges: .bottom)
				}
			} else {
				LabelView(self.vmStatus(), callback)
			}
		} else {
			InternalVirtualMachineView(document: document, automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, callback: callback)
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
