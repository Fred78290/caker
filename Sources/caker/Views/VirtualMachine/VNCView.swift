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

class VNCConnectionLogger: VNCLogger {
	let logger: Logger = Logger("VNCConnectionLogger")
	var isDebugLoggingEnabled: Bool = false

	public func logDebug(_ message: String) {
		#if DEBUG
			if isDebugLoggingEnabled {
				self.logger.debug(message)
			}
		#endif
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

	init(document: VirtualMachineDocument, ) {
		self.document = document
	}

	func makeCoordinator() -> VirtualMachineDocument {
		return document
	}

	func makeNSView(context: Context) -> NSViewType {
		guard let connection = document.connection, let framebuffer = connection.framebuffer else {
			fatalError("Connection is nil")
		}

		let view = NSVNCView(frame: CGRectMake(0, 0, framebuffer.cgSize.width, framebuffer.cgSize.height), document: document)

		self.document.vncView = view

		#if DEBUG
			self.logger.debug("makeNSView: \(view.frame), \(framebuffer.cgSize)")
		#endif

		return view
	}

	/*func sizeThatFits(_ proposal: ProposedViewSize, nsView: Self.NSViewType, context: Self.Context) -> CGSize? {
		if let framebuffer = self.document.connection.framebuffer {
			if let width = proposal.width, let height = proposal.height {
				self.logger.debug("sizeThatFits: \(width)x\(height), \(nsView.frame), \(framebuffer.cgSize)")
			}
	
	
			return framebuffer.cgSize
		} else {
			if let width = proposal.width, let height = proposal.height {
				self.logger.debug("sizeThatFits: \(width)x\(height), \(nsView.frame)")
			}
		}
	
		return nil
	}*/

	func updateNSView(_ nsView: NSViewType, context: Context) {
		#if DEBUG
			if nsView.isLiveViewResize == false {
				if let connection = self.document.connection, let framebuffer = connection.framebuffer {
					self.logger.debug("updateNSView: \(nsView.frame), framebuffer: \(framebuffer.cgSize)")
				} else {
					self.logger.debug("updateNSView: \(nsView.frame), framebuffer: nil")
				}
			}
		#endif
	}

}
