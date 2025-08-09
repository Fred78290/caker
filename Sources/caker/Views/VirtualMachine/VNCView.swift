//
//  VNCView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/08/2025.
//

import Foundation
import SwiftUI
import RoyalVNCKit

struct VNCView: NSViewRepresentable {
	var document: VirtualMachineDocument
	var viewSize: CGSize

	func makeCoordinator() -> VirtualMachineDocument {
		return document
	}

	func makeNSView(context: Context) -> NSView {
		let view: NSView

		if let connection = context.coordinator.connection, let framebuffer = connection.framebuffer {
			view = VNCCAFramebufferView(frame: CGRectMake(0, 0, viewSize.width, viewSize.height), framebuffer: framebuffer, connection: connection)
		} else {
			view = NSViewType(frame: CGRectMake(0, 0, viewSize.width, viewSize.height))
		}

		view.autoresizingMask = [.width, .height]

		return view
	}
	
	func updateNSView(_ nsView: NSView, context: Context) {
		if let view = nsView as? VNCCAFramebufferView {
			context.coordinator.framebufferView = view
		} else {
			context.coordinator.framebufferView = nil
		}
	}

}
