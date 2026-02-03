//
//  VZVNCServer.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/02/2026.
//
import Virtualization

class VZVNCServerImpl: VNCServer, @unchecked Sendable {
	override func start() throws {
		if let vmView = self.sourceView as? VNCVirtualMachineView, let display = vmView.graphicsDisplay, let observer = self.sourceView as? VZGraphicsDisplayObserver {
			observer.displayDidBeginReconfiguration?(display)
			observer.displayDidEndReconfiguration?(display)
		}

		try super.start()
	}
}
