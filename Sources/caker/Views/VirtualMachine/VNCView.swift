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

class VNCConnectionLogger: VNCLogger {
	let logger: Logger = Logger("VNCConnectionLogger")
	var isDebugLoggingEnabled: Bool = false
	
	public func logDebug(_ message: String) {
		if isDebugLoggingEnabled {
			self.logger.debug(message)
		}
	}
	
	public func logInfo(_ message: String) {
		self.logger.info(message)
	}
	
	public func logWarning(_ message: String) {
		self.logger.warn(message)
	}
	
	public func logError(_ message: String) {
		self.logger.error(message)
	}
}

struct VNCView: NSViewRepresentable {
	typealias NSViewType = NSVNCView

	private let document: VirtualMachineDocument
	private let logger = Logger("HostVirtualMachineView")

	init(document: VirtualMachineDocument,) {
		self.document = document
	}

	func makeCoordinator() -> VirtualMachineDocument {
		return document
	}

	func makeNSView(context: Context) -> NSViewType {
		guard let connection = document.connection, let framebuffer = connection.framebuffer else {
			fatalError("Connection is nil")
		}

		let view = NSVNCView(frame: CGRectMake(0, 0, framebuffer.cgSize.width, framebuffer.cgSize.height), connection: connection)

		self.document.vncView = view

		self.logger.info("makeNSView: \(view.frame), \(framebuffer.cgSize)")

		return view
	}

	/*func sizeThatFits(_ proposal: ProposedViewSize, nsView: Self.NSViewType, context: Self.Context) -> CGSize? {
		if let framebuffer = self.document.connection.framebuffer {
			if let width = proposal.width, let height = proposal.height {
				self.logger.info("sizeThatFits: \(width)x\(height), \(nsView.frame), \(framebuffer.cgSize)")
			}


			return framebuffer.cgSize
		} else {
			if let width = proposal.width, let height = proposal.height {
				self.logger.info("sizeThatFits: \(width)x\(height), \(nsView.frame)")
			}
		}
		
		return nil
	}*/

	func updateNSView(_ nsView: NSViewType, context: Context) {
		if let connection = self.document.connection, let framebuffer = connection.framebuffer {
			self.logger.info("updateNSView: \(nsView.frame), framebuffer: \(framebuffer.cgSize)")
		} else {
			self.logger.info("updateNSView: \(nsView.frame), framebuffer: nil")
		}
	}

}
