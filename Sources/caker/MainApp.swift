import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib
import SwiftTerm
import SwiftUI
import SwifterSwiftUI

@MainActor
func alertError(_ error: Error) {
	let informativeText: String

	if let error = error as? ServiceError {
		informativeText = error.description
	} else {
		informativeText = error.localizedDescription
	}

	let alert = NSAlert(error: error)

	alert.messageText = "An error occured"
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

struct MainAppParseArgument: ParsableCommand {
	@Option(name: [.customLong("log-level")], help: "Log level")
	var logLevel: Logger.LogLevel = .info

	func validate() throws {
		Logger.setLevel(self.logLevel)
	}
}

@main
struct MainApp: App {
	@Environment(\.openWindow) var openWindow
	@Environment(\.openDocument) private var openDocument
	@State var appState: AppState
	@State var createTemplate = false

	@NSApplicationDelegateAdaptor(MainUIAppDelegate.self) var appDelegate

	init() {
		_ = try? MainAppParseArgument.parse(CommandLine.arguments)
		self.appState = AppState.shared

		DispatchQueue.main.async {
			EnvironmentValues().openWindow(id: "home")
		}
	}

	var agentCondition: (title: String, needUpdate: Bool, disabled: Bool) {
		let title = "Install agent"

		guard let document = appState.currentDocument else {
			return (title, false, true)
		}

		return document.agentCondition
	}

	var body: some Scene {
		CakerMenuBarExtraScene(appState: appState)

		DocumentGroup(viewing: BridgeVirtualDocument.self) { file in
			let document = file.document.attachedVirtualDocument
			let initialSize = document.virtualMachineConfig.display.size

			if document.location != nil {
				HostVirtualMachineView(appState: $appState, document: document)
					.colorSchemeForColor()
					.windowMinimizeBehavior(.enabled)
					.windowResizeBehavior(.enabled)
					.windowFullScreenBehavior(.enabled)
					.windowToolbarFullScreenVisibility(.onHover)
					.restorationState(.disabled)
					.frame("MainApp", minSize: initialSize, idealSize: document.documentSize.cgSize)
					.containerBackground(.windowBackground, for: .window)
			} else {
				LabelView("Unable to load virtual machine \(document.name)")
					.containerBackground(.windowBackground, for: .window)
					.colorSchemeForColor()
					.restorationState(.disabled)
					.frame(size: initialSize)
			}
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.restorationState(.disabled)
		.commandsReplaced {
			CommandGroup(before: .newItem) {
				Button("New virtual machine") {
					openWindow(id: "wizard")
				}.keyboardShortcut(KeyboardShortcut("N"))
				Button("Open virtual machine") {
					open()
				}.keyboardShortcut(KeyboardShortcut("o"))
			}
			CommandMenu("Control") {
				Button("Start") {
					appState.currentDocument.startFromUI()
				}.disabled(appState.isRunning || appState.currentDocument == nil)

				Button("Stop") {
					appState.currentDocument.stopFromUI(force: true)
				}.disabled(appState.isStopped || appState.isAgentInstalling || appState.currentDocument == nil)

				Button("Request Stop") {
					appState.currentDocument.stopFromUI(force: false)
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

				let agentCondition = self.agentCondition

				Button(agentCondition.title) {
					appState.isAgentInstalling = true

					appState.currentDocument.installAgent(updateAgent: agentCondition.needUpdate) {
						appState.isAgentInstalling = false
					}
				}
				.disabled(agentCondition.disabled)
				.alert("Create template", isPresented: $createTemplate) {
					CreateTemplateView(appState: $appState)
				}
			}

			CommandMenu("Service") {
				if self.appState.cakedServiceInstalled {
					Button("Remove service") {
						self.appState.removeCakedService()
					}
				} else {
					Button("Install service") {
						self.appState.installCakedService()
					}
				}

				if self.appState.cakedServiceRunning {
					Button("Stop service") {
						self.appState.stopCakedService()
					}
				} else {
					Button("Start service") {
						self.appState.startCakedService()
					}
				}
			}
		}

		Window("Home", id: "home") {
			HomeView(appState: $appState)
				.colorSchemeForColor()
				.containerBackground(.windowBackground, for: .window)
				.frame(size: CGSize(width: 1200, height: 800))
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)

		Window("Create new virtual machine", id: "wizard") {
			newDocWizard()
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.expanded)
		.restorationState(.disabled)
		.commands {
			CommandGroup(replacing: .saveItem, addition: {})
		}

		Settings {
			SettingsView()
				.colorSchemeForColor()
				.containerBackground(.windowBackground, for: .window)
		}.restorationState(.disabled)
	}

	private func open() {
		let home = StorageLocation(runMode: .app).rootURL

		if let documentURL = FileHelpers.selectSingleInputFile(ofType: [.virtualMachine], withTitle: "Open virtual machine", directoryURL: home) {
			Task {
				try? await openDocument(at: documentURL)
			}
		}
	}

	func newDocWizard() -> some View {
		VirtualMachineWizard(appState: $appState)
			.colorSchemeForColor()
			.restorationState(.disabled)
			.frame(minWidth: 700, maxWidth: 700, minHeight: 670, maxHeight: 670)
	}
}

@MainActor class MainUIAppDelegate: NSObject, NSApplicationDelegate {
	@Setting("HideDockIcon") private var isDockIconHidden: Bool = false

	func applicationDidFinishLaunching(_ notification: Notification) {
		ProcessWithSharedFileHandle.runLoopQos = .userInteractive

		if isDockIconHidden {
			NSApp.setActivationPolicy(.accessory)
		}
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		if AppState.shared.haveVirtualMachinesRunning() {
			return .terminateLater
		} else {
			return .terminateNow
		}
	}

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		urls.forEach { u in print("Opening URL: \(u)") }
	}
}
