//
//  HostVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/05/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

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

	var delegate: CustomWindowDelegate = CustomWindowDelegate()

	init(appState: Binding<AppState>, document: VirtualMachineDocument) {
		self._appState = appState
		self._document = StateObject(wrappedValue: document)
		
		if document.status == .external {
			self.externalModeView = document.vncURL != nil ? .vnc : .terminal
		} else {
			self.externalModeView = .none
		}

		let config = document.virtualMachineConfig
		let display = config.display
	
		self.size = CGSize(width: CGFloat(display.width), height: CGFloat(display.height))
		self.automaticallyReconfiguresDisplay = config.displayRefit || (config.os == .darwin)
	}

	var body: some View {
		let view = vmView { window in
			if let window = window {
				windowNumber = window.windowNumber
				
				if #unavailable(macOS 15.0) {
					window.delegate = self.delegate
				}
			}
		}
		.onAppear {
			NSWindow.allowsAutomaticWindowTabbing = false
			self.appState.currentDocument = self.document
		}.onDisappear {
			if self.appState.currentDocument == self.document {
				self.appState.currentDocument = nil
			}
		}.onReceive(NSNotification.VNCFramebufferSizeChanged) { notification in
			if let size = notification.object as? CGSize {
				self.logger.info("VNCFramebufferSizeChanged: \(size)")
				self.size = size
			}
		}.onReceive(NSWindow.willCloseNotification) { notification in
			if let window = notification.object as? NSWindow {
				if window.windowNumber == windowNumber {
					if document.status == .running {
						document.stopFromUI(force: false)
					}

					DispatchQueue.main.async {
						self.document.close()
					}
				}
			}
		}.onReceive(NSNotification.StartVirtualMachine) { notification in
			if let name = notification.object as? String, name == document.name, document.status != .running {
				document.startFromUI()
			}
		}.onReceive(NSNotification.DeleteVirtualMachine) { notification in
			if let name = notification.object as? String, name == document.name {
				if self.appState.currentDocument == self.document {
					self.appState.currentDocument = nil
				}
				
				if document.status == .running {
					document.stopFromUI(force: false)
				}
				
				dismiss()
			}
		}.onChange(of: appearsActive) { newValue in
			if newValue {
				self.appState.currentDocument = self.document
				self.appState.isAgentInstalling = self.document.agent == .installing
				self.appState.isStopped = document.status == .stopped || document.status == .stopping
				self.appState.isRunning = document.status == .running || document.status == .starting || document.status == .external
				self.appState.isPaused = document.status == .paused || document.status == .pausing
				self.appState.isSuspendable = document.status == .running && document.suspendable
			} else if self.appState.currentDocument == self.document {
				self.appState.currentDocument = nil
			}
		}.onChange(of: self.document.status) { newValue in
			if newValue == .external {
				self.externalModeView = document.vncURL != nil ? .vnc : .terminal
			} else {
				self.externalModeView = .none
			}

			if self.appearsActive {
				self.appState.isAgentInstalling = self.document.agent == .installing
				self.appState.isStopped = newValue == .stopped || newValue == .stopping
				self.appState.isRunning = newValue == .running || newValue == .starting || newValue == .external
				self.appState.isPaused = newValue == .paused || newValue == .pausing
				self.appState.isSuspendable = newValue == .running && document.suspendable
			}
		}.onChange(of: self.document.vncStatus) { newValue in
			if let framebuffer = self.document.connection.framebuffer, newValue == .ready {
				self.logger.info("VNC framebuffer size changed: \(framebuffer.size)")
				self.size = framebuffer.cgSize
			}
		}.onChange(of: self.externalModeView) { newValue in
			if newValue == .vnc && self.document.status == .external {
				self.document.tryVNCConnect()
			}
		}.toolbar {
			ToolbarItemGroup(placement: .navigation) {
				if document.status == .stopping {
					Button("Force stop", systemImage: "power") {
						document.stopFromUI(force: true)
					}
					.help("Force to stop virtual machine")
					.disabled(document.agent == .installing)
				} else if document.status == .running || document.status == .external {
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
		}
		.sheet(isPresented: $displaySettings) {
			VirtualMachineSettingsView(config: $document.virtualMachineConfig).frame(width: 700)
		}.alert("Create template", isPresented: $createTemplate) {
			CreateTemplateView(appState: $appState)
		}

		if #available(macOS 15.0, *) {
			view.windowToolbarFullScreenVisibility(.onHover)
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
	func terminalView(callback: VMView.CallbackWindow? = nil) -> some View {
		if self.document.agent == .installed {
			ExternalVirtualMachineView(document: _document, size: self.size, dismiss: dismiss, callback: callback)
				.colorPicker(placement: .secondaryAction)
				.fontPicker(placement: .secondaryAction)
				.frame(minWidth: self.size.width, idealWidth: self.size.width, maxWidth: .infinity, minHeight: self.size.height, idealHeight: self.size.height, maxHeight: .infinity)
		} else if self.document.agent == .installing {
			Text("Installing agent...")
		} else {
			Text("Agent not installed. Please install the agent first.")
		}
	}

	@ViewBuilder
	func combinedView(callback: VMView.CallbackWindow? = nil) -> some View {
		if self.externalModeView == .terminal {
			self.terminalView(callback: callback)
		} else {
			switch self.document.vncStatus {
			case .connecting:
				VStack(alignment: .center) {
					ProgressView()
					Text("Connecting to VNC")
						.foregroundStyle(.white)
						.background(.black)
						.font(.largeTitle)
						.frame(maxWidth: .infinity, minHeight: self.size.height, maxHeight: .infinity)
				}
				.background(.black)
				.frame(maxWidth: .infinity, minHeight: self.size.height, maxHeight: .infinity)
			case .disconnected:
				Text("VNC not connected")
					.foregroundStyle(.white)
					.background(.black)
					.font(.largeTitle)
					.frame(maxWidth: .infinity, minHeight: self.size.height, maxHeight: .infinity)
			case .connected:
				Text("VNC connected")
					.foregroundStyle(.white)
					.background(.black)
					.font(.largeTitle)
					.frame(maxWidth: .infinity, minHeight: self.size.height, maxHeight: .infinity)
			case .disconnecting:
				Text("VNC disconnecting")
					.foregroundStyle(.white)
					.background(.black)
					.font(.largeTitle)
					.frame(maxWidth: .infinity, minHeight: self.size.height, maxHeight: .infinity)
			case .ready:
				ViewThatFits {
					VNCView(document: self.document, callback).frame(size: self.size)
				}
			}
		}
	}

	@ViewBuilder
	func vmView(callback: VMView.CallbackWindow? = nil) -> some View {
		if self.document.status == .external {
			if self.document.vncURL == nil {
				self.terminalView(callback: callback)
			} else {
				self.combinedView(callback: callback)
					.frame(minWidth: self.size.width, idealWidth: self.size.width, maxWidth: .infinity, minHeight: self.size.height, idealHeight: self.size.height, maxHeight: .infinity)
					.background(.black)
					.toolbar {
						 ToolbarItem(placement: .secondaryAction) {
							 Picker("Mode", selection: $externalModeView) {
								 Image(systemName: "apple.terminal").tag(ExternalModeView.terminal)
								 Image(systemName: "play.display").tag(ExternalModeView.vnc)
							 }.pickerStyle(.segmented).labelsHidden()
						 }
					 }
			}
		} else {
			InternalVirtualMachineView(document: document, automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, callback: callback)
				.frame(minWidth: self.size.width, idealWidth: self.size.width, maxWidth: .infinity, minHeight: self.size.height, idealHeight: self.size.height, maxHeight: .infinity)
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
