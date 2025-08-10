//
//  VNCView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/08/2025.
//

import Foundation
import SwiftUI
import RoyalVNCKit
import CakedLib

struct VNCView: NSViewRepresentable {
	private let document: VirtualMachineDocument
	private let callback: VMView.CallbackWindow?
	private let logger = Logger("HostVirtualMachineView")

	init(document: VirtualMachineDocument, _ callback: VMView.CallbackWindow? = nil) {
		self.document = document
		self.callback = callback
	}

	func makeCoordinator() -> VirtualMachineDocument {
		return document
	}

	func makeNSView(context: Context) -> NSView {
		let view = context.coordinator.vncView!

		if let callback = self.callback {
			DispatchQueue.main.async {
				callback(view.window)
			}
		}

		self.logger.info("makeNSView: \(view), \(view.frame)")

		return context.coordinator.vncView
	}

	func sizeThatFits(_ proposal: ProposedViewSize, nsView: Self.NSViewType, context: Self.Context) -> CGSize? {
		if let framebuffer = self.document.connection.framebuffer {
			return framebuffer.cgSize
		}
		
		return nil
	}

	func updateNSView(_ nsView: NSView, context: Context) {
		self.logger.info("updateNSView: \(nsView), \(nsView.frame)")

		if let framebuffer = self.document.connection.framebuffer {
			//nsView.frame = CGRectMake(nsView.frame.origin.x, nsView.frame.origin.y, framebuffer.cgSize.width, framebuffer.cgSize.height)
			self.logger.info("Resize NSView: \(framebuffer), \(nsView.frame), \(framebuffer.cgSize)")
		} else {
			self.logger.info("updateNSView: framebuffer nil")
		}
	}

}
