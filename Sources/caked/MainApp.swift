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
	static var params: VMRunHandler!
	static var vm: VirtualMachine!

	@State var appState: AppState

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

	init() {
		self.appState = AppState(Self.vm)
		Self.vm.delegate = self
	}

	var body: some Scene {
		let display = MainApp.params.config.display
		let minWidth = CGFloat(display.width)
		let idealWidth = CGFloat(display.width)
		let minHeight = CGFloat(display.height)
		let idealHeight = CGFloat(display.height)

		WindowGroup(MainApp.params.name) {
			VMView(MainApp.vm, params: MainApp.params)
				.onAppear {
					NSWindow.allowsAutomaticWindowTabbing = false
				}
				.onDisappear {
					if kill(getpid(), SIGINT) != 0 {
						NSApplication.shared.terminate(self)
					}
				}
				#if DEBUG
					.onChange(of: self.appState.status) { _, newValue in
						Logger(self).debug("New status: \(newValue)")
					}
				#endif
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
			CommandGroup(replacing: .appInfo) { AboutCaker(config: MainApp.params.config) }
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
		MainApp.vm.startFromUI()
	}

	func restartFromUI() {
		MainApp.vm.restartFromUI()
	}

	func stopFromUI() {
		MainApp.vm.stopFromUI()
	}

	func requestStopFromUI() {
		MainApp.vm.requestStopFromUI()
	}

	func suspendFromUI() {
		MainApp.vm.suspendFromUI()
	}

	func didChangedState(_ vm: VirtualMachine) {
		self.appState.update(vm: vm)
	}

	func didScreenshot(_ vm: CakedLib.VirtualMachine, screenshot: NSImage) {
		try? screenshot.pngData?.write(to: vm.location.screenshotURL)
	}

	static func runUI(_ vm: VirtualMachine, params: VMRunHandler) {
		MainApp.displayUI = true
		MainApp.params = params
		MainApp.vm = vm
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
