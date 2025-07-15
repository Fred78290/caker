import Foundation
import SwiftUI
import Virtualization
import CakedLib

struct AppState {
	var status: VMLocation.Status
	var isStopped: Bool
	var isSuspendable: Bool
	var isRunning: Bool
	var isPaused: Bool
	
	init(_ vm: VirtualMachine) {
		self.status = vm.status

		self.isStopped = status == .stopped
		self.isRunning = status == .running
		self.isPaused = status == .suspended
		self.isSuspendable = status == .running && vm.suspendable
	}
	
	mutating func update(vm: VirtualMachine) {
		self.status = vm.status
		
		self.isStopped = status == .stopped
		self.isRunning = status == .running
		self.isPaused = status == .suspended
		self.isSuspendable = status == .running && vm.suspendable
	}
}

struct MainApp: App, VirtualMachineDelegate {
	static var _vm: VirtualMachine? = nil
	static var _config: CakeConfig? = nil
	static var _name: String? = nil
	static var _virtualMachine: VZVirtualMachine? = nil

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
		WindowGroup(MainApp.name) {
			let display = MainApp.config.display
			let minWidth = CGFloat(display.width)
			let idealWidth = CGFloat(display.width)
			let minHeight = CGFloat(display.height)
			let idealHeight = CGFloat(display.height)

			Group {
				VMView(automaticallyReconfiguresDisplay: MainApp.config.displayRefit || (MainApp.config.os == .darwin), vm: MainApp.vm, virtualMachine: MainApp.virtualMachine).onAppear {
					NSWindow.allowsAutomaticWindowTabbing = false
				}.onDisappear {
					if kill(getpid(), SIGINT) != 0 {
						NSApplication.shared.terminate(self)
					}
				}
			}.toolbar {
				ToolbarItemGroup(placement: .navigation) {
					if self.appState.status == .running {
						Button("Stop", systemImage: "stop.circle") {
							self.requestStopFromUI()
						}.help("Stop virtual machine")
					} else if self.appState.status == .suspended {
						Button("Resume", systemImage: "playpause.circle") {
							self.startFromUI()
						}.help("Resumes virtual machine")
					} else {
						Button("Start", systemImage: "power.circle") {
							self.startFromUI()
						}.help("Start virtual machine")
					}
					
					Button("Pause", systemImage: "pause.circle") {
						self.suspendFromUI()
					}
					.help("Suspends virtual machine")
					.disabled(self.appState.isSuspendable == false)
					
					Button("Restart", systemImage: "restart.circle") {
						self.stopFromUI()
					}
					.help("Restarts virtual machine")
					.disabled(self.appState.isStopped)
				}
			}.onChange(of: self.appState.status) { newValue in
				Logger(self).info("New status: \(newValue)")
			}.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: idealHeight, maxHeight: .infinity)
		}.commands {
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

				Button("Suspend") {
					Task { self.suspendFromUI() }
				}.disabled(self.appState.isSuspendable == false)

				Button("Request Stop") {
					Task { self.requestStopFromUI() }
				}.disabled(self.appState.isStopped)
			}
		}
	}

	func startFromUI() {
		MainApp._vm?.startFromUI()
	}

	func stopFromUI() {
		MainApp._vm?.stopFromUI()
	}

	func requestStopFromUI() {
		try? MainApp._vm?.requestStopFromUI()
	}

	func suspendFromUI() {
		MainApp._vm?.suspendFromUI()
	}

	func didChangedState(_ vm: VirtualMachine) {
		self.appState.update(vm: vm)
	}

	static func runUI(name: String, vm: VirtualMachine, config: CakeConfig) {
		MainApp.vm = vm
		MainApp.virtualMachine = vm.getVM()
		MainApp.name = name
		MainApp.config = config
		MainApp.main()
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.regular)
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
