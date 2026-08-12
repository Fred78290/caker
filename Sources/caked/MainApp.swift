import CakeAgentLib
import CakedLib
import Combine
import Foundation
import SwiftUI
import Virtualization

class AppState: ObservableObject, Observable, VirtualMachineDelegate {
	@Published var status: VMLocation.Status
	@Published var isStopped: Bool
	@Published var isSuspendable: Bool
	@Published var isRunning: Bool
	@Published var isPaused: Bool

	init(_ vm: VirtualMachine) {
		let status = vm.status

		self.status = status
		self.isStopped = status == .stopped
		self.isRunning = status.isRunning
		self.isPaused = status == .paused
		self.isSuspendable = status.isRunning && vm.suspendable
	}

	func update(vm: VirtualMachine) {
		self.status = vm.status
		self.isStopped = status == .stopped
		self.isRunning = status.isRunning
		self.isPaused = status == .paused
		self.isSuspendable = status.isRunning && vm.suspendable
	}

	func didChangedState(_ vm: VirtualMachine) {
		self.update(vm: vm)
	}

	func didScreenshot(_ vm: VirtualMachine, screenshot: NSImage) {
		try? screenshot.pngData?.write(to: vm.location.screenshotURL)
	}
}

enum RestorationStateBehavior: String {
	case disabled
	case automatic
}

extension Scene {
	func restorationState(_ restoreState: RestorationStateBehavior = .disabled) -> some Scene {
		if #available(macOS 15.0, *) {
			return self.restorationBehavior(restoreState == .automatic ? .automatic : .disabled)
		}

		return self
	}
}

struct MainWindow: Scene {
	private var params: VMRunHandler
	private var vm: VirtualMachine

	@State private var appState: AppState

	init(params: VMRunHandler, vm: VirtualMachine) {
		let appState = AppState(vm)

		vm.delegate = appState

		self.init(params: params, vm: vm, appState: appState)
	}

	init(params: VMRunHandler, vm: VirtualMachine, appState: AppState) {
		self.params = params
		self.vm = vm
		self.appState = appState
	}

