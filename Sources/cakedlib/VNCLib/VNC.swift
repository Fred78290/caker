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

public extension VZVNCServer {
	static func createVNCServer(_ virtualMachine: VZVirtualMachine, name: String, view: VMView.NSViewType, password: String, port: Int, allInet: Bool, queue: dispatch_queue_t) throws -> VZVNCServer {
		//return InternalVNCServer(virtualMachine, view: view, password: password, port: port, queue: queue)
		return try VNCServer(view, name: name, password: password, port: UInt16(port), allInet: allInet)
	}

	static func findHostMatching(urls: [String]?) -> URL? {
		Self.findHostMatching(urls: urls?.compactMap {
			URL(string: $0)
		})
	}

	static func findHostMatching(urls: [URL]?) -> URL? {
		guard let urls else {
			return nil
		}

		let inf = VZSharedNetwork.networkInterfaces()

		guard let found = urls.first(where: {
			guard let host = $0.host(percentEncoded: false) else {
				return false
			}

			guard let ip = IP.V4(host) else {
				return false
			}

			return inf.first { inf in
				inf.value.contains(ip)
			} != nil
		}) else {
			return urls.first
		}

		return found
	}
}

class InternalVNCServer: VZVNCServer {
	var delegate: (any VNCServerDelegate)?

	private let vnc: Dynamic
	private let password: String  // = UUID().uuidString
	private let view: VMView.NSViewType

	init(_ virtualMachine: VZVirtualMachine, view: VMView.NSViewType, password: String, port: Int, queue: dispatch_queue_t) {
		let securityConfiguration = Dynamic._VZVNCAuthenticationSecurityConfiguration(password: password)
		self.password = password
		self.vnc = Dynamic._VZVNCServer(port: port, queue: queue, securityConfiguration: securityConfiguration)
		self.vnc.virtualMachine = virtualMachine
		self.view = view
	}

	var urls: [URL] {
		while true {
			if let port = vnc.port.asUInt16, port != 0 {
				return [URL(string: "vnc://:\(password)@127.0.0.1:\(port)")!]
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
