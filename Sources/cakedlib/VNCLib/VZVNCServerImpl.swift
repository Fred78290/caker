//
//  VZVNCServer.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/02/2026.
//
import Virtualization

class VZVNCServerImpl: VNCServer, @unchecked Sendable {
	override func start() throws {
		if let vmView = self.sourceView as? VNCVirtualMachineView {
			if let framebufferView = vmView.framebufferView {
				vmView.autoresizesSubviews = true
				framebufferView.autoresizingMask = [.width, .height]
				framebufferView.frame = NSRect(origin: .zero, size: vmView.bounds.size)
			}

			let window: NSWindow = NSWindow(contentRect: vmView.bounds, styleMask: .borderless, backing: .buffered, defer: false)

			window.contentView = vmView
			window.makeKeyAndOrderFront(nil)
		}

		try super.start()
	}
}
