import SwiftUI

class AppState: ObservableObject {
	@Published var currentDocument: VirtualMachineDocument?
	@Published var isStopped: Bool = true
	@Published var isSuspendable: Bool = false
	@Published var isRunning: Bool = false
	@Published var isPaused: Bool = false
}

@main
struct MainApp: App {
	@StateObject var appState = AppState()
	@AppStorage("vmstopped") var isStopped: Bool = true
	@AppStorage("vmsuspendable") var isSuspendable: Bool = false
	@AppStorage("vmrunning") var isRunning: Bool = false
	@AppStorage("vmpaused") var isPaused: Bool = false

	@NSApplicationDelegateAdaptor private var appDelegate: MainUIAppDelegate

	var body: some Scene {
		DocumentGroup(viewing: VirtualMachineDocument.self) { file in
			if let fileURL = file.fileURL {
				if file.document.loadVirtualMachine(from: fileURL) {
					VirtualMachineView(appState: self.appState, document: file.document)
				} else {
					Color.black
				}
			} else {
				Color.red
			}
		}
		.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			CommandMenu("Control") {
				Button("Start") {
					appState.currentDocument?.startFromUI()
				}.disabled(appState.isRunning || appState.currentDocument == nil)

				Button("Stop") {
					appState.currentDocument?.stopFromUI()
				}.disabled(appState.isStopped || appState.currentDocument == nil)

				Button("Request Stop") {
					appState.currentDocument?.requestStopFromUI()
				}.disabled(appState.isStopped || appState.currentDocument == nil)

				if #available(macOS 14, *) {
					Button("Suspend") {
						appState.currentDocument?.suspendFromUI()
					}.disabled(!appState.isSuspendable || appState.currentDocument == nil)
				}
			}
		}

		WindowGroup("Configure VM", id: "settings", for: String.self) { $vmname in
			VirtualMachineSettingsView(vmname: vmname)
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
