import SwiftUI
import CakedLib
import GRPCLib

struct PairedVirtualMachineDocument: Identifiable {
	let id: URL
	let document: VirtualMachineDocument
}

class AppState: ObservableObject, Observable {
	@Published var currentDocument: VirtualMachineDocument?
	@Published var isStopped: Bool = true
	@Published var isSuspendable: Bool = false
	@Published var isRunning: Bool = false
	@Published var isPaused: Bool = false
	@Published var virtualMachines: [URL:VirtualMachineDocument] = [:]

	var vms: [PairedVirtualMachineDocument] {
		self.virtualMachines.compactMap {
			PairedVirtualMachineDocument(id: $0.key, document: $0.value)
		}
	}

	init() {
		if let vms = try? ListHandler.list(vmonly: true, runMode: .app) {
			let storage = StorageLocation(runMode: .app)
			
			vms.compactMap {
				if let location = try? storage.find($0.name) {
					return location
				}
				
				return nil
			}.forEach {
				self.virtualMachines[$0.rootURL] = VirtualMachineDocument(name: $0.name)
			}
		}
	}
}

@main
struct MainApp: App {
	@Environment(\.openWindow) var openWindow
	@Environment(\.openDocument) private var openDocument
	@Environment(\.newDocument) private var newDocument
	@State var appState = AppState()
	@State var createTemplate = false

	@NSApplicationDelegateAdaptor(MainUIAppDelegate.self) var appDelegate

	func documentView(fileURL: URL, document: VirtualMachineDocument) -> some View {
		var document = document

		if let found = appState.virtualMachines[fileURL] {
			document = found
		} else {
			appState.virtualMachines[fileURL] = document
		}

		let loaded = document.loadVirtualMachine(from: fileURL)

		return HStack {
			if loaded {
				VirtualMachineView(appState: $appState, document: document)
			} else {
				Text("Unable to load virtual machine \(document.name)")
			}
		}.restorationState(.disabled)
	}

	var body: some Scene {
		/*DocumentGroup(newDocument: VirtualMachineDocument()) { file in
			VirtualMachineView(appState: self.appState, document: file.document)
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
		Window("Create new virtual machine", id: "wizard") {
			newDocWizard()
		}
		WindowGroup("Open virtual machine", id: "opendocument", for: URL.self) { $url in
			if let fileURL = url, let document = appState.virtualMachines[fileURL] {
				documentView(fileURL: fileURL, document: document).onAppear{
					document.startFromUI()
				}
			} else {
				newDocWizard()
			}
		}
		.restorationState(.disabled)
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
