//
//  VNCApp.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/03/2026.
//
import ArgumentParser
import SwiftUI
import RoyalVNCKit
import CakeAgentLib
import RoyalVNCKit
import GRPCLib

struct VNCView: NSViewRepresentable {
	typealias NSViewType = NSVNCView
	
	private let appState: VNCConnectionAppState
	private let logger = Logger("HostVirtualMachineView")
	
	init(_ appState: VNCConnectionAppState) {
		self.appState = appState
	}
	
	func makeCoordinator() -> VNCConnectionAppState {
		return appState
	}
	
	func makeNSView(context: Context) -> NSViewType {
		guard let framebuffer = appState.connection.framebuffer else {
			fatalError("framebuffer is nil")
		}
		
		let view = NSVNCView(frame: CGRectMake(0, 0, framebuffer.cgSize.width, framebuffer.cgSize.height), connection: self.appState.connection)
		
		self.appState.vncView = view

#if DEBUG
		self.logger.trace("makeNSView: \(view.frame), \(framebuffer.cgSize)")
#endif
		
		return view
	}
	
	func updateNSView(_ nsView: NSVNCView, context: Context) {
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.regular)
	}
}

@Observable
class VNCConnectionAppState: RoyalVNCKit.VNCConnectionDelegate, Codable {
	typealias VncStatusStream = (stream: AsyncThrowingStream<VncStatus, Error>, continuation: AsyncThrowingStream<VncStatus, Error>.Continuation)
	typealias VncStatusStreamContinuation = AsyncThrowingStream<VncStatus, Error>.Continuation

	enum VncStatus: Int {
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

	let config: VirtualMachineConfiguration
	let vncLogger: VNCConnectionLogger
	let username: String?
	let password: String?
	let vmStatus: VNCApp.VMStatusAction
	let screenSizeAction: VNCApp.VNCSetScreenSizeAction?
	let settings: RoyalVNCKit.VNCConnection.Settings
	var continuation: VncStatusStreamContinuation? = nil
	var connection: RoyalVNCKit.VNCConnection! = nil
	var vncView: NSVNCView? = nil
	var vncStatus: VncStatus
	var screenSize: ViewSize

	static var state: VNCConnectionAppState!

	init(name: String,
		 config: VirtualMachineConfiguration,
		 vncURL: URL,
		 screenSize: ViewSize,
		 isDebugLoggingEnabled: Bool = false,
		 vmStatus: @escaping VNCApp.VMStatusAction,
		 screenSizeAction: VNCApp.VNCSetScreenSizeAction? = nil) throws {

		guard let vncPort = vncURL.port, let vncHost = vncURL.host(percentEncoded: false) else {
			throw ServiceError("VM \(name) does not have a VNC connection")
		}

		// Create settings
		self.settings = RoyalVNCKit.VNCConnection.Settings(
			isDebugLoggingEnabled: isDebugLoggingEnabled,
			hostname: vncHost,
			port: UInt16(vncPort),
			isShared: true,
			isScalingEnabled: true,
			useDisplayLink: false,
			inputMode: .none,
			isClipboardRedirectionEnabled: false,
			colorDepth: .depth24Bit,
			frameEncodings: .default)

		self.vncLogger = VNCConnectionLogger(isDebugLoggingEnabled)
		self.username = vncURL.user(percentEncoded: false)
		self.password = vncURL.password(percentEncoded: false)
		self.connection = nil
		self.vncStatus = .disconnected
		self.screenSize = screenSize
		self.config = config
		self.screenSizeAction = screenSizeAction
		self.vmStatus = vmStatus
	}

	required init(from decoder: any Decoder) throws {
		throw ValidationError("Unimplemented")
	}

	func encode(to encoder: any Encoder) throws {
		throw ValidationError("Unimplemented")
	}

	func tryVNCConnect() {
		guard self.connection == nil else {
			return
		}

		self.connection = RoyalVNCKit.VNCConnection(settings: self.settings, logger: vncLogger)
		self.connection.delegate = self
		self.connection.connect()
	}

