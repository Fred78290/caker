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
	var statusBarItem: NSStatusItem?

	override init() {
		super.init()

		print("delegate")
	}

	@objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
		print("Menu item clicked")
		// We'll implement the window handling logic here
	}

	func applicationWillFinishLaunching(_ notification: Notification) {
		let statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

		self.statusBarItem = statusBarItem

		if let button = statusBarItem.button {
			//button.action = #selector(statusBarButtonClicked(_:))
			//button.target = self
			button.image = NSImage(named: NSImage.Name("SmallAppIcon"))
			
			setupMenus(statusBarItem)
		}
	}

	@objc func showAbout() {
		
	}

	@objc func newVirtualMachine(_ sender: NSMenuItem) {
		
	}

	@objc func startVirtualMachine(_ sender: NSMenuItem) {
		
	}

	func setupMenus(_ statusBarItem: NSStatusItem) {
		let menu = NSMenu()
		let aboutMenu = NSMenuItem(title: "About", action: #selector(showAbout) , keyEquivalent: "")
		menu.addItem(aboutMenu)
		menu.addItem(NSMenuItem.separator())

		let newMenu = NSMenuItem(title: "New virtual machine", action: #selector(newVirtualMachine) , keyEquivalent: "")
		menu.addItem(newMenu)
		
		let vmsMenu = NSMenuItem(title: "Virtual machines", action: nil, keyEquivalent: "3")
		let subMenus = NSMenu()
		
		vmsMenu.submenu = subMenus

		try? ListHandler.list(vmonly: true, runMode: .app).forEach {
			let vmMenu = NSMenuItem(title: $0.name, action: #selector(startVirtualMachine(_:)), keyEquivalent: "")

			subMenus.addItem(vmMenu)
		}

		menu.addItem(vmsMenu)
		menu.addItem(NSMenuItem.separator())
		menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))

		statusBarItem.menu = menu
	}

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		urls.forEach { u in print("Opening URL: \(u)") }
	}
}
