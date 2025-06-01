import SwiftUI

class AppState: ObservableObject {
	@Published var currentDocument: VirtualMachineDocument? = nil
}

struct MainUI: App {
	@StateObject var appState = AppState()

	@NSApplicationDelegateAdaptor private var appDelegate: MainUIAppDelegate

	var body: some Scene {
		WindowGroup {
			MainView()
		}.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
		}
		DocumentGroup(viewing: VirtualMachineDocument.self) { file in
			if let fileURL = file.fileURL {
				if file.document.loadVirtualMachine(from: fileURL) {
					VirtualMachineView(appState: self.appState, document: file.$document)
				} else {
					Color.black
				}
			} else {
				Color.red
			}
		}.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			CommandMenu("Control") {
				Button("Start") {
					Task {
						appState.currentDocument?.startFromUI()
					}
				}
				Button("Stop") {
					Task {
						appState.currentDocument?.stopFromUI()
					}
				}
				Button("Request Stop") {
					Task {
						try appState.currentDocument?.requestStopFromUI()
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

	/*func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		if kill(getpid(), SIGINT) == 0 {
			return .terminateLater
		} else {
			return .terminateNow
		}
	}*/
}
