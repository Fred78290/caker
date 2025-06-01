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

	let automaticallyReconfiguresDisplay: Bool

	@ObservedObject
	var vm: VirtualMachine
	var virtualMachine: VZVirtualMachine

	func makeNSView(context: Context) -> NSViewType {
		let machineView = VZVirtualMachineView()

		if #available(macOS 14.0, *) {
			machineView.automaticallyReconfiguresDisplay = self.automaticallyReconfiguresDisplay
		}

		return machineView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.virtualMachine = virtualMachine
	}
}
