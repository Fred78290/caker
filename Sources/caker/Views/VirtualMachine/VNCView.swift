//
//  VNCView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/08/2025.
//

import CakedLib
import Foundation
import RoyalVNCKit
import SwiftUI
import CakeAgentLib

struct VNCView: NSViewRepresentable {
	typealias NSViewType = NSVNCView

	private let document: VirtualMachineDocument
	private let logger = Logger("HostVirtualMachineView")

	init(document: VirtualMachineDocument) {
		self.document = document
	}

	func makeCoordinator() -> VirtualMachineDocument {
		return document
	}

	func makeNSView(context: Context) -> NSViewType {
		guard let connection = document.connection, let framebuffer = connection.framebuffer else {
			fatalError("Connection is nil")
		}

		let view = NSVNCView(frame: CGRectMake(0, 0, framebuffer.cgSize.width, framebuffer.cgSize.height), connection: document.connection)

		self.document.vncView = view

		#if DEBUG
			self.logger.trace("makeNSView: \(view.frame), \(framebuffer.cgSize)")
		#endif

		return view
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		#if DEBUG
			if nsView.isLiveViewResize == false {
				if let connection = self.document.connection, let framebuffer = connection.framebuffer {
					self.logger.trace("updateNSView: \(nsView.frame), framebuffer: \(framebuffer.cgSize)")
				} else {
					self.logger.trace("updateNSView: \(nsView.frame), framebuffer: nil")
				}
			}
		#endif
	}

}
