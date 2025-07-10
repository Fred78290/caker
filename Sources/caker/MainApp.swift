import SwiftUI
import CakedLib
import GRPCLib

struct AppState {
	var currentDocument: VirtualMachineDocument?
	var isStopped: Bool = true
	var isSuspendable: Bool = false
	var isRunning: Bool = false
	var isPaused: Bool = false
	var templateName: String = ""
	var templateResult: CreateTemplateReply?

	@ViewBuilder
	static func createTemplatePrompt(appState: Binding<AppState>) -> some View {
		TextField("Name", text: appState.templateName)
		AsyncButton("Create", action: {
			appState.wrappedValue.templateResult = appState.wrappedValue.currentDocument?.createTemplateFromUI(name: appState.wrappedValue.templateName)
		}).disabled(appState.wrappedValue.templateName.isEmpty || TemplateHandler.exists(name: appState.wrappedValue.templateName, runMode: .app))

		Button("Cancel", role: .cancel, action: {})
	}

	static func createTemplatFailed(templateResult: CreateTemplateReply?) {
		if let templateResult = templateResult, templateResult.created == false {
			let alert = NSAlert()
			
			alert.messageText = "Failed to create template"
			alert.informativeText = templateResult.reason ?? "Internal error"
			alert.runModal()
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

	var body: some Scene {
		/*DocumentGroup(newDocument: VirtualMachineDocument()) { file in
			VirtualMachineView(appState: self.appState, document: file.document)
		}*/

		DocumentGroup(viewing: VirtualMachineDocument.self) { file in
			if let fileURL = file.fileURL {
				if file.document.loadVirtualMachine(from: fileURL) {
					VirtualMachineView(appState: $appState, document: file.document)
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
					AppState.createTemplatePrompt(appState: $appState)
				}.onChange(of: appState.templateResult) { newValue in
					AppState.createTemplatFailed(templateResult: newValue)
				}
			}
		}
		Window("Create new virtual machine", id: "wizard") {
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
