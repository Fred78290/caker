import SwiftUI

class AppState: ObservableObject {
	@Published var currentDocument: VirtualMachineDocument? = nil
}

struct MainUI: App {
	@StateObject var appState = AppState()

	@NSApplicationDelegateAdaptor private var appDelegate: MainUIAppDelegate

	enum ControlMenuItem {
		case start
		case suspend
		case stop
		case requestStop
	}

	func controlMenuDisabled(_ menuItem: ControlMenuItem) -> Bool {
		guard let currentDocument = appState.currentDocument else {
			return true
		}
		
		let vmStatus = currentDocument.status

		if vmStatus == .none {
			return true
		}

		switch menuItem {
		case .start:
			return !currentDocument.canStart
		case .suspend:
			return !(currentDocument.canPause && currentDocument.suspendable)
		case .stop:
			return !currentDocument.canStop
		case .requestStop:
			return !currentDocument.canRequestStop
		}
	}

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
				}.disabled(
					self.controlMenuDisabled(.start)
				)
				Button("Stop") {
					Task {
						appState.currentDocument?.stopFromUI()
					}
				}.disabled(
					self.controlMenuDisabled(.stop)
				)
				Button("Request Stop") {
					Task {
						appState.currentDocument?.requestStopFromUI()
					}
				}.disabled(
					self.controlMenuDisabled(.requestStop)
				)
				if #available(macOS 14, *) {
					Button("Suspend") {
						Task {
							appState.currentDocument?.suspendFromUI()
						}
					}.disabled(
						self.controlMenuDisabled(.suspend)
					)
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
}