	func connect() async throws {
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
				self.vncLogger.logDebug("VNC Connected to VM")
				break
			}
		}
	}

	func setScreenSize(_ screenSize: ViewSize) {
		self.screenSize = screenSize
		
		self.screenSizeAction?(screenSize)
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, stateDidChange connectionState: RoyalVNCKit.VNCConnection.ConnectionState) {
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
					}
				} else {
					self.vncView = nil
				}
			}

			self.vncStatus = newStatus

			if let continuation = self.continuation {
				if newStatus == .disconnecting || newStatus == .disconnected {
					continuation.finish(throwing: ServiceError("VNC disconnected unexpectedly"))
				}

				continuation.yield(newStatus)
			}
		})
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, credentialFor authenticationType: RoyalVNCKit.VNCAuthenticationType, completion: @escaping ((any RoyalVNCKit.VNCCredential)?) -> Void) {
		let authenticationTypeString: String

		var credential: RoyalVNCKit.VNCCredential? = nil

		func readInput(_ prompt: String) -> String? {
			print(prompt, terminator: "")

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

		connection.logger.logDebug("connection credentialFor: \(authenticationTypeString)")

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

	func connection(_ connection: RoyalVNCKit.VNCConnection, didCreateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		if self.vncStatus != .ready {
			DispatchQueue.main.async {
				self.vncLogger.logDebug("vnc ready")
				self.screenSize = ViewSize(framebuffer.cgSize)
				self.vncStatus = .ready
			}
		}

	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, didResizeFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer) {
		if framebuffer.size.width != 8192 && framebuffer.size.height != 4320 {
			self.vncView?.connection(connection, didResizeFramebuffer: framebuffer)

			DispatchQueue.main.async {
				self.screenSize = .init(framebuffer.cgSize)
			}
		}
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateFramebuffer framebuffer: RoyalVNCKit.VNCFramebuffer, x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
		self.vncView?.connection(connection, didUpdateFramebuffer: framebuffer, x: x, y: y, width: width, height: height)
	}

	func connection(_ connection: RoyalVNCKit.VNCConnection, didUpdateCursor cursor: RoyalVNCKit.VNCCursor) {
		vncView?.connection(connection, didUpdateCursor: cursor)
	}
}

struct VNCContentView: View {
	private let logger = Logger("VNCContentView")

	@State var appState: VNCConnectionAppState
	@State var window: NSWindow? = nil
	@State var needsResize: Bool = false
	@State var liveResizeWindow: Bool = false

	var body: some View {
		GeometryReader { geom in
			self.vncView(geom.size)
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

					if let window = self.window {
						self.appState.setScreenSize(ViewSize(window.contentLayoutRect.size))
					} else {
						self.needsResize = true
					}
				}.onReceive(NSWindow.willStartLiveResizeNotification) { notification in
					handleStartLiveResizeNotification(notification)
				}.onReceive(NSWindow.didEndLiveResizeNotification) { notification in
					handleDidResizeNotification(notification)
				}.onGeometryChange(for: CGRect.self) { proxy in
					proxy.frame(in: .global)
				} action: { newValue in
					if self.needsResize == false && self.liveResizeWindow == false && window != nil {
						self.appState.setScreenSize(ViewSize(newValue.size))
					}
				}
		}
	}

	@ViewBuilder
	func vncView(_ size: CGSize) -> some View{
		switch self.appState.vncStatus {
		case .connecting:
			LabelView("Connecting to VNC", size: size, progress: true)
		case .disconnected:
			LabelView("VNC not connected", size: size)
		case .connected:
			LabelView("VNC connected", size: size)
		case .disconnecting:
			LabelView("VNC disconnecting", size: size)
		case .ready:
			VNCView(self.appState)
				.frame(width: size.width, height: size.height)
				.background(.black)
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
			}
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
	public typealias VNCSetScreenSizeAction = (ViewSize) -> Void
	public typealias VMStatusAction = () -> Status

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
	@State var appState: VNCConnectionAppState
	
	public init() {
		self.appState = VNCConnectionAppState.state!
		self.appState.tryVNCConnect()
	}
	
	public var body: some Scene {
		WindowGroup {
			VNCContentView(appState: self.appState)
				.frame(idealWidth: CGFloat(appState.screenSize.width), maxWidth: .infinity, idealHeight: CGFloat(appState.screenSize.height), maxHeight: .infinity)
				.presentedWindowToolbarStyle(.unifiedCompact)
				.windowMinimizeBehavior(.enabled)
				.windowResizeBehavior(.enabled)
				.windowFullScreenBehavior(.enabled)
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
	
	public static func startVncClient(name: String,
									  config: VirtualMachineConfiguration,
									  vncURL: URL,
									  screenSize: ViewSize,
									  isDebugLoggingEnabled: Bool = false,
									  vmStatus: @escaping VMStatusAction,
									  screenSizeAction: VNCSetScreenSizeAction? = nil) async throws {
		VNCConnectionAppState.state = try VNCConnectionAppState(
			name: name,
			config: config,
			vncURL: vncURL,
			screenSize: screenSize,
			isDebugLoggingEnabled: isDebugLoggingEnabled,
			vmStatus: vmStatus,
			screenSizeAction: screenSizeAction
		)
		
		// Connect
		try await VNCConnectionAppState.state.connect()

		await MainActor.run {
			VNCApp.main()
		}
	}
}
