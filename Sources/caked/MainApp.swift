import Foundation
import SwiftUI
import Virtualization

struct MainApp: App {
	static var _vm: VirtualMachine? = nil
	static var _config: CakeConfig? = nil
	static var _name: String? = nil
	static var _virtualMachine: VZVirtualMachine? = nil

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

	static var virtualMachine: VZVirtualMachine {
		get {
			return _virtualMachine!
		}
		set {
			_virtualMachine = newValue
		}
	}

	static var name: String {
		get {
			return _name!
		}
		set {
			_name = newValue
		}
	}

	static var config: CakeConfig {
		get {
			return _config!
		}
		set {
			_config = newValue
		}
	}

	static var vm: VirtualMachine {
		get {
			return _vm!
		}
		set {
			_vm = newValue
		}
	}

	var body: some Scene {
		WindowGroup(MainApp.name) {
			let display = MainApp.config.display
			let minWidth = CGFloat(display.width)
			let idealWidth = CGFloat(display.width)
			let minHeight = CGFloat(display.height)
			let idealHeight = CGFloat(display.height)

			Group {
				VMView(config: MainApp.config, vm: MainApp.vm, virtualMachine: MainApp.virtualMachine).onAppear {
					NSWindow.allowsAutomaticWindowTabbing = false
				}.onDisappear {
					let ret = kill(getpid(), SIGINT)
					if ret != 0 {
						NSApplication.shared.terminate(self)
					}
				}
			}.frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: .infinity, minHeight: minHeight, idealHeight: idealHeight, maxHeight: .infinity)
		}.commands {
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			CommandGroup(replacing: .appInfo) { AboutCaker(config: MainApp.config) }
			CommandMenu("Control") {
				Button("Start") {
					Task { MainApp.vm.startFromUI() }
				}
				Button("Stop") {
					Task { MainApp.vm.stopFromUI() }
				}
				Button("Request Stop") {
					Task { try MainApp.vm.requestStopFromUI() }
				}
			}
		}
	}

	static func runUI(name: String, vm: VirtualMachine, config: CakeConfig) {
		MainApp.vm = vm
		MainApp.virtualMachine = vm.getVM()
		MainApp.name = name
		MainApp.config = config
		MainApp.main()
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		if kill(getpid(), SIGINT) == 0 {
			return .terminateLater
		} else {
			return .terminateNow
		}
	}
}

struct AboutCaker: View {
	var infos: NSAttributedString

	init(config: CakeConfig) {
		let infos = NSMutableAttributedString()
		let style: NSMutableParagraphStyle = NSMutableParagraphStyle()

		style.alignment = NSTextAlignment.center

		let center: [NSAttributedString.Key: Any] = [.paragraphStyle: style]

		infos.append(NSAttributedString(string: "CPU: \(config.cpuCount) cores\n", attributes: center))
		infos.append(NSAttributedString(string: "Memory: \(ByteCountFormatter.string(fromByteCount: Int64(config.memorySize), countStyle: .memory))\n", attributes: center))
		infos.append(NSAttributedString(string: "User: \(config.configuredUser)\n", attributes: center))

		if let runningIP = config.runningIP {
			infos.append(NSAttributedString(string: "IP: \(runningIP)\n", attributes: center))
		}

		self.infos = infos
	}

	var body: some View {
		Button("About Caked") {
			NSApplication.shared.orderFrontStandardAboutPanel(options: [
				NSApplication.AboutPanelOptionKey.applicationIcon: NSApplication.shared.applicationIconImage as Any,
				NSApplication.AboutPanelOptionKey.applicationName: "Caked",
				NSApplication.AboutPanelOptionKey.applicationVersion: CI.version,
				NSApplication.AboutPanelOptionKey.credits: self.infos,
			])
		}
	}
}

struct VMView: NSViewRepresentable {
	typealias NSViewType = VZVirtualMachineView

	let config: CakeConfig

	@ObservedObject
	var vm: VirtualMachine
	var virtualMachine: VZVirtualMachine

	func makeNSView(context: Context) -> NSViewType {
		let machineView = VZVirtualMachineView()
		if #available(macOS 14.0, *), config.displayRefit || (config.os == .darwin) {
			machineView.automaticallyReconfiguresDisplay = true
		}

		return machineView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.virtualMachine = virtualMachine
	}
}
