//
//  VMView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import SwiftUI
import Virtualization

struct VMView: NSViewRepresentable {
	typealias NSViewType = VZVirtualMachineView
	typealias CallbackWindow = (NSWindow?) -> Void

	let automaticallyReconfiguresDisplay: Bool

	@ObservedObject
	var vm: VirtualMachine
	var virtualMachine: VZVirtualMachine
	var callback: CallbackWindow? = nil

	func makeNSView(context: Context) -> NSViewType {
		let machineView = VZVirtualMachineView()

		if let callback = self.callback {
			DispatchQueue.main.async { [weak machineView] in
				callback(machineView?.window)
			}
		}

		if #available(macOS 14.0, *) {
			machineView.automaticallyReconfiguresDisplay = self.automaticallyReconfiguresDisplay
		}

		return machineView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.virtualMachine = virtualMachine
	}
}
