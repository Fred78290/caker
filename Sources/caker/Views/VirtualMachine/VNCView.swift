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
	private let callback: VMView.CallbackWindow?
	private let logger = Logger("HostVirtualMachineView")

	init(document: VirtualMachineDocument, _ callback: VMView.CallbackWindow? = nil) {
		self.document = document
		self.callback = callback
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
		view.delegate = self.document

		if let callback = self.callback {
			DispatchQueue.main.async {
				callback(view.window)
			}
		}

		self.logger.info("makeNSView: \(view), \(view.frame)")

		view.allowsFrameSizeDidChangeNotification = true

		return view
	}

	/*func sizeThatFits(_ proposal: ProposedViewSize, nsView: Self.NSViewType, context: Self.Context) -> CGSize? {
		if let connection = self.document.connection, let framebuffer = connection.framebuffer {
			return framebuffer.cgSize
		}

		self.logger.info("sizeThatFits: \(proposal)")

		return nil
	}*/

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.allowsFrameSizeDidChangeNotification = true

		if let connection = self.document.connection, let framebuffer = connection.framebuffer {
			self.logger.info("updateNSView: \(framebuffer), \(nsView.frame), \(framebuffer.cgSize)")
		} else {
			self.logger.info("updateNSView: framebuffer nil, \(nsView.frame)")
		}
	}

}
