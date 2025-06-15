//
//  VMView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import SwiftUI
import Virtualization

public struct VMView: NSViewRepresentable {
	public typealias NSViewType = VZVirtualMachineView
	public typealias CallbackWindow = (NSWindow?) -> Void

	let automaticallyReconfiguresDisplay: Bool

	@ObservedObject
	public var vm: VirtualMachine
	public var virtualMachine: VZVirtualMachine
	var callback: CallbackWindow? = nil

	public init(automaticallyReconfiguresDisplay: Bool = false, vm: VirtualMachine, virtualMachine: VZVirtualMachine, callback: CallbackWindow? = nil) {
		self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
		self.vm = vm
		self.virtualMachine = virtualMachine
		self.callback = callback
	}

	public func makeNSView(context: Context) -> NSViewType {
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

	public func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.virtualMachine = virtualMachine
	}
}
