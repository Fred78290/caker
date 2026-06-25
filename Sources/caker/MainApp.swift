import ArgumentParser
import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib
import Logging
import Security
import ServiceManagement
import SwiftTerm
import SwiftUI
import SwifterSwiftUI

#if SPARKLE
	import Sparkle
#endif

@MainActor
func alertError(_ messageText: String, _ informativeText: String, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
	let alert = NSAlert()

	alert.messageText = messageText
	alert.informativeText = informativeText
	let result = alert.runModal()

	if let completion {
		completion(result)
	}
}

@MainActor
func alertError(_ error: Error, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
	let informativeText: String

	switch error {
	case let error as ServiceError:
		informativeText = error.description
	case let error as ValidationError:
		informativeText = error.description
	case let error as GRPCStatus:
		informativeText = error.description
	default:
		informativeText = error.localizedDescription
	}

	alertError(String(localized: "An error occurred"), informativeText, completion: completion)
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
	var appState: AppState
	@State var createTemplate = false
	@State var navigationModel = NavigationModel()

	@NSApplicationDelegateAdaptor(MainUIAppDelegate.self) var appDelegate

	// Sparkle updater
	#if SPARKLE
		private let updaterController: SPUStandardUpdaterController
	#endif

	init() {
		_ = try? MainAppParseArgument.parse(CommandLine.arguments)
		self.appState = AppState.shared

		#if SPARKLE
			// Initialize Sparkle updater
			self.updaterController = SPUStandardUpdaterController(
				startingUpdater: true,
				updaterDelegate: nil,
				userDriverDelegate: nil
			)
		#endif

		self.navigationModel.sync(with: self.appState)

		Self.app = self
	}

	var agentCondition: (title: LocalizedStringKey, needUpdate: Bool, disabled: Bool) {
		guard let document = AppState.shared.currentDocument else {
			return ("Install agent", false, true)
		}

		return document.agentCondition
	}

	var body: some Scene {
		CakerMenuBarExtraScene(model: self.navigationModel)

		DocumentGroup(viewing: BridgeVirtualDocument.self) { file in
			let document = file.document.attachedVirtualDocument
			let initialSize = document.virtualMachineConfig.display.cgSize

			if document.location != nil || document.url.isFileURL == false {
				HostVirtualMachineView(document: document)
					.colorSchemeForColor()
					.windowMinimizeBehavior(.enabled)
					.windowResizeBehavior(.enabled)
					.windowFullScreenBehavior(.enabled)
					.windowToolbarFullScreenVisibility(.onHover)
					.restorationState(.disabled)
					.frame("MainApp", minSize: initialSize, idealSize: document.documentSize.cgSize)
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
			if let vmURL, let document = AppState.shared.findVirtualMachineDocument(vmURL) {
				let initialSize = document.virtualMachineConfig.display.cgSize

				HostVirtualMachineView(document: document)
					.colorSchemeForColor()
					.windowMinimizeBehavior(.enabled)
					.windowResizeBehavior(.enabled)
					.windowFullScreenBehavior(.enabled)
					.windowToolbarFullScreenVisibility(.onHover)
					.restorationState(.disabled)
					.frame("MainApp", minSize: initialSize, idealSize: document.documentSize.cgSize)
					.navigationTitle(document.name)
			} else {
				self.failedLoadVirtualMachine("Service is not runing or stopped")
					.colorSchemeForColor()
			}
		}
		.handlesExternalEvents(matching: [])
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.restorationState(.disabled)

		Window("Home", id: "home") {
			HomeView(navigationModel: navigationModel)
				.colorSchemeForColor()
				.frame(size: CGSize(width: 1200, height: 800))
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)

		Window("Browser of services", id: "remote") {
			CakedServerView()
				.colorSchemeForColor()
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
		}.restorationState(.disabled)

		Window("About Caker", id: "about") {
			AboutCakerView()
				.colorSchemeForColor()
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.restorationState(.disabled)
		.defaultPosition(.center)

		Window("Import from Multipass", id: "import-multipass") {
			ImportMultipassView()
				.colorSchemeForColor()
				.containerBackground(.windowBackground, for: .window)
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.restorationState(.disabled)
		.defaultPosition(.center)

		Window("Import from VMware", id: "import-vmware") {
			ImportVMwareView()
				.colorSchemeForColor()
				.containerBackground(.windowBackground, for: .window)
		}
		.windowResizability(.contentSize)
		.windowToolbarStyle(.unifiedCompact)
		.restorationState(.disabled)
		.defaultPosition(.center)
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

		CommandMenu("Import") {
			Button("From Multipass…") {
				openWindow(id: "import-multipass")
			}
			.disabled(self.appState.connectionMode == .remote)
			Button("From VMware…") {
				openWindow(id: "import-vmware")
			}
			.disabled(self.appState.connectionMode == .remote)
		}
		CommandMenu("Control") {
			Button("Start") {
				appState.currentDocument.startFromUI()
			}.disabled(self.appState.isRunning || self.appState.currentDocument == nil)

			Button("Stop") {
				appState.currentDocument.stopFromUI(force: true)
			}.disabled(self.appState.isStopped || self.appState.isAgentInstalling || self.appState.currentDocument == nil)

			Button("Request stop") {
				appState.currentDocument.stopFromUI(force: false)
			}.disabled(self.appState.isStopped || self.appState.isAgentInstalling || self.appState.currentDocument == nil)

			if #available(macOS 14, *) {
				Button("Suspend") {
					self.appState.currentDocument.suspendFromUI()
				}.disabled(!self.appState.isSuspendable || self.appState.isAgentInstalling || self.appState.currentDocument == nil)
			}

			Button("Create template") {
				createTemplate = true
			}
			.disabled(self.appState.isRunning || self.appState.currentDocument == nil)
			.alert("Create template", isPresented: $createTemplate) {
				CreateTemplateView()
			}

			Divider()

			let agentCondition = self.agentCondition

			Button(agentCondition.title) {
				self.appState.isAgentInstalling = true

				self.appState.currentDocument.installAgent(updateAgent: agentCondition.needUpdate) { _ in
					self.appState.isAgentInstalling = false
				}
			}
			.disabled(agentCondition.disabled)
			.alert("Create template", isPresented: $createTemplate) {
				CreateTemplateView()
			}
		}

		CommandGroup(replacing: .appInfo) {
			Button("About Caker") {
				openWindow(id: "about")
			}
		}

		#if SPARKLE
			CommandGroup(after: .appInfo) {
				CheckForUpdatesView(updater: updaterController.updater)
			}
		#endif

		CommandMenu("Service") {
			Button("Connect to remote") {
				self.openWindow(id: "remote")
			}
			Divider()

			#if USE_SMAPPSERVICE
				if self.appState.cakedServiceInstalled {
					Button("Remove service") {
						Self.removeCakedService()
					}
				} else {
					Button("Install service") {
						Self.installCakedService()
					}
					.disabled(self.appState.cakedServiceRunning)
				}

				if self.appState.cakedServiceInstalled == false {
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
			#else
				if self.appState.cakedServiceInstalled {
					Button("Remove service") {
						Self.removeCakedService()
					}.disabled(self.appState.cakedServiceRunning)
				} else {
					Button("Install service") {
						Self.installCakedService()
					}
					#if USE_SMAPPSERVICE
						.disabled(self.appState.cakedServiceRunning)
					#endif
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
			#endif
		}
	}

	private func failedLoadVirtualMachine(_ title: String) -> some View {
		LabelView("Unable to load virtual machine\n\(title)")
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

	func syncAppState() {
		self.navigationModel.sync(with: self.appState)
	}

	func addStateVirtualMachineDocument(with document: VirtualMachineDocument) {
		DispatchQueue.main.async {
			self.navigationModel.addStateVirtualMachineDocument(with: document)
		}
	}

	func removeStateVirtualMachineDocument(with url: URL) {
		self.navigationModel.removeStateVirtualMachineDocument(with: url)
	}

	func updateStateVirtualMachineDocument(with document: VirtualMachineDocument) {
		DispatchQueue.main.async {
			self.navigationModel.updateStateVirtualMachineDocument(with: document)
		}
	}

	@MainActor func openVirtualMachine(_ vmURL: URL) async {
		if let document = self.appState.tryVirtualMachineDocument(vmURL) {
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
				try installLaunchAgent(savedPassword)
				return
			} catch {
				// If saved password fails, fall back to prompting
				Logger("MainApp").warn("Failed to install launch agent with saved passphrase: \(error)")
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
			try installLaunchAgent(password)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	static var launchdAgentName: String {
		return "com.aldunelabs.caker.plist"
	}

	static var appService: SMAppService {
		SMAppService.agent(plistName: launchdAgentName)
	}

	static func isAgentInstalled() -> Bool {
		#if USE_SMAPPSERVICE
			let service = Self.appService

			return (service.status == .requiresApproval) || (service.status == .enabled)
		#else
			return ServiceHandler.isAgentInstalled
		#endif
	}

	static func installLaunchAgent(_ password: String?) throws {
		#if USE_SMAPPSERVICE
			let service = Self.appService

			if service.status == .notFound || service.status == .notRegistered {
				try service.register()
			}
		#else
			try ServiceHandler.installAgent(password: password, runMode: .user)
		#endif
	}

	static func uninstallLaunchAgent() throws {
		#if USE_SMAPPSERVICE
			let service = Self.appService

			if service.status == .requiresApproval || service.status == .enabled {
				try service.unregister()
			}
		#else
			try ServiceHandler.uninstallAgent(runMode: .user)
		#endif
	}

	static func removeCakedService() {
		do {
			try uninstallLaunchAgent()
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
				if Bundle.isApplicationSandboxed {
					let scriptsFile = try FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("caked.sh")
					let scripts: [String] = [
						"#!/bin/sh",
						"exec '\(pluginsURL.path(percentEncoded: false))' \"$@\"",
					]

					try scripts.joined(separator: "\n").write(to: scriptsFile, atomically: true, encoding: .utf8)
					try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptsFile.path(percentEncoded: false))

					defer {
						try? FileManager.default.removeItem(at: scriptsFile)
					}

					let userTask = try NSUserUnixTask(url: scriptsFile)

					userTask.standardOutput = FileHandle(fileDescriptor: dup(STDOUT_FILENO), closeOnDealloc: true)
					userTask.standardError = FileHandle(fileDescriptor: dup(STDERR_FILENO), closeOnDealloc: true)
					userTask.standardInput = nil

					try await userTask.execute(withArguments: [
						"service",
						"listen",
						"--secure",
						"--tcp",
						"--rest",
						"--log-level=\(CakeAgentLib.Logger.Level().description)",
					])
				} else {
					let process = Process()
					process.executableURL = pluginsURL
					process.environment = ProcessInfo.processInfo.environment
					process.arguments = [
						"service",
						"listen",
						"--secure",
						"--tcp",
						"--rest",
						"--log-level=\(CakeAgentLib.Logger.Level().description)",
					]

					// If you need to capture output, switch to Pipes and read asynchronously.
					// For now, inherit parent's stdio without blocking the main thread.
					process.standardOutput = FileHandle.standardOutput
					process.standardError = FileHandle.standardError
					process.standardInput = nil

					try process.run()
				}
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

		Self.askUserToInstallCakedAgent()

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

	static var isPrivilegedBootstrapFilesInstalled: Bool {
		FileManager.default.fileExists(atPath: "/etc/paths.d/com.aldunelabs.caker") && FileManager.default.fileExists(atPath: "/etc/sudoers.d/caked")
	}

	static func ensurePrivilegedBootstrapFiles() {
		let pluginPaths = Bundle.main.cakerBuildPlugInsPath

		guard pluginPaths.isEmpty == false else {
			return
		}

		do {
			let pathsFile = URL(fileURLWithPath: "/etc/paths.d/com.aldunelabs.caker")
			let sudoersFile = URL(fileURLWithPath: "/etc/sudoers.d/caked")
			let needsPathsFile = FileManager.default.fileExists(atPath: pathsFile.path) == false
			let needsSudoersFile = FileManager.default.fileExists(atPath: sudoersFile.path) == false

			guard needsPathsFile || needsSudoersFile else { return }

			var contents: [String] = ["#!/bin/sh\n"]
			var pathsContent: String = ""
			var sudoersContent: String = ""

			if needsPathsFile {
				pathsContent = pluginPaths.map { $0.hasSuffix("\n") ? $0 : "\($0)\n" }.joined()
				try contents.append(contentsOf: installRootOwnedFile(content: pathsContent, to: pathsFile, mode: "0644"))
			}

			if let pluginPath = pluginPaths.first, needsSudoersFile {
				sudoersContent = "%everyone ALL=(root:wheel) NOPASSWD: \(pluginPath)/caked\n"
				try contents.append(contentsOf: installRootOwnedFile(content: sudoersContent, to: sudoersFile, mode: "0440"))
			}

			if geteuid() != 0 && contents.count > 1 {
				if Bundle.isApplicationSandboxed {
					let shouldContinue = MainActor.assumeIsolated {
						showPrivilegedInstallationConfirmation()
					}
					guard shouldContinue else {
						NSApp.terminate(self)
						return
					}
					do {
						try print(runPrivilegedWithBundledScript(pathsContent: pathsContent, sudoersContent: sudoersContent))
					} catch {
						MainActor.assumeIsolated {
							showCommandToPasteAlert(contents)
						}
					}
				} else {
					do {
						try print(runPrivileged(contents))
					} catch {
						MainActor.assumeIsolated {
							showRunInTerminalAlert(contents)
						}
					}
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

	@MainActor
	private static func showRunInTerminalAlert(_ contents: [String]) {
		let scriptBody = contents.dropFirst().joined(separator: "\n")
		let sudoScript = "sudo sh << 'SUDOEOF'\n\(scriptBody)\nSUDOEOF"

		let alert = NSAlert()
		alert.messageText = String(localized: "Admin rights required")
		alert.informativeText = String(localized: "Could not obtain admin privileges. Please run the following command in Terminal, then relaunch Caker:")

		let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
		textView.string = sudoScript
		textView.isEditable = false
		textView.isSelectable = true
		textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
		textView.backgroundColor = NSColor.windowBackgroundColor

		let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
		scrollView.documentView = textView
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = true
		scrollView.borderType = .bezelBorder

		alert.accessoryView = scrollView
		alert.addButton(withTitle: String(localized: "Copy & Quit"))
		alert.addButton(withTitle: String(localized: "Quit"))

		let response = alert.runModal()
		if response == .alertFirstButtonReturn {
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(sudoScript, forType: .string)
		}

		NSApp.terminate(self)
		return
	}

	@MainActor
	private static func showPrivilegedInstallationConfirmation() -> Bool {
		let alert = NSAlert()
		alert.messageText = String(localized: "Administrator Access Required")
		alert.informativeText = String(
			localized:
				"Caker needs to install privileged files to allow caked and cakectl to function. macOS will prompt for your administrator password via a system dialog. Click Continue to proceed, or Quit to exit.")
		alert.alertStyle = .informational
		alert.addButton(withTitle: String(localized: "Continue"))
		alert.addButton(withTitle: String(localized: "Quit"))
		return alert.runModal() == .alertFirstButtonReturn
	}

	@MainActor
	private static func showCommandToPasteAlert(_ contents: [String]) {
		let scriptBody = contents.dropFirst().joined(separator: "\n")
		let sudoScript = "sudo sh << 'SUDOEOF'\n\(scriptBody)\nSUDOEOF"

		let alert = NSAlert()
		alert.messageText = String(localized: "Manual configuration required")
		alert.informativeText = String(
			localized:
				"To allow use command caked and cakectl in terminal, path must be added to /etc/paths.d/com.aldunelabs.caker and sudoers must be added to /etc/sudoers.d/caked. Please run the following command in Terminal or do it later in settings.")

		let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
		textView.string = sudoScript
		textView.isEditable = false
		textView.isSelectable = true
		textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
		textView.backgroundColor = NSColor.windowBackgroundColor

		let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
		scrollView.documentView = textView
		scrollView.hasVerticalScroller = true
		scrollView.hasHorizontalScroller = true
		scrollView.borderType = .bezelBorder

		alert.accessoryView = scrollView
		alert.addButton(withTitle: String(localized: "Copy"))

		_ = alert.runModal()

		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(sudoScript, forType: .string)
	}

	static func askUserToInstallCakedAgent() {
		#if USE_SMAPPSERVICE
			if MainApp.isAgentInstalled() == false {
				MainActor.assumeIsolated {
					showInstallAgentAlert()
				}
			}
		#endif
	}

	#if USE_SMAPPSERVICE
		@MainActor
		private static func showInstallAgentAlert() {
			let alert = NSAlert()
			alert.messageText = String(localized: "caked Agent Not Installed")
			alert.informativeText = String(localized: "The caked background agent is not installed. Would you like to install it now to enable full functionality?")
			alert.alertStyle = .warning
			alert.addButton(withTitle: String(localized: "Install"))
			alert.addButton(withTitle: String(localized: "Later"))

			if alert.runModal() == .alertFirstButtonReturn {
				MainApp.installCakedService()
			}
		}
	#endif

	private static func installRootOwnedFile(content: String, to destination: URL, mode: String) throws -> [String] {
		var result: [String] = []

		let temporaryFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(destination.lastPathComponent)
		let parent = destination.deletingLastPathComponent()
		let logger = CakeAgentLib.Logger("MainUIAppDelegate")

		try? temporaryFile.delete()

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
				"rm -f \(temporaryFile.path)",
			])
		}

		return result
	}

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		guard AppState.shared.haveVirtualMachinesRunning() else {
			return .terminateNow
		}

		let alert = NSAlert()
		alert.messageText = String(localized: "Virtual Machines Running")
		alert.informativeText = String(localized: "Some virtual machines are currently running. Do you want to terminate them and quit?")
		alert.alertStyle = .warning
		alert.addButton(withTitle: String(localized: "Terminate All & Quit"))
		alert.addButton(withTitle: String(localized: "Cancel"))

		if alert.runModal() == .alertFirstButtonReturn {
			Task {
				await AppState.shared.stopOrSuspendAllRunningVirtualMachines {
					sender.reply(toApplicationShouldTerminate: true)
				}
			}

			return .terminateLater
		}

		return .terminateCancel
	}

	func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
		return false
	}

	func application(_ application: NSApplication, open urls: [URL]) {
		Task {
			for vmURL in urls {
				if let document = AppState.shared.tryVirtualMachineDocument(vmURL) {
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

	private static func runPrivilegedWithBundledScript(pathsContent: String, sudoersContent: String) throws -> String {
		guard let bundledURL = Bundle.main.url(forResource: "PrivilegedBootstrap", withExtension: "applescript") else {
			throw NSError(domain: NSOSStatusErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "PrivilegedBootstrap.applescript not found in bundle"])
		}

		let scriptsDir = try FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		let scriptURL = scriptsDir.appendingPathComponent("PrivilegedBootstrap.applescript")

		if FileManager.default.fileExists(atPath: scriptURL.path) {
			try FileManager.default.removeItem(at: scriptURL)
		}
		try FileManager.default.copyItem(at: bundledURL, to: scriptURL)

		defer {
			try? FileManager.default.removeItem(at: scriptURL)
		}

		// 'aevt'/'oapp' with argv list as keyDirectObject ('----')
		let event = NSAppleEventDescriptor.appleEvent(
			withEventClass: 0x6165_7674,
			eventID: 0x6F61_7070,
			targetDescriptor: .null(),
			returnID: -1,
			transactionID: 0
		)
		let argList = NSAppleEventDescriptor.list()
		argList.insert(NSAppleEventDescriptor(string: pathsContent), at: 0)
		argList.insert(NSAppleEventDescriptor(string: sudoersContent), at: 0)
		event.setParam(argList, forKeyword: 0x2D2D_2D2D)  // keyDirectObject

		let task = try NSUserAppleScriptTask(url: scriptURL)
		var taskResult: Result<String, Error> = .success("")
		let semaphore = DispatchSemaphore(value: 0)

		task.execute(withAppleEvent: event) { descriptor, error in
			if let error {
				taskResult = .failure(error)
			} else {
				taskResult = .success(descriptor?.stringValue ?? "")
			}
			semaphore.signal()
		}
		semaphore.wait()

		return try taskResult.get()
	}

	private static func shellQuote(_ value: String) -> String {
		let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
		return "'\(escaped)'"
	}

}
