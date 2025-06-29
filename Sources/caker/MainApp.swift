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
	@Environment(\.openWindow) var openWindow
	@Environment(\.openDocument) private var openDocument
	@Environment(\.newDocument) private var newDocument
	@StateObject var appState = AppState()
	@NSApplicationDelegateAdaptor(MainUIAppDelegate.self) var appDelegate

	var body: some Scene {
		/*DocumentGroup(newDocument: VirtualMachineDocument()) { file in
			VirtualMachineView(appState: self.appState, document: file.document)
		}*/

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
			/*CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})*/
			CommandGroup(replacing: .saveItem, addition: {})
			CommandGroup(replacing: .newItem) {
				Section {
					Button("New") {
						openWindow(id: "wizard")
						//newDocumentWizard()
					}.keyboardShortcut(KeyboardShortcut("N"))
					Button("Open") {
						open()
					}.keyboardShortcut(KeyboardShortcut("o"))
				}
			}
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
		Window("Choose Template", id: "wizard") {
			newDocWizard()
		}
		//WindowGroup("Configure VM", id: "settings", for: String.self) { $vmname in
		//	VirtualMachineSettingsView(vmname: vmname)
		//}
	}

	private func newDocumentWizard() {
		newDocument(VirtualMachineDocument())
	}

	private func open() {
		if let documentURL = FileHelpers.selectSingleInputFile(ofType: [.virtualMachine], withTitle: "Open virtual machine") {
			Task {
				try? await openDocument(at: documentURL)
			}
		}
	}

	func newDocWizard() -> some View {
		VirtualMachineWizard()
	}
}

class MainUIAppDelegate: NSObject, NSApplicationDelegate {
	override init() {
		super.init()

		print("delegate")
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		print(#function)
	}

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		urls.forEach { u in print("Opening URL: \(u)") }
	}
}
