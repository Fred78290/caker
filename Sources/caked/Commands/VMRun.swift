import ArgumentParser
import CakedLib
import CakeAgentLib
import Cocoa
import Foundation
import GRPCLib
import NIOPortForwarding
import System
import Virtualization

struct VMRun: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "vmrun", abstract: String(localized: "Run VM"), shouldDisplay: false, aliases: ["run"])

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@Flag(name: [.customLong("service"), .customShort("l")], help: ArgumentHelp(String(localized: "VM running from service"), discussion: String(localized: "This option tell that vm run from service"), visibility: .private))
	var launchedFromService: Bool = false

	@Flag(name: [.customLong("lima"), .customShort("m")], help: ArgumentHelp(String(localized: "Use socket-vmnet for network"), visibility: .private))
	var useLimaVMNet: Bool = false

	@Flag(help: ArgumentHelp(String(localized: "VM Display mode"), discussion: String(localized: "This option allows display window of running vm or vnc server"), visibility: .hidden))
	var display: VMRunHandler.DisplayMode = .none

	@Flag(help: ArgumentHelp(String(localized: "Service endpoint"), discussion: String(localized: "This option allows run vm in service mode"), visibility: .hidden))
	var mode: VMRunServiceMode = .grpc

	@Option(help: ArgumentHelp(String(localized: "VNC server password"), discussion: String(localized: "This option allows run vnc server with password"), visibility: .hidden))
	var vncPassword: String? = nil

	@Option(help: ArgumentHelp(String(localized: "VNC Server port"), discussion: String(localized: "This option allows run vnc server with custom port"), visibility: .hidden))
	var vncPort: Int = 0

	@Option(help: ArgumentHelp(String(localized: "Screen size"), discussion: String(localized: "This option allows setting custom screen size for the VM display"), visibility: .hidden))
	var screenSize: ViewSize?

	@Flag(name: [.customLong("gcd")], help: ArgumentHelp(String(localized: "Start grand central dispatch"), visibility: .private))
	var startGCD: Bool = false

	@Flag(name: [.customLong("recovery")], help: ArgumentHelp(String(localized: "Launch vm in recovery mode"), discussion: String(localized: "This option allows starting the MacOS VM in recovery mode")))
	var recoveryMode: Bool = false

	@Argument(help: ArgumentHelp(String(localized: "Path to the VM disk.img or his name")))
	var path: String

	var locations: (StorageLocation, VMLocation) {
		if StorageLocation(runMode: self.common.runMode).exists(path) {
			let storageLocation = StorageLocation(runMode: self.common.runMode)
			let vm = try! storageLocation.find(path)

			return (storageLocation, vm)
		} else {
			let u: URL = URL(fileURLWithPath: path)
			let parent = u.deletingLastPathComponent()
			let storage = parent.deletingLastPathComponent()
			let storageLocation = StorageLocation(runMode: self.common.runMode, name: storage.lastPathComponent)
			let vm = VMLocation(rootURL: parent, template: storageLocation.template)

			return (storageLocation, vm)
		}
	}

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let (_, location) = self.locations

		VMRunHandler.launchedFromService = self.launchedFromService
		VMRunHandler.serviceMode = self.mode

		if location.inited == false {
			throw ValidationError(String(localized: "VM at \(path) does not exist"))
		}

		if location.status == .running {
			throw ValidationError(String(localized: "VM at \(path) is already running"))
		}

		phUseLimaVMNet = self.useLimaVMNet
		MainApp.displayUI = display == .ui

		let config = try location.config()

		try config.sockets.forEach {
			try $0.validate()
		}

		if let console = config.console {
			try ConsoleAttachment(argument: console).validate()
		}

		if self.launchedFromService {
			self.display = .vnc
		}
	}

	@MainActor
	func run() async throws {
		let (storageLocation, location) = self.locations
		let config = try location.config()
		let vncPassword = self.vncPassword ?? config.vncPassword ?? UUID().uuidString
		let displaySize: CGSize
		var display = self.display
		var startGrandCentral = false

		if location.isPIDRunning() {
			throw ServiceError(String(localized: "The VM is already running"))
		}

		if let screenSize = self.screenSize {
			displaySize = .init(width: screenSize.width, height: screenSize.height)
		} else {
			displaySize = config.display.cgSize
		}

		if (self.launchedFromService && self.startGCD) || (self.launchedFromService == false && ServiceHandler.isAgentRunning) {
			startGrandCentral = true

			if display == .none {
				display = .vnc
			} else if display == .ui {
				display = .all
			}
		}

		let runMode = self.common.runMode
		let handler = CakedLib.VMRunHandler(
			mode: mode,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: display,
			config: config,
			screenSize: displaySize,
			vncPassword: vncPassword,
			vncPort: vncPort,
			recoveryMode: self.recoveryMode,
			runMode: runMode)

		try handler.run { address, vm in
			let logger = Logger(self)

			address.whenSuccess { ip in
				if let ip {
					logger.info("VM Machine \(location.name) is now available at \(ip)")
				}
			}

			// Check also manual launch
			if startGrandCentral {
				logger.info("Start GCD for VM: \(location.name)")

				try? Utilities.group.next().makeFutureWithTask {
					try await vm.startGrandCentralUpdate(frequency: 1, runMode: runMode)
				}.wait()
			}

			if display == .all || display == .vnc {
				if let vncURL = try? vm.startVncServer(vncPassword: vncPassword, port: vncPort) {
					logger.info("VNC server started at \(vncURL.map(\.absoluteString).joined(separator: ", "))")
				} else {
					logger.info("Failed to start VNC server")
				}

			} else if display == .ui {
				vm.createVirtualMachineView()
			}

			if display == .ui || display == .all {
				MainApp.runUI(vm, params: handler)
			} else {
				NSApplication.shared.setActivationPolicy(.prohibited)
				NSApplication.shared.run()
			}
		}
	}
}
