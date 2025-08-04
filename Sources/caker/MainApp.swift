import CakedLib
import GRPCLib
import SwiftTerm
import SwiftUI

@MainActor
func alertError(_ error: Error) {
	let informativeText: String
	
	if let error = error as? ServiceError {
		informativeText = error.description
	} else {
		informativeText = error.localizedDescription
	}
	
	let alert = NSAlert(error: error)

	alert.messageText = "Failed to start VM"
	alert.informativeText = informativeText
	alert.runModal()
}

struct Defaults {
	static func currentTerminalFont(defaultValue: NSFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)) -> NSFont {
		guard let name = UserDefaults.standard.object(forKey: "TerminalFontName") as? String else {
			return defaultValue
		}

		let size = CGFloat(UserDefaults.standard.float(forKey: "TerminalFontSize"))
		guard let font = NSFont(name: name, size: size) else {
			return defaultValue
		}

		return font
	}

	static func saveTerminalFont(name: String, size: Float) {
		UserDefaults.standard.set(name, forKey: "TerminalFontName")
		UserDefaults.standard.set(size, forKey: "TerminalFontSize")
	}

	static func saveTerminalFont(_ font: NSFont) {
		saveTerminalFont(name: font.fontName, size: Float(font.pointSize))
	}

	static func saveTerminalFontColor(color: SwiftTerm.Color) {
		let value = String(format: "%04x.%04x.%04x", color.red, color.green, color.blue)

		UserDefaults.standard.set(value, forKey: "TerminalFontColor")
	}

	static func currentTerminalFontColor(defaultValue: SwiftTerm.Color = SwiftTerm.Color(red: 35389, green: 35389, blue: 35389)) -> SwiftTerm.Color {
		guard let color = UserDefaults.standard.object(forKey: "TerminalFontColor") as? String else {
			return defaultValue
		}

		let rgbValues = color.split(separator: ".")

		if rgbValues.count == 3 {
			if let red = UInt16(rgbValues[0], radix: 16), let green = UInt16(rgbValues[1], radix: 16), let blue = UInt16(rgbValues[2], radix: 16) {
				return .init(red: red, green: green, blue: blue)
			}
		}

		return defaultValue
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
		}
	}

	var body: some Scene {
		CakerMenuBarExtraScene(appState: appState)

		DocumentGroup(viewing: VirtualMachineDocument.self) { file in
			if let fileURL = file.fileURL {
				documentView(fileURL: fileURL, document: file.document).restorationState(.disabled)
			} else {
				Color.red.restorationState(.disabled)
			}
		}
		.windowResizability(.contentSize)
		.commands {
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
					appState.currentDocument.startFromUI()
				}.disabled(appState.isRunning || appState.currentDocument == nil)

				Button("Stop") {
					appState.currentDocument.stopFromUI()
				}.disabled(appState.isStopped || appState.isAgentInstalling || appState.currentDocument == nil)

				Button("Request Stop") {
					appState.currentDocument.requestStopFromUI()
				}.disabled(appState.isStopped || appState.isAgentInstalling || appState.currentDocument == nil)

				if #available(macOS 14, *) {
					Button("Suspend") {
						appState.currentDocument.suspendFromUI()
					}.disabled(!appState.isSuspendable || appState.isAgentInstalling || appState.currentDocument == nil)
				}

				Button("Create template") {
					createTemplate = true
				}
				.disabled(appState.isRunning || appState.currentDocument == nil)
				.alert("Create template", isPresented: $createTemplate) {
					CreateTemplateView(appState: $appState)
				}
				
				Divider()

				Button("Install agent") {
					appState.isAgentInstalling = true

					appState.currentDocument.installAgent {
						appState.isAgentInstalling = false
					}
				}
				.disabled(appState.isStopped || appState.isAgentInstalling || appState.currentDocument == nil)
				.alert("Create template", isPresented: $createTemplate) {
					CreateTemplateView(appState: $appState)
				}
			}
		}.restorationState(.disabled)

		Window("Home", id: "home") {
			HomeView(appState: $appState)
				.restorationState(.disabled)
		}.restorationState(.disabled)

		Window("Create new virtual machine", id: "wizard") {
			newDocWizard()
				.restorationState(.disabled)
		}
		.windowResizability(.contentSize)
		.restorationState(.disabled)
		.commands {
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
		}.restorationState(.disabled)
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
			.frame(minWidth: 700, maxWidth: 700, minHeight: 670, maxHeight: 670)
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
