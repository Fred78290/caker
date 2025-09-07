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

	public var isDebugLoggingEnabled: Bool {
		get {
			Logger.LoggingLevel() == .debug
		}

		set(newValue) {
			if newValue {
				Logger.setLevel(.debug)
			}
		}
	}
	
	public func logDebug(_ message: String) {
		self.logger.debug(message)
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
	private let callback: VMView.CallbackWindow
	private let logger = Logger("HostVirtualMachineView")
	private let size: CGSize

	init(document: VirtualMachineDocument, size: CGSize, _ callback: @escaping VMView.CallbackWindow) {
		self.document = document
		self.size = size
		self.callback = callback
	}

	func makeCoordinator() -> VirtualMachineDocument {
		return document
	}

	func makeNSView(context: Context) -> NSViewType {
		guard let connection = document.connection/*, let framebuffer = connection.framebuffer*/ else {
			fatalError("Connection is nil")
		}

		//let view = NSVNCView(frame: CGRectMake(0, 0, framebuffer.cgSize.width, framebuffer.cgSize.height), connection: connection)
		let view = NSVNCView(frame: CGRectMake(0, 0, size.width, size.height), connection: connection)

		self.document.vncView = view

		DispatchQueue.main.async {
			callback(view.window)
		}

		self.logger.info("makeNSView: \(size), \(view.frame)")

		return view
	}

	/*func sizeThatFits(_ proposal: ProposedViewSize, nsView: Self.NSViewType, context: Self.Context) -> CGSize? {
		if let width = proposal.width, let height = proposal.height {
			self.logger.info("sizeThatFits: \(width)x\(height), \(nsView.frame)")
		}

		if let framebuffer = self.document.connection.framebuffer {
			return framebuffer.cgSize
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
