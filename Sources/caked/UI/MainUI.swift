import SwiftUI

class AppState: ObservableObject {
	@Published var currentVirtualMachine: VirtualMachine? = nil
}

struct MainUI: App {
	@StateObject var appState = AppState()

	@NSApplicationDelegateAdaptor private var appDelegate: MainUIAppDelegate

	var body: some Scene {
		DocumentGroup(newDocument: VirtualMachine()) { file in
			VirtualMachineView(appState: self.appState, document: file.$document)
		}.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			CommandGroup(replacing: .appInfo) { AboutCaker(config: appState.currentVirtualMachine?.config) }
			CommandMenu("Control") {
				Button("Start") {
					Task {
						appState.currentVirtualMachine?.startFromUI()
					}
				}
				Button("Stop") {
					Task {
						appState.currentVirtualMachine?.stopFromUI()
					}
				}
				Button("Request Stop") {
					Task {
						try appState.currentVirtualMachine?.requestStopFromUI()
					}
				}
			}
		}
	}
}

class MainUIAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		urls.forEach { u in print("Opening URL: \(u)") }
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		if kill(getpid(), SIGINT) == 0 {
			return .terminateLater
		} else {
			return .terminateNow
		}
	}
}
