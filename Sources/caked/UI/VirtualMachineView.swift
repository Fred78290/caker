//
//  VirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/05/2025.
//

import SwiftUI

struct VirtualMachineView: View {
	@ObservedObject var appState: AppState
	@Binding var document: VirtualMachine

	var body: some View {
		let display = document.config?.display ?? DisplaySize(width: 800, height: 600)
		let minWidth = CGFloat(display.width)
		let idealWidth = CGFloat(display.width)
		let minHeight = CGFloat(display.height)
		let idealHeight = CGFloat(display.height)
		let automaticallyReconfiguresDisplay: Bool

		if let config = document.config {
			automaticallyReconfiguresDisplay = config.displayRefit || (config.os == .darwin)
		} else {
			automaticallyReconfiguresDisplay = false
		}

		return VMView(automaticallyReconfiguresDisplay: automaticallyReconfiguresDisplay, vm: document, virtualMachine: document.virtualMachine).onAppear {
			NSWindow.allowsAutomaticWindowTabbing = false
		}.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: idealHeight, maxHeight: .infinity).onAppear {
			self.appState.currentVirtualMachine = self.document
		}.onDisappear {
			self.appState.currentVirtualMachine = nil
		}
	}
}

#Preview {
	VirtualMachineView(appState: AppState(), document: .constant(VirtualMachine()))
}
