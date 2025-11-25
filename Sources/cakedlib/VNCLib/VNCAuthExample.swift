// VNCAuthExample.swift
// Example showing VNC Authentication usage

import Foundation
import AppKit

class VNCAuthExample: VNCServerDelegate {
	
	func basicAuthExample() {
		let sourceView = NSView()
		
		// Server with password authentication
		let secureServer = VNCServer(sourceView, password: "vncPassword123", port: 5900, captureMethod: .metal
		)
		
		// Set up delegate to monitor authentication
		secureServer.delegate = self
		
		do {
			try secureServer.start()
			print("🔐 VNC Server started with password authentication on port 5900")
			print("🔑 Use password: 'vncPassword123' to connect")
		} catch {
			print("❌ Failed to start VNC server: \(error)")
		}
	}
	
	func noAuthExample() {
		let sourceView = NSView()
		
		// Server without authentication
		let openServer = VNCServer(sourceView, port: 5901, captureMethod: .coreGraphics)
		
		do {
			try openServer.start()
			print("🔓 VNC Server started without authentication on port 5901")
		} catch {
			print("❌ Failed to start VNC server: \(error)")
		}
	}
	
	func runtimePasswordChange() {
		let sourceView = NSView()
		
		let server = VNCServer(sourceView, password: "initialPassword", port: 5902)
		
		do {
			try server.start()
			print("🔐 VNC Server started with initial password")
			
			// Change password after 10 seconds
			DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
				server.password = "newPassword123"
				print("🔄 Password changed to: 'newPassword123'")
			}
			
			// Remove password after 20 seconds
			DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
				server.password = nil
				print("🔓 Password removed - server now open")
			}
			
		} catch {
			print("❌ Failed to start VNC server: \(error)")
		}
	}
	
	func vncServer(_ server: VNCServer, clientDidConnect clientAddress: String) {
		print("✅ Client connected: \(clientAddress)")
	}
	
	func vncServer(_ server: VNCServer, clientDidDisconnect clientAddress: String) {
		print("❌ Client disconnected: \(clientAddress)")
	}
	
	func vncServer(_ server: VNCServer, didReceiveError error: Error) {
		print("🚨 VNC Server error: \(error.localizedDescription)")
	}
	
	func vncServer(_ server: VNCServer, didReceiveKeyEvent key: UInt32, isDown: Bool) {
		print("⌨️  Key \(key) \(isDown ? "pressed" : "released")")
	}
	
	func vncServer(_ server: VNCServer, didReceiveMouseEvent x: Int, y: Int, buttonMask: UInt8) {
		print("🖱️  Mouse at (\(x), \(y)) buttons: \(buttonMask)")
	}
}
