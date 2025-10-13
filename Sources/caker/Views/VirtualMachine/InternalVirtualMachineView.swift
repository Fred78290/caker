//
//  InternalVirtualMachineView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/07/2025.
//

import CakedLib
import GRPCLib
import SwiftUI
import Virtualization

class CakerVZVirtualMachineView: VZVirtualMachineView {
	private var liveViewResize: Bool = false
	private let document: VirtualMachineDocument

	init(document: VirtualMachineDocument) {
		self.document = document

		super.init(frame: .zero)
		self.virtualMachine = document.virtualMachine.getVM()

		if #available(macOS 14.0, *) {
			self.automaticallyReconfiguresDisplay = document.virtualMachineConfig.displayRefit || (document.virtualMachineConfig.os == .darwin)
		}
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	public override func viewWillStartLiveResize() {
		self.liveViewResize = true
	}

	override func viewDidEndLiveResize() {
		self.liveViewResize = false
		self.document.setScreenSize(.init(size: self.bounds.size))
	}
}

struct InternalVirtualMachineView: NSViewRepresentable {
	public typealias NSViewType = VZVirtualMachineView

	private let document: VirtualMachineDocument
	private let logger = Logger("InternalVirtualMachineView")

	init(document: VirtualMachineDocument) {
		self.document = document
	}

	public func makeNSView(context: Context) -> NSViewType {
		return CakerVZVirtualMachineView(document: self.document)
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
	}
}
