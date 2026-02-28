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
	static let configuration = CommandConfiguration(commandName: "vmrun", abstract: "Run VM", shouldDisplay: false, aliases: ["run"])

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@Argument(help: "Path to the VM disk.img or his name")
	var path: String

	@Flag(name: [.customLong("service"), .customShort("l")], help: ArgumentHelp("VM running from service", discussion: "This option tell that vm run from service", visibility: .private))
	var launchedFromService: Bool = false

	@Flag(name: [.customLong("lima"), .customShort("m")], help: ArgumentHelp("Use socket-vmnet for network", visibility: .private))
	var useLimaVMNet: Bool = false

	@Flag(help: ArgumentHelp("VM Display mode", discussion: "This option allow display window of running vm or vnc server", visibility: .hidden))
	var display: VMRunHandler.DisplayMode = .none

	@Flag(help: ArgumentHelp("Service endpoint", discussion: "This option allow run vm in service mode", visibility: .hidden))
	var mode: VMRunServiceMode = .grpc

	@Option(help: ArgumentHelp("VNC server password", discussion: "This option allow run vnc server with password", visibility: .hidden))
	var vncPassword: String? = nil

	@Option(help: ArgumentHelp("VNC Server port", discussion: "This option allow run vnc server with custom port", visibility: .hidden))
	var vncPort: Int = 0

	@Option(help: ArgumentHelp("Screen size", discussion: "This option allow run vnc server with custom port", visibility: .hidden))
	var screenSize: ViewSize?

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
			throw ValidationError("VM at \(path) does not exist")
		}

		if location.status == .running {
			throw ValidationError("VM at \(path) is already running")
		}

		phUseLimaVMNet = self.useLimaVMNet
		MainApp.displayUI = display == .ui

		let config = try location.config()

		try config.sockets.forEach {
			try $0.validate()
		}

		if let console = config.console {
			try console.validate()
		}

		if self.launchedFromService {
			self.display = .vnc
		}
	}

	@MainActor
	func run() async throws {
		let (storageLocation, location) = self.locations
		let config = try location.config()
		let vncPassword = self.vncPassword ?? config.vncPassword
		let displaySize: CGSize

		if location.isPIDRunning() {
			throw ServiceError("The VM is already running")
		}

		if let screenSize = self.screenSize {
			displaySize = .init(width: screenSize.width, height: screenSize.height)
		} else {
			displaySize = config.display.cgSize
		}

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
			runMode: self.common.runMode)

		try handler.run { address, vm in
			address.whenSuccess { ip in
				if let ip {
					Logger(self).info("VM Machine is now available at \(ip)")
				}
			}

			if self.launchedFromService && self.common.runMode != .app {
				_ = Timer(timeInterval: 5, repeats: false) { _ in
					try? Utilities.group.next().makeFutureWithTask {
						try await vm.startGrandCentralUpdate(frequency: 1, runMode: self.common.runMode)
					}.wait()
				}
			}

			if display == .all || display == .vnc {
				let vncURL = try? vm.startVncServer(vncPassword: vncPassword, port: vncPort)

				Logger(self).info("VNC server started at \(vncURL?.absoluteString ?? "<failed to start VNC server>")")
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
