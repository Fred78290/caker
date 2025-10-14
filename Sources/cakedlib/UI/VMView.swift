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

	let automaticallyReconfiguresDisplay: Bool

	@ObservedObject
	public var vm: VirtualMachine
	public var virtualMachine: VZVirtualMachine

	public init(automaticallyReconfiguresDisplay: Bool = false, vm: VirtualMachine) {
		self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
		self.vm = vm
		self.virtualMachine = vm.getVM()
	}

	public func makeNSView(context: Context) -> NSViewType {
		let machineView = VZVirtualMachineView()

		if #available(macOS 14.0, *) {
			machineView.automaticallyReconfiguresDisplay = self.automaticallyReconfiguresDisplay
		}

		return machineView
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.virtualMachine = virtualMachine
	}
}
