//
//  VNCApp.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/03/2026.
//
import AppKit
import ArgumentParser
import CakeAgentLib
import GRPCLib
import RoyalVNCKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	private var splashWindow: NSWindow? = nil

	func applicationWillTerminate(_ notification: Notification) {
		VNCApp.state.closeTunnel()
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		closeSplashWindowSingle()
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		NSApp.setDockIcon()
		self.showSplashWindow()
	}

	private func showSplashWindow() {
		self.splashWindow = SplashScreenView.showSplashWindow(name: VNCApp.state.name)
	}

	func closeSplashWindowSingle() {
		guard let window = self.splashWindow else {
			return
		}

		self.splashWindow = nil
		window.orderOut(self)
		window.close()

		// AppDelegate has no SwiftUI environment of its own — reading the action from a fresh
		// EnvironmentValues() is how a plain NSObject opens the "VM" WindowGroup by id.
		EnvironmentValues().openWindow(id: "VM")
	}
}

@Observable
public class VNCConnectionAppState: Codable {
	public typealias VNCSetScreenSizeAction = (ViewSize) -> Void
	public typealias VMStatusAction = () -> Status
	
	typealias VncStatusStream = (stream: AsyncThrowingStream<VncStatus, Error>, continuation: AsyncThrowingStream<VncStatus, Error>.Continuation)
	typealias VncStatusStreamContinuation = AsyncThrowingStream<VncStatus, Error>.Continuation
	
	public struct VNCView: NSViewRepresentable {
		public typealias NSViewType = NSVNCView
		
		private let appState: VNCConnectionAppState
		private let logger = Logger("VNCView")
		
		public init(_ appState: VNCConnectionAppState) {
			self.appState = appState
		}
		
		public func makeCoordinator() -> VNCConnectionAppState {
			return appState
		}
		
		public func makeNSView(context: Context) -> NSViewType {
			guard let framebuffer = appState.connection.framebuffer else {
				fatalError("framebuffer is nil")
			}
			
			let view = NSVNCView(frame: CGRectMake(0, 0, framebuffer.cgSize.width, framebuffer.cgSize.height), allowClientResize: appState.allowClientResize, connection: self.appState.connection)
			
			self.appState.vncView = view
			
#if DEBUG
			self.logger.trace("makeNSView: \(view.frame), \(framebuffer.cgSize)")
#endif
			
			return view
		}
		
		public func updateNSView(_ nsView: NSVNCView, context: Context) {
			guard nsView.isLiveViewResize == false && nsView.bounds.size != .zero else {
				return
			}
			
			if let connection = appState.connection, let framebuffer = connection.framebuffer {
				if nsView.bounds.size != framebuffer.cgSize {
					self.logger.debug("updateNSView: \(nsView.frame), framebuffer: \(framebuffer.cgSize)")
					nsView.setDesktopSize()
				}
			}
		}
	}
	
	public enum VncStatus: Int {
		case disconnected
		case connecting
		case connected
		case disconnecting
		case ready
		
		init(vncStatus: RoyalVNCKit.VNCConnection.Status) {
			switch vncStatus {
			case .disconnected:
				self = .disconnected
			case .connecting:
				self = .connecting
			case .connected:
				self = .connected
			case .disconnecting:
				self = .disconnecting
			}
		}
	}
	
	public let name: String
	public let config: VirtualMachineConfiguration
	public let vncLogger: VNCConnectionLogger
	public let username: String?
	public let password: String?
	public let vmStatus: VMStatusAction
	public let settings: RoyalVNCKit.VNCConnection.Settings
	public var tunnel: VNCTunnel?
	public var connection: RoyalVNCKit.VNCConnection! = nil
	public var vncView: NSVNCView? = nil
	public var vncStatus: VncStatus
	public var screenSize: ViewSize
	public var allowClientResize: Bool
	
	private var continuation: VncStatusStreamContinuation? = nil
	
	deinit {
		self.closeTunnel()
	}
	
