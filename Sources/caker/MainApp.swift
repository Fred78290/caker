import SwiftUI
import CakedLib
import GRPCLib

struct Defaults {
	static func currentFont() -> NSFont {
		guard let name = UserDefaults.standard.object(forKey: "fontName") as? String else {
			return NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
		}
		
		let size = CGFloat(UserDefaults.standard.float(forKey: "fontSize"))
		guard let font = NSFont(name: name, size: size) else {
			return NSFont.systemFont(ofSize: NSFont.systemFontSize)
		}
		
		return font
	}
	
	static func saveCurrentFont(name: String, size: Float) {
		UserDefaults.standard.set(name, forKey: "fontName")
		UserDefaults.standard.set(size, forKey: "fontSize")
	}
	
	static func saveCurrentFont(_ font: NSFont) {
		saveCurrentFont(name: font.fontName, size: Float(font.pointSize))
	}
}

@main
struct MainApp: App {
	@Environment(\.openWindow) var openWindow
	@Environment(\.openDocument) private var openDocument
	@Environment(\.newDocument) private var newDocument
	@State var appState = AppState.shared
	@State var createTemplate = false

	@NSApplicationDelegateAdaptor(MainUIAppDelegate.self) var appDelegate

	func documentView(fileURL: URL, document: VirtualMachineDocument) -> some View {
		let loaded = document.loadVirtualMachine(from: fileURL)

		return HStack {
			if loaded {
				HostVirtualMachineView(appState: $appState, document: document)
			} else {
				Text("Unable to load virtual machine \(document.name)")
			}
		}.restorationState(.disabled)
	}

	var body: some Scene {
		/*DocumentGroup(newDocument: VirtualMachineDocument()) { file in
		 HostVirtualMachineView(appState: self.appState, document: file.document)
		}*/
		CakerMenuBarExtraScene(appState: appState)
		DocumentGroup(viewing: VirtualMachineDocument.self) { file in
			if let fileURL = file.fileURL {
				documentView(fileURL: fileURL, document: file.document)
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
					Button("New virtual machine") {
						openWindow(id: "wizard")
						//newDocumentWizard()
					}.keyboardShortcut(KeyboardShortcut("N"))
					Button("Open virtual machine") {
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

				Button("Create template") {
					createTemplate = true
				}
				.disabled(appState.isRunning || appState.currentDocument == nil)
				.alert("Create template", isPresented: $createTemplate) {
					CreateTemplateView(currentDocument: appState.currentDocument)
				}
			}
		}
		Window("Home", id: "home") {
			HomeView(appState: $appState)
		}
		Window("Create new virtual machine", id: "wizard") {
			newDocWizard()
		}.commands {
			CommandGroup(replacing: .saveItem, addition: {})
		}
		//WindowGroup("Open virtual machine", id: "opendocument", for: URL.self) { $url in
		//	if let fileURL = url, let document = appState.virtualMachines[fileURL] {
		//		documentView(fileURL: fileURL, document: document).onAppear{
		//			document.startFromUI()
		//		}
		//	} else {
		//		newDocWizard()
		//	}
		//}.commands {
		//	CommandGroup(replacing: .saveItem, addition: {})
		//}
		//.restorationState(.disabled)
		Settings {
			SettingsView()
		}
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
		VirtualMachineWizard().restorationState(.disabled)
	}
}

@MainActor class MainUIAppDelegate: NSObject, NSApplicationDelegate {
	@Setting("HideDockIcon") private var isDockIconHidden: Bool = false

	func applicationDidFinishLaunching(_ notification: Notification) {
		if isDockIconHidden {
			NSApp.setActivationPolicy(.accessory)
		}
	}
	
	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		urls.forEach { u in print("Opening URL: \(u)") }
	}
}
