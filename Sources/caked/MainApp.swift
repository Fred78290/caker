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

		vm.delegate = self
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

struct MainApp: App {
	static var cancellation: Cancellable?
	static var displayUI = false
	static var params: VMRunHandler!
	static var vm: VirtualMachine!

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

	var body: some Scene {
		MainWindow(params: Self.params, vm: Self.vm)
	}

	static func activate() {
		NSApp.activate()
	}

	static func runUI(_ vm: VirtualMachine, params: VMRunHandler, cancellation: Cancellable?) {
		MainApp.displayUI = true
		MainApp.params = params
		MainApp.vm = vm
		MainApp.cancellation = cancellation
		MainApp.main()
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
		.onAppear {
			// Fallback retry in case setDockIcon()'s activate() call at launch lost the race —
			// see the "Front-app activation workaround" note above AppDelegate.
			DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
				NSApp.activate()
			}
		}
	}
}

// MARK: - Front-app activation workaround
//
// When this process is launched via fork/exec from a terminal or shell script (as `caked
// provision --foreground` and similar are, rather than through Finder/LaunchServices), macOS
// does not automatically grant it frontmost/active status the way a normal GUI launch would.
// SwiftUI's `App`/`WindowGroup` alone doesn't compensate for this — the VM window can end up
// open but buried behind whatever else has focus, with no visible sign it opened at all.
//
// The three layers below are a deliberate belt-and-braces workaround, not redundant flourishes;
// each exists because the one before it wasn't reliably sufficient on its own across launch
// contexts observed in practice:
//   1. `setDockIcon()` (Extensions.swift) calls `NSApp.activate(ignoringOtherApps:)` immediately
//      from `applicationDidFinishLaunching`.
//   2. The splash `NSWindow` below is created at `.floating` level, so it visually surfaces
//      above other apps' windows even before this process becomes the system-designated
//      active app — activation state and window-server ordering aren't the same thing.
//   3. `SplashScreenView` schedules a delayed `NSApp.activate()` retry, in case (1) lost a race
//      against window-server/App Nap state still settling right after process launch.
//
// Once real activation lands (`applicationDidBecomeActive`), the splash window is torn down and
// the actual SwiftUI `WindowGroup` ("VM") is opened via `EnvironmentValues().openWindow(id:)` —
// used here specifically because `AppDelegate` isn't a View and has no SwiftUI environment to
// pull an `openWindow` action from any other way.
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	private var splashWindow: NSWindow? = nil

	func applicationDidBecomeActive(_ notification: Notification) {
		closeSplashWindowSingle()
	}

	func applicationWillTerminate(_ notification: Notification) {
		MainApp.cancellation?.cancel()
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		if MainApp.displayUI {
			NSApp.setDockIcon()
			self.showSplashWindow()
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

extension AppDelegate {
	private func showSplashWindow() {
		let size = NSSize(width: 320, height: 180)
		let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)

		window.isReleasedWhenClosed = false
		window.isOpaque = false
		window.backgroundColor = .clear
		window.hasShadow = true
		// .floating puts this above other apps' windows on the window server regardless of
		// whether this process is the active app yet — see the note above AppDelegate.
		window.level = .floating
		window.center()
		window.contentView = NSHostingView(rootView: SplashScreenView(name: MainApp.params.name))
		window.makeKeyAndOrderFront(self)

		self.splashWindow = window
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