	var body: some Scene {
		let display = self.params.config.display
		let minWidth = CGFloat(display.width)
		let idealWidth = CGFloat(display.width)
		let minHeight = CGFloat(display.height)
		let idealHeight = CGFloat(display.height)

		WindowGroup(self.params.name, id: "VM") {
			VMView(self.vm, params: self.params)
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
						#if DEBUG
							Button("Screenshot", systemImage: "photo") {
								self.takeScreenshot()
							}.help("Take a screenshot")
						#endif

						if self.appState.status.isRunning {
							Button("Stop", systemImage: "stop") {
								self.requestStopFromUI()
							}.help("Stop virtual machine")
						} else if self.appState.status == .paused {
							Button("Resume", systemImage: "playpause") {
								self.startFromUI()
							}.help("Resume virtual machine")
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
		.restorationState()
		.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			CommandGroup(replacing: .appInfo) { AboutApplication(config: self.params.config) }
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
		
		Window("About", id: "about") {
			AboutApplication(config: self.params.config)
		}.windowResizability(.contentSize)
	}

	var menu: some View {
		Group {
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

	#if DEBUG
		func takeScreenshot() {
			self.vm.takeScreenshotDebug()
		}
	#endif

	func startFromUI() {
		self.vm.startFromUI()
	}

	func restartFromUI() {
		self.vm.restartFromUI()
	}

	func stopFromUI() {
		self.vm.stopFromUI()
	}

	func requestStopFromUI() {
		self.vm.requestStopFromUI()
	}

	func suspendFromUI() {
		self.vm.suspendFromUI()
	}
}

@available(macOS 26.0, *)
final class VirtualMachineRepresentation: NSHostingSceneRepresentation<MainWindow> {
	init(params: VMRunHandler, vm: VirtualMachine, appState: AppState) {
		super.init {
			MainWindow(params: params, vm: vm, appState: appState)
		}
	}
}

struct MainApp: App {
	static var cancellation: Cancellable?
	static var displayUI = false
	static var params: VMRunHandler!
	static var vm: VirtualMachine!

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

	var body: some Scene {
		MainWindow(params: Self.params, vm: Self.vm)
	}

	static func runUI(_ vm: VirtualMachine, params: VMRunHandler, cancellation: Cancellable?) {
		MainApp.displayUI = true
		MainApp.params = params
		MainApp.vm = vm
		MainApp.cancellation = cancellation

		if #available(macOS 26.0, *) {
			let delegate = AppDelegate(params: params, vm: vm, cancellation: cancellation)

			NSApp.delegate = delegate
			NSApp.setDockIcon()
			NSApp.run()
		} else {
			MainApp.main()
		}
	}
}

private struct SplashScreenView: View {
	let name: String

	var body: some View {
		VStack(spacing: 12) {
			Image(nsImage: NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)!)
				.resizable()
				.frame(width: 64, height: 64)

			Text(name)
				.font(.headline)

			ProgressView()
				.controlSize(.small)
		}
		.padding(24)
		.frame(width: 320, height: 180)
		.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	private var splashWindow: NSWindow?
	private var params: VMRunHandler?
	private var vm: VirtualMachine?
	private var cancellation: Cancellable?
	private var displayVM: (() -> Void)?
	private var displayAbout: (() -> Void)?

	@available(macOS 26.0, *)
	init(params: VMRunHandler, vm: VirtualMachine, cancellation: Cancellable?) {
		self.params = params
		self.vm = vm
		self.cancellation = cancellation
	}

	func applicationDidBecomeActive(_ notification: Notification) {
		if #available(macOS 26.0, *) {
			closeSplashWindow()
		}
	}

	func applicationWillTerminate(_ notification: Notification) {
		MainApp.cancellation?.cancel()
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		if MainApp.displayUI {
			NSApp.setDockIcon()

			if #available(macOS 26.0, *), let params, let vm {
				self.showSplashWindow(params: params, vm: vm)
			}
		}
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		guard let vm = MainApp.vm, vm.status.isRunning else {
			return .terminateNow
		}

		let alert = NSAlert()

		alert.messageText = String(localized: "Virtual machine Running")
		alert.informativeText = String(localized: "The virtual machine is running. Do you want terminate it them and quit?")
		alert.alertStyle = .warning
		alert.addButton(withTitle: String(localized: "Terminate & Quit"))
		alert.addButton(withTitle: String(localized: "Cancel"))

		if alert.runModal() == .alertFirstButtonReturn {
			Task {
				if vm.suspendable {
					vm.suspendFromUI { _ in
						sender.reply(toApplicationShouldTerminate: true)
					}
				} else {
					vm.requestStopFromUI { _ in
						sender.reply(toApplicationShouldTerminate: true)
					}
				}
			}

			return .terminateLater
		}

		return .terminateCancel
	}
}

@available(macOS 26.0, *)
extension AppDelegate {
	private func showSplashWindow(params: VMRunHandler, vm: VirtualMachine) {
		let size = NSSize(width: 320, height: 180)
		let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)

		window.isReleasedWhenClosed = false
		window.isOpaque = false
		window.backgroundColor = .clear
		window.hasShadow = true
		window.level = .floating
		window.center()
		window.contentView = NSHostingView(rootView: SplashScreenView(name: MainApp.params.name))
		window.makeKeyAndOrderFront(self)

		self.splashWindow = window

		let appState = AppState(vm)

		vm.delegate = appState

		MainActor.assumeIsolated {
			let scene = VirtualMachineRepresentation(params: params, vm: vm, appState: appState)
			NSApp.addSceneRepresentation(scene)

			self.displayVM = {
				scene.environment.openWindow(id: "VM")
			}

			self.displayAbout = {
				scene.environment.openWindow(id: "about")
			}

			NSApp.mainMenu = self.makeMainMenu(params: params, vm: vm, appState: appState)
		}
	}

	private func makeMainMenu(params: VMRunHandler, vm: VirtualMachine, appState: AppState) -> NSMenu {
		let mainWindow = MainWindow(params: params, vm: vm, appState: appState)
		let mainMenu = NSMenu()

		let appMenuItem = NSMenuItem()

		appMenuItem.submenu = NSHostingMenu(rootView: Group {
			Button("About \(params.name)") { [weak self] in
				self?.displayAbout?()
			}

			Divider()

			Button("Quit \(params.name)") {
				NSApp.terminate(nil)
			}.keyboardShortcut("q")
		})

		let controlMenuItem = NSMenuItem(title: String(localized: "Control"), action: nil, keyEquivalent: "")

		controlMenuItem.submenu = NSHostingMenu(rootView: mainWindow.menu)

		mainMenu.addItem(appMenuItem)
		mainMenu.addItem(controlMenuItem)

		return mainMenu
	}

	func closeSplashWindow() {
		guard let window = self.splashWindow else {
			return
		}

		self.splashWindow = nil
		window.orderOut(self)
		window.close()

		if let displayVM {
			displayVM()
		}
	}


}
