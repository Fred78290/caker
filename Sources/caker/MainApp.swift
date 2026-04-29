import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib
import SwiftTerm
import SwiftUI
import SwifterSwiftUI
import Logging
import Security
import Sparkle

@MainActor
func alertError(_ messageText: String, _ informativeText: String) {
	let alert = NSAlert()

	alert.messageText = messageText
	alert.informativeText = informativeText
	alert.runModal()
}

@MainActor
func alertError(_ error: Error) {
	let informativeText: String

	if let error = error as? ServiceError {
		informativeText = error.description
	} else {
		informativeText = error.localizedDescription
	}

	alertError(String(localized: "An error occured"), informativeText)
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
	@Option(name: [.customLong("log-level")], help: ArgumentHelp(String(localized: "Log level")))
	var logLevel: CakeAgentLib.Logger.LogLevel = .info

	func validate() throws {
		// Set up logging to stderr
		Logging.LoggingSystem.bootstrap { label in
			StreamLogHandler.standardError(label: label)
		}

		CakeAgentLib.Logger.setLevel(self.logLevel)
	}
}

@main
struct MainApp: App {
	static var app: MainApp! = nil
	
	@Environment(\.openWindow) var openWindow
	@Environment(\.openDocument) private var openDocument
	@State var appState: AppState
	@State var createTemplate = false
	
	@NSApplicationDelegateAdaptor(MainUIAppDelegate.self) var appDelegate
	
	// Sparkle updater
	private let updaterController: SPUStandardUpdaterController
	
	init() {
		_ = try? MainAppParseArgument.parse(CommandLine.arguments)
		self.appState = AppState.shared
		
		// Initialize Sparkle updater
		self.updaterController = SPUStandardUpdaterController(
			startingUpdater: true,
			updaterDelegate: nil,
			userDriverDelegate: nil
		)
		
		Self.app = self
	}
	
	var agentCondition: (title: LocalizedStringKey, needUpdate: Bool, disabled: Bool) {		
		guard let document = appState.currentDocument else {
			return ("Install agent", false, true)
		}
		
		return document.agentCondition
	}
	
