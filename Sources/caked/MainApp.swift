import Foundation
import SwiftUI
import Virtualization

struct MainApp: App {
	static var suspendable: Bool = false
	static var capturesSystemKeys: Bool = false
	static var _vm: VirtualMachine? = nil

	static var vm: VirtualMachine {
		get {
			return _vm!
		}
		set {
			_vm = newValue
		}
	}

	@NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

	var body: some Scene {
		WindowGroup(MainApp.vm.name) {
			let display = MainApp.vm.config.display

			Group {
				VMView(vm: MainApp.vm, capturesSystemKeys: MainApp.capturesSystemKeys).onAppear {
					NSWindow.allowsAutomaticWindowTabbing = false
				}.onDisappear {
					let ret = kill(getpid(), MainApp.suspendable ? SIGUSR1 : SIGINT)
					if ret != 0 {
						// Fallback to the old termination method that doesn't
						// propagate the cancellation to Task's in case graceful
						// termination via kill(2) is not successful
						NSApplication.shared.terminate(self)
					}
				}
			}.frame(
				minWidth: CGFloat(display.width),
				idealWidth: CGFloat(display.width),
				maxWidth: .infinity,
				minHeight: CGFloat(display.height),
				idealHeight: CGFloat(display.height),
				maxHeight: .infinity
			)
		}.commands {
			// Remove some standard menu options
			CommandGroup(replacing: .help, addition: {})
			CommandGroup(replacing: .newItem, addition: {})
			CommandGroup(replacing: .pasteboard, addition: {})
			CommandGroup(replacing: .textEditing, addition: {})
			CommandGroup(replacing: .undoRedo, addition: {})
			CommandGroup(replacing: .windowSize, addition: {})
			// Replace some standard menu options
			CommandGroup(replacing: .appInfo) { AboutTart(config: MainApp.vm.config) }
			CommandMenu("Control") {
				Button("Start") {
					Task { try await MainApp.vm.virtualMachine.start() }
				}
				Button("Stop") {
					Task { try await MainApp.vm.virtualMachine.stop() }
				}
				Button("Request Stop") {
					Task { try MainApp.vm.virtualMachine.requestStop() }
				}
				if #available(macOS 14, *) {
					if (MainApp.suspendable) {
						Button("Suspend") {
							kill(getpid(), SIGUSR1)
						}
					}
				}
			}
		}
	}

	static func runUI(vm: VirtualMachine, _ suspendable: Bool, _ captureSystemKeys: Bool) {
		MainApp.suspendable = suspendable
		MainApp.capturesSystemKeys = captureSystemKeys
		MainApp.vm = vm
		MainApp.main()
	}
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
	var suspendable: Bool = false

	func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		if (kill(getpid(), self.suspendable ? SIGUSR1 : SIGINT) == 0) {
			return .terminateLater
		} else {
			return .terminateNow
		}
	}
}

struct AboutTart: View {
	var credits: NSAttributedString

	init(config: CakeConfig) {
		let mutableAttrStr = NSMutableAttributedString()
		let style = NSMutableParagraphStyle()
		style.alignment = NSTextAlignment.center
		let attrCenter: [NSAttributedString.Key : Any] = [
			.paragraphStyle: style,
		]
		mutableAttrStr.append(NSAttributedString(string: "CPU: \(config.cpuCount) cores\n", attributes: attrCenter))
		mutableAttrStr.append(NSAttributedString(string: "Memory: \(config.memorySize / 1024 / 1024) MB\n", attributes: attrCenter))
		mutableAttrStr.append(NSAttributedString(string: "Display: \(config.display.description)\n", attributes: attrCenter))
		mutableAttrStr.append(NSAttributedString(string: "https://github.com/cirruslabs/tart", attributes: [
			.paragraphStyle: style,
			.link : "https://github.com/cirruslabs/tart"
		]))
		credits = mutableAttrStr
	}

	var body: some View {
		Button("About Tart") {
			NSApplication.shared.orderFrontStandardAboutPanel(options: [
				NSApplication.AboutPanelOptionKey.applicationIcon: NSApplication.shared.applicationIconImage as Any,
				NSApplication.AboutPanelOptionKey.applicationName: "Tart",
				NSApplication.AboutPanelOptionKey.applicationVersion: CI.version,
				NSApplication.AboutPanelOptionKey.credits: credits,
			])
		}
	}
}

struct VMView: NSViewRepresentable {
	typealias NSViewType = VZVirtualMachineView

	@ObservedObject var vm: VirtualMachine
	var capturesSystemKeys: Bool

	func makeNSView(context: Context) -> NSViewType {
		let machineView = VZVirtualMachineView()

		machineView.capturesSystemKeys = capturesSystemKeys

		// If not specified, enable automatic display
		// reconfiguration for guests that support it
		//
		// This is disabled for Linux because of poor HiDPI
		// support, which manifests in fonts being too small
		if #available(macOS 14.0, *), vm.config.displayRefit || (vm.config.os != .linux) {
			machineView.automaticallyReconfiguresDisplay = true
		}

		return machineView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.virtualMachine = vm.virtualMachine
	}
}
