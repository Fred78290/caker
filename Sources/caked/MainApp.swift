import CakedLib
import Foundation
import SwiftUI
import Virtualization

class AppState: ObservableObject, Observable {
	@Published var status: VMLocation.Status
	@Published var isStopped: Bool
	@Published var isSuspendable: Bool
	@Published var isRunning: Bool
	@Published var isPaused: Bool

	init(_ vm: VirtualMachine) {
		let status = vm.status

		self.status = status
		self.isStopped = status == .stopped
		self.isRunning = status == .running
		self.isPaused = status == .paused
		self.isSuspendable = status == .running && vm.suspendable
	}

	func update(vm: VirtualMachine) {
		self.status = vm.status

		self.isStopped = status == .stopped
		self.isRunning = status == .running
		self.isPaused = status == .paused
		self.isSuspendable = status == .running && vm.suspendable
	}
}

struct MainApp: App, VirtualMachineDelegate {
	static var displayUI = false
	static var vncPassword: String? = nil
	static var vncPort: Int? = nil
	static var captureMethod: VNCCaptureMethod = .coreGraphics
	static var _vm: VirtualMachine? = nil
	static var _config: CakeConfig? = nil
	static var _name: String? = nil
	static var _virtualMachine: VZVirtualMachine? = nil
	static var _display: VMRunHandler.DisplayMode? = nil

	@State var appState: AppState

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

	init() {
		self.appState = AppState(Self._vm!)
		Self._vm?.delegate = self
	}

	static var virtualMachine: VZVirtualMachine {
		get {
			return _virtualMachine!
		}
		set {
			_virtualMachine = newValue
		}
	}

	static var display: VMRunHandler.DisplayMode {
		get {
			return _display!
		}
		set {
			_display = newValue
		}
	}

	static var name: String {
		get {
			return _name!
		}
		set {
			_name = newValue
		}
	}

	static var config: CakeConfig {
		get {
			return _config!
		}
		set {
			_config = newValue
		}
	}

	static var vm: VirtualMachine {
		get {
			return _vm!
		}
		set {
			_vm = newValue
		}
	}

	var body: some Scene {
		let display = MainApp.config.display
		let minWidth = CGFloat(display.width)
		let idealWidth = CGFloat(display.width)
		let minHeight = CGFloat(display.height)
		let idealHeight = CGFloat(display.height)

		WindowGroup(MainApp.name) {
			VMView(MainApp.display, automaticallyReconfiguresDisplay: MainApp.config.displayRefit || (MainApp.config.os == .darwin), vm: MainApp.vm, vncPassword: MainApp.vncPassword, vncPort: MainApp.vncPort, captureMethod: MainApp.captureMethod)
				.onAppear {
					NSWindow.allowsAutomaticWindowTabbing = false
				}
				.onDisappear {
					if kill(getpid(), SIGINT) != 0 {
						NSApplication.shared.terminate(self)
					}
				}
				.onChange(of: self.appState.status) { _, newValue in
					Logger(self).debug("New status: \(newValue)")
				}
				.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: idealHeight, maxHeight: .infinity)
				.toolbar {
					ToolbarItemGroup(placement: .navigation) {
						if self.appState.status == .running {
							Button("Stop", systemImage: "stop") {
								self.requestStopFromUI()
							}.help("Stop virtual machine")
						} else if self.appState.status == .paused {
							Button("Resume", systemImage: "playpause") {
								self.startFromUI()
							}.help("Resumes virtual machine")
						} else {
							Button("Start", systemImage: "power") {
								self.startFromUI()
							}.help("Start virtual machine")
						}

						Button("Pause", systemImage: "pause") {
							self.suspendFromUI()
						}
						.help("Suspends virtual machine")
						.disabled(self.appState.isSuspendable == false)

						Button("Restart", systemImage: "restart") {
							self.restartFromUI()
						}
						.help("Restarts virtual machine")
						.disabled(self.appState.isStopped)
					}
				}
				.presentedWindowToolbarStyle(.unifiedCompact)
				.windowToolbarFullScreenVisibility(.onHover)
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.defaultSize(CGSize(width: idealWidth, height: idealHeight))
		.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			CommandGroup(replacing: .appInfo) { AboutCaker(config: MainApp.config) }
			CommandMenu("Control") {
				Button("Start") {
					Task { self.startFromUI() }
				}.disabled(self.appState.isRunning)

				Button("Stop") {
					Task { self.stopFromUI() }
				}.disabled(self.appState.isStopped)

				Button("Request Stop") {
					Task { self.requestStopFromUI() }
				}.disabled(self.appState.isStopped)

				Button("Suspend") {
					Task { self.suspendFromUI() }
				}.disabled(self.appState.isSuspendable == false)
			}
		}
	}

	func startFromUI() {
		MainApp._vm?.startFromUI()
	}

	func restartFromUI() {
		MainApp._vm?.restartFromUI()
	}

	func stopFromUI() {
		MainApp._vm?.stopFromUI()
	}

	func requestStopFromUI() {
		MainApp._vm?.requestStopFromUI()
	}

	func suspendFromUI() {
		MainApp._vm?.suspendFromUI()
	}

	func didChangedState(_ vm: VirtualMachine) {
		self.appState.update(vm: vm)
	}

	func didScreenshot(_ vm: CakedLib.VirtualMachine, data: NSImage) {
		try? vm.saveScreenshot()
	}

	static func runUI(_ display: VMRunHandler.DisplayMode, name: String, vm: VirtualMachine, config: CakeConfig, vncPassword: String, vncPort: Int?, captureMethod: VNCCaptureMethod) {
		MainApp.displayUI = true
		MainApp.vncPort = vncPort
		MainApp.vncPassword = vncPassword
		MainApp.captureMethod = captureMethod
		MainApp.display = display
		MainApp.vm = vm
		MainApp.virtualMachine = vm.getVM()
		MainApp.name = name
		MainApp.config = config
		MainApp.main()
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	func applicationDidFinishLaunching(_ notification: Notification) {
		if MainApp.displayUI {
			NSApp.setActivationPolicy(.regular)
		}
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		if kill(getpid(), SIGINT) == 0 {
			return .terminateLater
		} else {
			return .terminateNow
		}
	}
}

struct AboutCaker: View {
	var infos: NSAttributedString

	init(config: CakeConfig) {
		let infos = NSMutableAttributedString()
		let style: NSMutableParagraphStyle = NSMutableParagraphStyle()

		style.alignment = NSTextAlignment.center

		let center: [NSAttributedString.Key: Any] = [.paragraphStyle: style]

		infos.append(NSAttributedString(string: "CPU: \(config.cpuCount) cores\n", attributes: center))
		infos.append(NSAttributedString(string: "Memory: \(ByteCountFormatter.string(fromByteCount: Int64(config.memorySize), countStyle: .memory))\n", attributes: center))
		infos.append(NSAttributedString(string: "User: \(config.configuredUser)\n", attributes: center))

		if let runningIP = config.runningIP {
			infos.append(NSAttributedString(string: "IP: \(runningIP)\n", attributes: center))
		}

		self.infos = infos
	}

	var body: some View {
		Button("About Caked") {
			NSApplication.shared.orderFrontStandardAboutPanel(options: [
				NSApplication.AboutPanelOptionKey.applicationIcon: NSApplication.shared.applicationIconImage as Any,
				NSApplication.AboutPanelOptionKey.applicationName: "Caked",
				NSApplication.AboutPanelOptionKey.applicationVersion: CI.version,
				NSApplication.AboutPanelOptionKey.credits: self.infos,
			])
		}
	}
}