	var body: some Scene {
		CakerMenuBarExtraScene(appState: appState)
		
		DocumentGroup(viewing: BridgeVirtualDocument.self) { file in
			let document = file.document.attachedVirtualDocument
			let initialSize = document.virtualMachineConfig.display.cgSize
			
			if document.location != nil || document.url.isFileURL == false {
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
				self.failedLoadVirtualMachine(document.name)
			}
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.restorationState(.disabled)
		.commandsReplaced {
			self.menus
		}
		
		WindowGroup(id: "VM", for: URL.self) { $vmURL in
			if let vmURL, let document = self.appState.findVirtualMachineDocument(vmURL) {
				let initialSize = document.virtualMachineConfig.display.cgSize
				
				HostVirtualMachineView(appState: $appState, document: document)
					.colorSchemeForColor()
					.windowMinimizeBehavior(.enabled)
					.windowResizeBehavior(.enabled)
					.windowFullScreenBehavior(.enabled)
					.windowToolbarFullScreenVisibility(.onHover)
					.restorationState(.disabled)
					.frame("MainApp", minSize: initialSize, idealSize: document.documentSize.cgSize)
					.containerBackground(.windowBackground, for: .window)
					.navigationTitle(document.name)
			} else {
				self.failedLoadVirtualMachine("Service is not runing or stopped")
			}
		}
		.handlesExternalEvents(matching: [])
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.restorationState(.disabled)
		
		Window("Home", id: "home") {
			HomeView(appState: $appState)
				.colorSchemeForColor()
				.containerBackground(.windowBackground, for: .window)
				.frame(size: CGSize(width: 1200, height: 800))
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)

		Window("Browser of services", id: "remote") {
			CakedServerView(appState: $appState)
				.colorSchemeForColor()
				.containerBackground(.windowBackground, for: .window)
				.frame(size: CGSize(width: 600, height: 400))
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)

		Window("Create a new virtual machine", id: "wizard") {
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
	
	@CommandsBuilder private var menus: some Commands {
		CommandGroup(before: .newItem) {
			Button("New virtual machine") {
				openWindow(id: "wizard")
			}.keyboardShortcut(KeyboardShortcut("N"))
			Button("Open virtual machine") {
				open()
			}
			.keyboardShortcut(KeyboardShortcut("o"))
			.disabled(self.appState.connectionMode == .remote)
		}
		CommandMenu("Control") {
			Button("Start") {
				appState.currentDocument.startFromUI()
			}.disabled(appState.isRunning || appState.currentDocument == nil)
			
			Button("Stop") {
				appState.currentDocument.stopFromUI(force: true)
			}.disabled(appState.isStopped || appState.isAgentInstalling || appState.currentDocument == nil)
			
			Button("Request stop") {
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
				CreateTemplateView()
			}
			
			Divider()
			
			let agentCondition = self.agentCondition
			
			Button(agentCondition.title) {
				appState.isAgentInstalling = true
				
				appState.currentDocument.installAgent(updateAgent: agentCondition.needUpdate) { _ in
					appState.isAgentInstalling = false
				}
			}
			.disabled(agentCondition.disabled)
			.alert("Create template", isPresented: $createTemplate) {
				CreateTemplateView()
			}
		}
		
		CommandGroup(after: .appInfo) {
			CheckForUpdatesView(updater: updaterController.updater)
		}
		
		CommandMenu("Service") {
			Button("Connect to remote") {
				self.openWindow(id: "remote")
			}
			Divider()
			if self.appState.cakedServiceInstalled {
				Button("Remove service") {
					Self.removeCakedService()
				}.disabled(self.appState.cakedServiceRunning)
			} else {
				Button("Install service") {
					Self.installCakedService()
				}
			}
			
			if self.appState.cakedServiceInstalled {
				if self.appState.cakedServiceRunning {
					Button("Stop service") {
						Self.stopCakedService()
					}.disabled(self.appState.cakedServiceInstalled == false)
				} else {
					Button("Start service") {
						Self.startCakedService()
					}.disabled(self.appState.cakedServiceInstalled == false)
				}
			} else {
				if self.appState.cakedServiceRunning {
					Button("Stop caked daemon") {
						Self.stopCakedDaemon()
					}
				} else {
					Button("Start caked daemon") {
						Self.startCakedDaemon()
					}
				}
			}
		}
	}
	
	private func failedLoadVirtualMachine(_ title: String) -> some View {
		LabelView("Unable to load virtual machine\n\(title)")
			.containerBackground(.windowBackground, for: .window)
			.colorSchemeForColor()
			.restorationState(.disabled)
			.frame(size: CGSize(width: 800, height: 600))
	}
	
	private func open() {
		let home = StorageLocation(runMode: .app).rootURL
		
		if let documentURL = FileHelpers.selectSingleInputFile(ofType: [.virtualMachine], withTitle: String(localized: "Open virtual machine"), directoryURL: home) {
			Task {
				try? await openDocument(at: documentURL)
			}
		}
	}
	
	func newDocWizard() -> some View {
		VirtualMachineWizard()
			.colorSchemeForColor()
			.restorationState(.disabled)
			.frame(size: CGSize(width: 700, height: 610))
	}
	
	@MainActor func openVirtualMachine(_ vmURL: URL) async {
		if let document = appState.tryVirtualMachineDocument(vmURL) {
			if let vmURL = document.loadVirtualMachine() {
				if vmURL.isFileURL {
					try? await EnvironmentValues().openDocument(at: vmURL)
				} else {
					EnvironmentValues().openWindow(id: "VM", value: vmURL)
				}
			}
		}
	}

	static func installCakedService() {
        // Try Keychain first
		if let savedPassword = try? CakedKeyConfig.passphrase.get(), savedPassword.isEmpty == false {
            do {
                try ServiceHandler.installAgent(password: savedPassword, runMode: .user)
                return
            } catch {
                // If saved password fails, fall back to prompting
            }
        }

        // Prompt for password using a secure text field
        let alert = NSAlert()
        alert.messageText = String(localized: "Pass-Phrase Required")
        alert.informativeText = String(localized: "To install the service, please enter your pass-phrase.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Install"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let secureField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        secureField.placeholderString = String(localized: "Password")
        alert.accessoryView = secureField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }

        let password = secureField.stringValue
        guard password.isEmpty == false else {
            DispatchQueue.main.async {
                alertError(String(localized: "Password"), String(localized: "Password cannot be empty."))
            }
            return
        }

        do {
			try ServiceHandler.installAgent(password: password, runMode: .user)
        } catch {
            DispatchQueue.main.async {
                alertError(error)
            }
        }
	}
	
	static func removeCakedService() {
		do {
			try ServiceHandler.uninstallAgent(runMode: .user)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
	
	static func stopCakedService() {
		do {
			try ServiceHandler.stopAgent(runMode: .user)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
	
	static func startCakedService() {
		do {
			try ServiceHandler.launchAgent(runMode: .user)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
	
	static func stopCakedDaemon() {
		do {
			try ServiceHandler.stopAgentRunning(runMode: .user)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
	
	static func startCakedDaemon() {
		do {
			try self.runAgent(runMode: .user)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
	
	static func runAgent(runMode: Utils.RunMode) throws {
		guard var pluginsURL = Bundle.main.cakedBundleURL else {
			throw ServiceError(String(localized: "Caked bundle path is missing"))
		}

		pluginsURL = pluginsURL.appendingPathComponent(Home.cakedCommandName)

		guard try pluginsURL.exists() else {
			throw ServiceError(String(localized: "Caked executable is missing"))
		}

		// Launch off the main thread to avoid QoS inversions and UI stalls
		Task.detached(priority: .background) {
			do {
				let process = ProcessWithSharedFileHandle()
				process.executableURL = pluginsURL
				process.arguments = [
					"service",
					"listen",
					"--secure",
					"--log-level=\(CakeAgentLib.Logger.Level().description)"
				]

				// If you need to capture output, switch to Pipes and read asynchronously.
				// For now, inherit parent's stdio without blocking the main thread.
				process.standardOutput = FileHandle.standardOutput
				process.standardError = FileHandle.standardError
				process.standardInput = FileHandle.nullDevice

				try process.run()

				// Do not call waitUntilExit() on the main thread. If needed, wait here off-main.
				//process.waitUntilExit()

				// If you need to update UI after exit, hop back to the main actor here.
				// await MainActor.run { /* update UI state */ }
			} catch {
				// Report error back to the main actor if UI needs to reflect failures
				await MainActor.run {
					// You can integrate with your app's logging or state here
					// e.g., Logger.error("Failed to run agent: \(error)")
					alertError(error)
				}
			}
		}
	}

}

class MainUIAppDelegate: NSObject, NSApplicationDelegate {
	static private(set) var instance: MainUIAppDelegate!

	@Setting("HideDockIcon") private var isDockIconHidden: Bool = false

	override init() {
		super.init()
		MainUIAppDelegate.instance = self
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		Self.ensureCertificates()
		Self.ensurePrivilegedBootstrapFiles()

		if isDockIconHidden {
			NSApp.setActivationPolicy(.accessory)
		} else {
			NSApp.setActivationPolicy(.regular)
			EnvironmentValues().openWindow(id: "home")
			NSApp.windows.first?.makeKeyAndOrderFront(nil)
		}
	}

	static func ensureCertificates() {
		do {
			_ = try CertificatesLocation.createCertificats(runMode: .app)
			_ = try CertificatesLocation.createAgentCertificats(runMode: .app)
		} catch {
			CakeAgentLib.Logger("MainUIAppDelegate").warn("Failed to ensure certificates: \(error.localizedDescription)")

			MainActor.assumeIsolated {
				alertError(String(localized: "Certificates"), String(localized: "Failed to install certificates. Please check the logs for more information."))
			}

			NSApp.terminate(self)
		}
	}

	static func ensurePrivilegedBootstrapFiles() {
		guard let pluginPath = Bundle.main.cakedBundlePath else {
			return
		}

		do {
			let pathsFile = URL(fileURLWithPath: "/etc/paths.d/com.aldunelabs.caker")
			let sudoersFile = URL(fileURLWithPath: "/etc/sudoers.d/caked")
			let needsPathsFile = FileManager.default.fileExists(atPath: pathsFile.path) == false
			let needsSudoersFile = FileManager.default.fileExists(atPath: sudoersFile.path) == false

			if needsPathsFile || needsSudoersFile {
				var contents: [String] = [
					"#!/bin/sh\n"
				]

				if needsPathsFile {
					let content = pluginPath.hasSuffix("\n") ? pluginPath : "\(pluginPath)\n"

					try contents.append(contentsOf: installRootOwnedFile(content: content, to: pathsFile, mode: "0644"))
				}
				
				if needsSudoersFile {
					let content = "%everyone ALL=(root:wheel) NOPASSWD: \(pluginPath)/caked\n"

					try contents.append(contentsOf: installRootOwnedFile(content: content, to: sudoersFile, mode: "0440"))
				}
				
				if geteuid() != 0 && contents.count > 1 {
					try print(runPrivileged(contents))
				}
			}
		} catch {
			CakeAgentLib.Logger("MainUIAppDelegate").warn("Failed to ensure privileged bootstrap files: \(error.localizedDescription)")

			MainActor.assumeIsolated {
				alertError(String(localized: "Admin rights"), String(localized: "Failed to ensure privileged bootstrap files"))
			}

			NSApp.terminate(self)
		}
	}

	private static func installRootOwnedFile(content: String, to destination: URL, mode: String) throws -> [String] {
		let temporaryFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("caker-bootstrap-\(UUID().uuidString)")
		let parent = destination.deletingLastPathComponent()
		let logger = CakeAgentLib.Logger("MainUIAppDelegate")
		var result: [String] = []

		try content.write(to: temporaryFile, atomically: true, encoding: .utf8)

		if geteuid() == 0 {
			defer {
				try? FileManager.default.removeItem(at: temporaryFile)
			}

			try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

			logger.debug(try Shell.command("/usr/bin/install", arguments: ["-o", "root", "-g", "wheel", "-m", mode, temporaryFile.path, destination.path]))
		} else {
			result.append(contentsOf: [
				"/usr/bin/install -d -m 755 \(parent.path)",
				"/usr/bin/install -o root -g wheel -m \(mode) \(temporaryFile.path) \(destination.path)",
				"rm -f \(temporaryFile.path)"
			])
		}

		return result
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
		let appState = AppState.shared
		
		Task {
			for vmURL in urls {
				if let document = appState.tryVirtualMachineDocument(vmURL) {
					if let vmURL = document.loadVirtualMachine() {
						if vmURL.isFileURL {
							try? await EnvironmentValues().openDocument(at: vmURL)
						} else {
							EnvironmentValues().openWindow(id: "VM", value: vmURL)
						}
					}
				}
			}

		}
	}

	private static func runPrivileged(_ commands: [String]) throws -> String {
		let temporaryFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("caker-bootstrap-\(UUID().uuidString).sh")
		let appleScript = "do shell script \"\(temporaryFile.path)\" with administrator privileges"

		try commands.joined(separator: "\n").write(to: temporaryFile, atomically: true, encoding: .utf8)
		
		defer {
			try? FileManager.default.removeItem(at: temporaryFile)
		}

		try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporaryFile.path)

		return try Shell.command("/usr/bin/osascript", arguments: ["-e", appleScript])
	}

	private static func shellQuote(_ value: String) -> String {
		let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
		return "'\(escaped)'"
	}

}
