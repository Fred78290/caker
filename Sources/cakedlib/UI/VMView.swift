//
//  VMView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import QuartzCore
import SwiftUI
import Virtualization
import CakeAgentLib
import Dynamic
import ObjectiveC.runtime

public struct VMView: NSViewRepresentable {
	public typealias NSViewType = VNCVirtualMachineView

	public var virtualMachine: VirtualMachine
	public var params: VMRunHandler

	public static func createView(vm: VirtualMachine, frame: NSRect) -> NSViewType {
		let vzMachineView = VNCVirtualMachineView(frame: frame)

		vzMachineView.virtualMachine = vm.virtualMachine
		vzMachineView.autoresizingMask = [.width, .height]
		vzMachineView.automaticallyReconfiguresDisplay = true
		vzMachineView.capturesSystemKeys = true
		//vzMachineView.showsHostCursor = false

		if vzMachineView.framebuffer == nil {
			fatalError("No framebuffer")
		}

		return vzMachineView
	}

	public init(_ vm: VirtualMachine, params: VMRunHandler) {
		self.params = params
		self.virtualMachine = vm
	}

	public func makeNSView(context: Context) -> NSViewType {
		guard let vmView = self.virtualMachine.env.vzMachineView else {
			return Self.createView(vm: self.virtualMachine, frame: .zero)
		}

		return vmView
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
	}
}

