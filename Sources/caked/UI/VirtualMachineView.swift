//
//  VirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/05/2025.
//

import SwiftUI

struct VirtualMachineView: View {
	@Environment(\.controlActiveState) var controlActiveState
	@ObservedObject var appState: AppState
	@Binding var document: VirtualMachineDocument

	var body: some View {
		let virtualMachine = document.virtualMachine!
		let config = virtualMachine.config
		let display = config.display
		let minWidth = CGFloat(display.width)
		let idealWidth = CGFloat(display.width)
		let minHeight = CGFloat(display.height)
		let idealHeight = CGFloat(display.height)
		let automaticallyReconfiguresDisplay = config.displayRefit || (config.os == .darwin)
		
		return VMView(automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, vm: virtualMachine, virtualMachine: virtualMachine.virtualMachine)
			.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: idealHeight, maxHeight: .infinity).onAppear {
				NSWindow.allowsAutomaticWindowTabbing = false
				self.appState.currentDocument = self.document
			}.onDisappear {
				self.appState.currentDocument = nil
			}.onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
				document.requestStopFromUI()
			}.onChange(of: controlActiveState) { newValue in
				if newValue == .active || newValue == .key {
					self.appState.currentDocument = self.document
				} else {
					self.appState.currentDocument = nil
				}
			}.toolbar {
				ToolbarItemGroup(placement: .navigation) {
					if document.status == .running {
						Button("Stop", systemImage: "stop") {
							document.requestStopFromUI()
						}.disabled(document.canStop)
					} else {
						Button("Start", systemImage: "start") {
							document.startFromUI()
						}.disabled(document.canStart == false)
					}
					
					Button("Pause", systemImage: "pause") {
						document.suspendFromUI()
					}.disabled(document.canPause == false)
					
					Button("Restart", systemImage: "restart") {
						document.stopFromUI()
					}.disabled(document.canStop)
				}
			}
	}
}

#Preview {
	VirtualMachineView(appState: AppState(), document: .constant(VirtualMachineDocument()))
}