	public init(
		name: String,
		config: VirtualMachineConfiguration,
		vncURL: URL,
		screenSize: ViewSize,
		tunnel: VNCTunnel?,
		allowClientResize: Bool,
		isDebugLoggingEnabled: Bool = false,
		vmStatus: @escaping VMStatusAction
	) throws {
		
		guard let vncPort = vncURL.port, let vncHost = vncURL.host(percentEncoded: false) else {
			throw ServiceError(String(localized: "VM \(name) does not have a VNC connection"))
		}
		
		// Create settings
		self.settings = RoyalVNCKit.VNCConnection.Settings(
			isDebugLoggingEnabled: isDebugLoggingEnabled,
			hostname: vncHost,
			port: UInt16(vncPort),
			isShared: true,
			isScalingEnabled: true,
			useDisplayLink: true,
			inputMode: .forwardAllKeyboardShortcutsAndHotKeys,
			isClipboardRedirectionEnabled: true,
			colorDepth: .depth24Bit,
			frameEncodings: .default)
		
		self.name = name
		self.vncLogger = VNCConnectionLogger(isDebugLoggingEnabled)
		self.username = vncURL.user(percentEncoded: false)
		self.password = vncURL.password(percentEncoded: false)
		self.connection = nil
		self.vncStatus = .disconnected
		self.screenSize = screenSize
		self.config = config
		self.vmStatus = vmStatus
		self.tunnel = tunnel
		self.allowClientResize = allowClientResize
	}
	
	required public init(from decoder: any Decoder) throws {
		throw ValidationError(String(localized: "Unimplemented"))
	}
	
	public func encode(to encoder: any Encoder) throws {
		throw ValidationError(String(localized: "Unimplemented"))
	}
	
	public func closeTunnel() {
		try? tunnel?.close().wait()
		
		self.tunnel = nil
	}
	
	public func tryVNCConnect() {
		guard self.connection == nil else {
			return
		}
		
		self.connection = RoyalVNCKit.VNCConnection(settings: self.settings, logger: vncLogger)
		self.connection.delegate = self
		self.connection.connect()
	}
	
	public func disconnect() {
		guard let connection = self.connection else {
			return
		}
		
		self.connection = nil
		
		connection.disconnect()
	}
	
	public func connect() async throws {
		guard self.connection == nil else {
			return
		}
		
		let stream = AsyncThrowingStream.makeStream(of: VncStatus.self)
		
		defer {
			stream.continuation.finish()
			self.continuation = nil
		}
		
		self.continuation = stream.continuation
		self.connection = RoyalVNCKit.VNCConnection(settings: self.settings, logger: vncLogger)
		self.connection.delegate = self
		
		self.connection.connect()
		
		for try await connectionState in stream.stream {
			if connectionState == .ready {
				break
			}
		}
	}
	
	public func setScreenSize(_ screenSize: ViewSize) {
		self.screenSize = screenSize
		self.vncView?.setDesktopSize()
	}
	
	@ViewBuilder
	public func view(_ size: CGSize) -> some View {
		switch self.vncStatus {
		case .connecting:
			LabelView("Connecting to VNC", size: size, progress: true)
		case .disconnected:
			LabelView("VNC not connected", size: size)
		case .connected:
			LabelView("VNC connected", size: size)
		case .disconnecting:
			LabelView("VNC disconnecting", size: size)
		case .ready:
			VNCConnectionAppState.VNCView(self)
				.frame(width: size.width, height: size.height)
				.background(.black)
		}
	}
}

