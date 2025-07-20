//
//  HostVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/05/2025.
//

import SwiftUI
import CakedLib
import GRPCLib

class CustomWindowDelegate: NSObject, NSWindowDelegate {
	override init() {
		super.init()
	}

	func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
		return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
	}
}

struct HostVirtualMachineView: View {
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

	var delegate: CustomWindowDelegate = CustomWindowDelegate()

	var body: some View {
		let view = vmView() { window in
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
		}.onReceive(NSWindow.willCloseNotification) { notification in
			if let window = notification.object as? NSWindow {
				if window.windowNumber == windowNumber {
					if document.status == .running {
						document.requestStopFromUI()
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
					document.stopFromUI()
				}

				dismiss()
			}
		}.onChange(of: appearsActive) { newValue in
			if newValue {
				self.appState.currentDocument = self.document
				self.appState.isStopped = document.status == .stopped
				self.appState.isRunning = document.status == .running || document.status == .external
				self.appState.isPaused = document.status == .suspended
				self.appState.isSuspendable = document.status == .running && document.suspendable
			} else if self.appState.currentDocument == self.document {
				self.appState.currentDocument = nil
			}
		}.onChange(of: self.document.status) { newValue in
			if self.appearsActive {
				self.appState.isStopped = newValue == .stopped
				self.appState.isRunning = newValue == .running || newValue == .external
				self.appState.isPaused = newValue == .suspended
				self.appState.isSuspendable = newValue == .running && document.suspendable
			}
		}.toolbar {
			ToolbarItemGroup(placement: .navigation) {
				if document.status == .running || document.status == .external {
					Button("Stop", systemImage: "stop.circle") {
						document.requestStopFromUI()
					}.help("Stop virtual machine")
				} else if document.status == .suspended {
					Button("Start", systemImage: "playpause.circle") {
						document.startFromUI()
					}.help("Resumes virtual machine")
				} else {
					Button("Start", systemImage: "play.circle") {
						document.startFromUI()
					}.help("Start virtual machine")
				}

				Button("Pause", systemImage: "pause.circle") {
					document.suspendFromUI()
				}
				.help("Suspends virtual machine")
				.disabled(document.suspendable == false)

				Button("Restart", systemImage: "restart.circle") {
					document.restartFromUI()
				}.disabled(self.appState.isStopped)

				Spacer()

				Button("Create template", systemImage: "archivebox") {
					createTemplate = true
				}.disabled(self.appState.isRunning)
			}

			ToolbarItemGroup(placement: .primaryAction) {
				Button("Settings", systemImage: "gear") {
					displaySettings = true
				}.disabled(self.document.virtualMachine == nil)
			}
		}.sheet(isPresented: $displaySettings) {
			VirtualMachineSettingsView(config: $document.virtualMachineConfig).frame(width: 700)
		}.alert("Create template", isPresented: $createTemplate) {
			CreateTemplateView(currentDocument: document)
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
	func vmView(callback: VMView.CallbackWindow? = nil) -> some View {
		let config = document.virtualMachineConfig
		let display = config.display
		let minWidth = CGFloat(display.width)
		let minHeight = CGFloat(display.height)
		let automaticallyReconfiguresDisplay = config.displayRefit || (config.os == .darwin)

		if self.document.status == .external {
			tryIt {
				try ExternalVirtualMachineView(document: _document, size: CGSize(width: minWidth, height: minHeight), dismiss: dismiss, callback: callback)
					.fontPanel(isPresented: $displayFontPanel)
					.toolbar {
						ToolbarItemGroup(placement: .secondaryAction) {
							Button("Font", systemImage: "character.circle") {
								displayFontPanel.toggle()
							}
							.help("Change font terminal")
						}
				}.frame(minWidth: minWidth, idealWidth: minWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: minHeight, maxHeight: .infinity)
			} catch: { error in
				if let error = error as? ServiceError {
					Text(error.description)
						.foregroundStyle(.red)
				} else {
					Text(error.localizedDescription)
						.foregroundStyle(.red)
				}
			}
		} else {
			InternalVirtualMachineView(document: document, automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, callback: callback).frame(minWidth: minWidth, idealWidth: minWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: minHeight, maxHeight: .infinity)
		}
	}

	func settings() {
		self.openWindow(id: "settings", value: self.document.virtualMachine!.vmLocation.name)
	}
	
	func promptToSave() {
		
	}
}

#Preview {
	HostVirtualMachineView(appState: .constant(AppState()), document: VirtualMachineDocument())
}
