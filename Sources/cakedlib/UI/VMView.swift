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
	public var virtualMachine: VirtualMachine
	public var display: VMRunHandler.DisplayMode
	public var vncPassword: String?
	public var vncPort: Int?
	public var captureMethod: VNCCaptureMethod

	public init(_ display: VMRunHandler.DisplayMode, automaticallyReconfiguresDisplay: Bool = false, vm: VirtualMachine, vncPassword: String?, vncPort: Int?, captureMethod: VNCCaptureMethod) {
		self.automaticallyReconfiguresDisplay = automaticallyReconfiguresDisplay
		self.vm = vm
		self.virtualMachine = vm
		self.display = display
		self.vncPassword = vncPassword
		self.vncPort = vncPort
		self.captureMethod = captureMethod
	}

	public func makeNSView(context: Context) -> NSViewType {
		let machineView = VZVirtualMachineView()

		if #available(macOS 14.0, *) {
			machineView.automaticallyReconfiguresDisplay = self.automaticallyReconfiguresDisplay
		}

		return machineView
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.virtualMachine = self.virtualMachine.getVM()
		
		if let vncPassword, let vncPort, display == .all {
			if let vncURL = try? self.vm.startVncServer(nsView, vncPassword: vncPassword, port: vncPort, captureMethod: captureMethod) {
				Logger(self).info("VNC server started at \(vncURL.absoluteString)")
			} else {
				Logger(self).error("Failed to start VNC server")
			}
		}
	}
}
