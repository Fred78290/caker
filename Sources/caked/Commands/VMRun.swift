import ArgumentParser
import CakedLib
import Cocoa
import Foundation
import GRPCLib
import Logging
import NIOPortForwarding
import System
import Virtualization

struct ViewSize: Codable, Identifiable, Hashable, ExpressibleByArgument {
	var id: String {
		"\(width)x\(height)"
	}
	var width: Int
	var height: Int
	var size: CGSize {
		.init(width: CGFloat(width), height: CGFloat(height))
	}

	init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}

	init(argument: String) {
		let parts = argument.components(separatedBy: "x").map {
			Int($0) ?? 0
		}

		self = ViewSize(
			width: parts.first ?? 0,
			height: parts.count > 0 ? parts[1] : 0
		)
	}
}

struct VMRun: AsyncParsableCommand {
	static let configuration = CommandConfiguration(commandName: "vmrun", abstract: "Run VM", shouldDisplay: false)

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

	@Option(help: ArgumentHelp("VNC capture method", discussion: "This option allow choose the capture method of vnc", visibility: .hidden))
	var captureMethod: VNCCaptureMethod = .coreGraphics

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
			mode,
			storageLocation: storageLocation,
			location: location,
			name: location.name,
			display: display,
			config: config,
			screenSize: displaySize,
			vncPassword: vncPassword,
			vncPort: vncPort,
			captureMethod: captureMethod,
			runMode: self.common.runMode)

		try handler.run() { address, vm in
			address.whenSuccess { ip in
				if let ip {
					Logger(self).info("VM Machine is now available at \(ip)")
				}
			}

			if display == .all {
				let vncURL = try? vm.startVncServer(vncPassword: vncPassword, port: vncPort, captureMethod: captureMethod)

				Logger(self).info("VNC server started at \(vncURL?.absoluteString ?? "<failed to start VNC server>")")
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
