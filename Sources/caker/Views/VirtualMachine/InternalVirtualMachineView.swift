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
import CakeAgentLib

class CakerVZVirtualMachineView: VNCVirtualMachineView {
	private var liveViewResize: Bool = false
	private weak var document: VirtualMachineDocument!

	init(document: VirtualMachineDocument) {
		self.document = document

		super.init(frame: .init(origin: .zero, size: document.documentSize.cgSize))
	}

	func attachtoDocument(showsHostCursor: Bool) {
		if let virtualMachine = self.document.virtualMachine {
			virtualMachine.vzMachineView = self

			self.virtualMachine = virtualMachine.getVM()
			self.showsHostCursor = showsHostCursor

			if #available(macOS 14.0, *) {
				self.automaticallyReconfiguresDisplay = document.virtualMachineConfig.displayRefit || (document.virtualMachineConfig.os == .darwin)

				// Windows' display driver refuses a display past what it allocated at start: keep the display inside it
				if self.automaticallyReconfiguresDisplay && virtualMachine.config.isWindowsGuest {
					self.displayPixelLimit = WindowsDisplayLimit.maxPixels(booted: CGSize(width: virtualMachine.config.display.width, height: virtualMachine.config.display.height))
				}
			}
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public override func viewWillStartLiveResize() {
		self.liveViewResize = true
		super.viewWillStartLiveResize()
	}

	override func viewDidEndLiveResize() {
		self.liveViewResize = false
		self.document.setScreenSize(.init(self.bounds.size))
		super.viewDidEndLiveResize()
	}
}

struct InternalVirtualMachineView: NSViewRepresentable {
	public typealias NSViewType = CakerVZVirtualMachineView

	private let document: VirtualMachineDocument
	private let logger = Logger("InternalVirtualMachineView")
	private let view: CakerVZVirtualMachineView
	private let showsHostCursor: Bool
	
	init(document: VirtualMachineDocument, showsHostCursor: Bool) {
		self.document = document
		self.view = CakerVZVirtualMachineView(document: self.document)
		self.showsHostCursor = showsHostCursor
	}

	public func makeNSView(context: Context) -> NSViewType {
		return self.view
	}

	public func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.attachtoDocument(showsHostCursor: self.showsHostCursor)
	}
}
