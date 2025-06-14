//
//  VirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/05/2025.
//

import SwiftUI

class CustomWindowDelegate: NSObject, NSWindowDelegate {
	override init() {
		super.init()
	}
	
	func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
		return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
	}
}

struct VirtualMachineView: View {
	@Environment(\.appearsActive) var appearsActive
	@Environment(\.scenePhase) var scenePhase
	@Environment(\.openWindow) private var openWindow
	@ObservedObject var appState: AppState
	@StateObject var document: VirtualMachineDocument

	@AppStorage("vmstopped") var isStopped: Bool = true
	@AppStorage("vmsuspendable") var isSuspendable: Bool = false
	@AppStorage("vmrunning") var isRunning: Bool = false
	@AppStorage("vmpaused") var isPaused: Bool = false
	@State var windowNumber: Int = 0
	@State var displaySettings: Bool = false

	var delegate: CustomWindowDelegate = CustomWindowDelegate()

	var body: some View {
		let virtualMachine = document.virtualMachine!
		let config = virtualMachine.config
		let display = config.display
		let minWidth = CGFloat(display.width)
		let idealWidth = CGFloat(display.width)
		let minHeight = CGFloat(display.height)
		let idealHeight = CGFloat(display.height)
		let automaticallyReconfiguresDisplay = config.displayRefit || (config.os == .darwin)
		let view = VMView(automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, vm: virtualMachine, virtualMachine: virtualMachine.virtualMachine) { window in
			if let window = window {
				windowNumber = window.windowNumber
				print("Window: \(self.windowNumber)")
				if #unavailable(macOS 15.0) {
					window.delegate = self.delegate
				}
			}
		}.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: idealHeight, maxHeight: .infinity).onAppear {
				NSWindow.allowsAutomaticWindowTabbing = false
				self.appState.currentDocument = self.document
			}.onDisappear {
				if self.appState.currentDocument == self.document {
					self.appState.currentDocument = nil
				}
			}.onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
				if let window = notification.object as? NSWindow {
					if window.windowNumber == windowNumber && document.status == .running {
						document.requestStopFromUI()
					}
				}
			}.onChange(of: appearsActive) { active in
				print("appearsActive: \(self.windowNumber) - \(active)")
				if active {
					self.appState.currentDocument = self.document
					self.appState.isStopped = document.status == .stopped
					self.appState.isRunning = document.status == .running
					self.appState.isPaused = document.status == .suspended
					self.appState.isSuspendable = document.status == .running && document.suspendable
				} else if self.appState.currentDocument == self.document {
					self.appState.currentDocument = nil
				}
			}.onChange(of: self.document.status) { newValue in
				if self.appearsActive {
					self.appState.isStopped = document.status == .stopped
					self.appState.isRunning = document.status == .running
					self.appState.isPaused = document.status == .suspended
					self.appState.isSuspendable = document.status == .running && document.suspendable
				}
			}.toolbar {
				ToolbarItemGroup(placement: .navigation) {
					if document.status == .running {
						Button("Stop", systemImage: "power") {
							document.requestStopFromUI()
						}
					} else {
						Button("Start", systemImage: "play.fill") {
							document.startFromUI()
						}
					}
					
					Button("Pause", systemImage: "pause") {
						document.suspendFromUI()
					}.disabled(!isSuspendable)
					
					Button("Restart", systemImage: "restart") {
						document.stopFromUI()
					}.disabled(isStopped)
				}

				ToolbarItemGroup(placement: .primaryAction) {
					Button("Settings", systemImage: "gear") {
//						settings()
						displaySettings = true
					}.disabled(self.document.virtualMachine == nil)
				}
			}.sheet(isPresented: $displaySettings) {
				VirtualMachineSettingsView(vmname: virtualMachine.vmLocation.name)
			}
			
		if #available(macOS 15.0, *) {
			view.windowToolbarFullScreenVisibility(.onHover)
		}
	}
	
	func settings() {
		self.openWindow(id: "settings", value: self.document.virtualMachine!.vmLocation.name)
	}
}

#Preview {
	VirtualMachineView(appState: AppState(), document: VirtualMachineDocument())
}
