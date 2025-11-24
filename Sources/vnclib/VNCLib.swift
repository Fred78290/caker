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

import Foundation

// Export all public classes
public typealias VNCServer = VNCLib.VNCServer
public typealias VNCServerDelegate = VNCLib.VNCServerDelegate
public typealias VNCFramebuffer = VNCLib.VNCFramebuffer
public typealias VNCInputHandler = VNCLib.VNCInputHandler
public typealias VNCKeyMapper = VNCLib.VNCKeyMapper