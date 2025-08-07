//
//  VNC.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/08/2025.
//

import Foundation
import Dynamic
import Virtualization

public class VNCServer {
	private let vnc: Dynamic

	public init(virtualMachine: VZVirtualMachine, queue: dispatch_queue_t) {
		let securityConfiguration = Dynamic._VZVNCNoSecuritySecurityConfiguration()

		vnc = Dynamic._VZVNCServer(port: 0, queue: queue, securityConfiguration: securityConfiguration)
		vnc.virtualMachine = virtualMachine
		vnc.start()
	}

	public func waitForURL() throws -> URL {
		while true {
			if let port = vnc.port.asUInt16, port != 0 {
				return URL(string: "vnc://127.0.0.1:\(port)")!
			}

			Thread.sleep(forTimeInterval: 1)
		}
	}

	public func stop() throws {
		vnc.stop()
	}

	deinit {
		try? stop()
	}
}
