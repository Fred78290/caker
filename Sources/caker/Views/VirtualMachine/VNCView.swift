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

	func makeNSView(context: Context) -> NSView {
		if let connection = document.connection, let framebuffer = connection.framebuffer {
			return VNCCAFramebufferView(frame: CGRectMake(0, 0, viewSize.width, viewSize.height), framebuffer: framebuffer, connection: connection)
		}
		
		return NSViewType(frame: CGRectMake(0, 0, viewSize.width, viewSize.height))
	}
	
	func updateNSView(_ nsView: NSView, context: Context) {
	}

}
