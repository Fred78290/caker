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
	private let password: String // = UUID().uuidString

	public init(_ virtualMachine: VZVirtualMachine, password: String, port: Int, queue: dispatch_queue_t) {
		let securityConfiguration = Dynamic._VZVNCAuthenticationSecurityConfiguration(password: password)
		//let securityConfiguration = Dynamic._VZVNCNoSecuritySecurityConfiguration()
		self.password = password
		self.vnc = Dynamic._VZVNCServer(port: port, queue: queue, securityConfiguration: securityConfiguration)
		self.vnc.virtualMachine = virtualMachine
		self.vnc.start()
	}

	public func waitForURL() throws -> URL {
		while true {
			if let port = vnc.port.asUInt16, port != 0 {
				return URL(string: "vnc://:\(password)@127.0.0.1:\(port)")!
			}

			Thread.sleep(forTimeInterval: 0.05)
		}
	}

	public func stop() {
		vnc.stop()
	}

	deinit {
		stop()
	}
}
