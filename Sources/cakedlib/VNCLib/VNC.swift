// VNCLib - VNC Server Library for macOS
//
// This library provides a complete VNC server based on NSView
// to replace the use of the private _VZVNCServer class
//
// Features:
// - Complete VNC server with RFB 3.8 protocol support
// - Real-time capture of NSView content
// - Automatic view resizing handling
// - Complete keyboard and mouse support
// - Clipboard management
// - Thread-safe and performance optimized
//
// Usage:
// ```swift
// let server = VNCServer(sourceView: myView, port: 5900)
// server.delegate = self
// try server.start()
// ```

import Dynamic
import Foundation
import Virtualization

extension VZVNCServer {
	public static func createVNCServer(_ virtualMachine: VZVirtualMachine, name: String, view: VZVirtualMachineView, password: String, port: Int, queue: dispatch_queue_t) throws -> VZVNCServer {
		//return InternalVNCServer(virtualMachine, view: view, password: password, port: port, queue: queue)
		return try VNCServer(view, name: name, password: password, port: UInt16(port))
	}
}

class InternalVNCServer: VZVNCServer {
	var delegate: (any VNCServerDelegate)?

	private let vnc: Dynamic
	private let password: String  // = UUID().uuidString

	init(_ virtualMachine: VZVirtualMachine, view: VZVirtualMachineView, password: String, port: Int, queue: dispatch_queue_t) {
		let securityConfiguration = Dynamic._VZVNCAuthenticationSecurityConfiguration(password: password)
		self.password = password
		self.vnc = Dynamic._VZVNCServer(port: port, queue: queue, securityConfiguration: securityConfiguration)
		self.vnc.virtualMachine = virtualMachine
	}

	func connectionURL() -> URL {
		while true {
			if let port = vnc.port.asUInt16, port != 0 {
				return URL(string: "vnc://:\(password)@127.0.0.1:\(port)")!
			}

			Thread.sleep(forTimeInterval: 0.05)
		}
	}

	func stop() {
		self.vnc.stop()
	}

	func start() throws {
		self.vnc.start()
	}

	deinit {
		stop()
	}
}