extension VNCConnectionAppState: RoyalVNCKit.VNCConnectionDelegate {
	public func connection(_ connection: RoyalVNCKit.VNCConnection, stateDidChange connectionState: RoyalVNCKit.VNCConnection.ConnectionState) {
		DispatchQueue.main.async(execute: {
			var newStatus = VncStatus(vncStatus: connectionState.status)

			if connectionState.status == .connected {
				if connection.framebuffer != nil {
					newStatus = .ready
				}
			} else if connectionState.status == .disconnected {
				if self.connection != nil {
					self.connection = nil
					if self.vmStatus() == .running {
						newStatus = .connecting
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
							self.tryVNCConnect()
						}
					} else {
						self.vncView = nil
						self.closeTunnel()
					}
				} else {
					self.vncView = nil
					self.closeTunnel()
				}
			}

			self.vncStatus = newStatus

			if let continuation = self.continuation {
				if newStatus == .disconnecting || newStatus == .disconnected {
					continuation.finish(throwing: ServiceError(String(localized: "VNC disconnected unexpectedly")))
				}

				continuation.yield(newStatus)
			}
		})
	}

	public func connection(_ connection: RoyalVNCKit.VNCConnection, credentialFor authenticationType: RoyalVNCKit.VNCAuthenticationType, completion: @escaping ((any RoyalVNCKit.VNCCredential)?) -> Void) {
		let authenticationTypeString: String

		var credential: RoyalVNCKit.VNCCredential? = nil

		func readInput(_ prompt: String) -> String? {
			print(prompt, terminator: String.empty)

			return readLine(strippingNewline: true)
		}

		func readUser() -> String? {
			if let username {
				return username
			}

			return readInput("Username: ")
		}

		func readPassword() -> String? {
			if let password {
				return password
			}

			return readInput("Password: ")
		}

		switch authenticationType {
		case .vnc:
			authenticationTypeString = "VNC"
		case .appleRemoteDesktop:
			authenticationTypeString = "Apple Remote Desktop"
		case .ultraVNCMSLogonII:
			authenticationTypeString = "UltraVNC MS Logon II"
		@unknown default:
			fatalError("Unknown authentication type: \(authenticationType)")
		}

		self.vncLogger.logger.debug("connection credentialFor: \(authenticationTypeString)")

		if authenticationType.requiresUsername, authenticationType.requiresPassword {
			if let username = readUser(), let password = readPassword() {
				credential = VNCUsernamePasswordCredential(username: username, password: password)
			}
		} else if authenticationType.requiresPassword {
			if let password = readPassword() {
				credential = VNCPasswordCredential(password: password)
			}
		}

		completion(credential)
	}

	public func connection(_ connection: RoyalVNCKit.VNCConnection, didCreateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		if self.vncStatus != .ready {
			DispatchQueue.main.async {
				self.vncLogger.logger.debug("vnc ready")
				self.screenSize = ViewSize(framebuffer.cgSize)
				self.vncStatus = .ready
			}
		}
	}

	public func connection(_ connection: RoyalVNCKit.VNCConnection, didResizeFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		if framebuffer.size.width != 8192 && framebuffer.size.height != 4320 {
			self.vncView?.connection(connection, didResizeFramebuffer: framebuffer)

			DispatchQueue.main.async {
				self.screenSize = .init(framebuffer.cgSize)
			}
		}
	}

	public func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
		self.vncView?.connection(connection, didUpdateFramebuffer: framebuffer, x: x, y: y, width: width, height: height)
	}

	public func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateCursor cursor: RoyalVNCKit.VNCCursor) {
		vncView?.connection(connection, didUpdateCursor: cursor)
	}
}

struct VNCContentView: View {
	private let logger = Logger("VNCContentView")

	@State var appState: VNCConnectionAppState
	@State var window: NSWindow? = nil
	@State var needsResize: Bool = false
	@State var liveResizeWindow: Bool = false
	@State var screenSize: ViewSize

	var body: some View {
		GeometryReader { geom in
			self.appState.view(geom.size)
				.windowAccessor($window) {
					if let window = $0 {
						if self.needsResize {
							let size = self.appState.screenSize.cgSize

							DispatchQueue.main.async {
								self.setContentSize(size, window: window, animated: true)
							}
						}
					}
				}
				.frame(width: geom.size.width, height: geom.size.height)
				.onAppear {
					NSWindow.allowsAutomaticWindowTabbing = false
					if self.appState.allowClientResize {
						if let window = self.window {
							self.appState.setScreenSize(ViewSize(window.contentLayoutRect.size))
						} else {
							self.needsResize = true
						}
					}
				}.onReceive(NSWindow.willStartLiveResizeNotification) { notification in
					handleStartLiveResizeNotification(notification)
				}.onReceive(NSWindow.didEndLiveResizeNotification) { notification in
					handleDidResizeNotification(notification)
				}.onReceive(NSWindow.willCloseNotification) { notification in
					handleWillCloseNotification(notification)
				}.onGeometryChange(for: CGRect.self) { proxy in
					proxy.frame(in: .global)
				} action: { newValue in
					if self.needsResize == false && window != nil {
						self.setScreenSize(ViewSize(newValue.size))
					}
				}
		}
	}

	func isMyWindowKey(_ notification: Notification) -> Bool {
		if let window = notification.object as? NSWindow, window.windowNumber == self.window?.windowNumber {
			return true
		}

		return false
	}

	func handleStartLiveResizeNotification(_ notification: Notification) {
		if isMyWindowKey(notification) {
			#if DEBUG
				self.logger.debug("handleStartLiveResizeNotification: \(notification)")
			#endif

			self.liveResizeWindow = true
		}
	}

	func handleDidResizeNotification(_ notification: Notification) {
		if isMyWindowKey(notification) {
			#if DEBUG
				self.logger.debug("handleDidResizeNotification: \(notification)")
			#endif

			if self.liveResizeWindow {
				self.liveResizeWindow = false
				self.appState.setScreenSize(screenSize)
			}
		}
	}

	func handleWillCloseNotification(_ notification: Notification) {
		if isMyWindowKey(notification) {
			self.appState.disconnect()
		}
	}

	func setScreenSize(_ size: ViewSize) {
		self.screenSize = size

		if self.liveResizeWindow == false {
			self.appState.setScreenSize(size)
		}
	}

	func setContentSize(_ size: CGSize, window: NSWindow, animated: Bool) {
		let titleBarHeight: CGFloat = window.frame.height - window.contentLayoutRect.height
		var frame = window.frame

		frame = window.frameRect(forContentRect: NSMakeRect(frame.origin.x, frame.origin.y, size.width, size.height + titleBarHeight))
		frame.origin.y += window.frame.size.height
		frame.origin.y -= frame.size.height

		if frame != window.frame {
			window.setFrame(frame, display: true, animate: animated)
		}
	}
}

public struct VNCApp: App {
	static var state: VNCConnectionAppState!

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
	@State var appState: VNCConnectionAppState

	public init() {
		self.appState = VNCApp.state!
		self.appState.tryVNCConnect()
	}

	public var body: some Scene {
		WindowGroup(self.appState.name, id: "VM") {
			let allowClientResize = self.appState.allowClientResize

			VNCContentView(appState: self.appState, screenSize: appState.screenSize)
				.frame(
					minWidth: allowClientResize ? nil : CGFloat(appState.screenSize.width),
					idealWidth: CGFloat(appState.screenSize.width),
					maxWidth: allowClientResize ? .infinity : CGFloat(appState.screenSize.width),
					minHeight: allowClientResize ? nil : CGFloat(appState.screenSize.height),
					idealHeight: CGFloat(appState.screenSize.height),
					maxHeight: allowClientResize ? .infinity : CGFloat(appState.screenSize.height)
				)
				.presentedWindowToolbarStyle(.unifiedCompact)
				.windowMinimizeBehavior(allowClientResize ? .enabled : .disabled)
				.windowResizeBehavior(allowClientResize ? .enabled : .disabled)
				.windowFullScreenBehavior(allowClientResize ? .enabled : .disabled)
				.windowToolbarFullScreenVisibility(.onHover)
				.containerBackground(.windowBackground, for: .window)
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.defaultSize(CGSize(width: CGFloat(appState.screenSize.width), height: CGFloat(appState.screenSize.height)))
		.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			CommandGroup(replacing: .appInfo) { AboutApplication(config: self.appState.config) }
		}
	}

	public static func startVncClient(
		name: String,
		config: VirtualMachineConfiguration,
		vncURL: URL,
		screenSize: ViewSize,
		tunnel: VNCTunnel?,
		allowClientResize: Bool,
		isDebugLoggingEnabled: Bool = false,
		vmStatus: @escaping VNCConnectionAppState.VMStatusAction
	) throws {
		VNCApp.state = try VNCConnectionAppState(
			name: name,
			config: config,
			vncURL: vncURL,
			screenSize: screenSize,
			tunnel: tunnel,
			allowClientResize: allowClientResize,
			isDebugLoggingEnabled: isDebugLoggingEnabled,
			vmStatus: vmStatus
		)

		VNCApp.main()
	}
}
