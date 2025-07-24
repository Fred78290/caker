//
//  VirtualMachineDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import SwiftUI
import UniformTypeIdentifiers
import GRPC
import GRPCLib
import FileMonitor
import FileMonitorShared
import NIO
import CakedLib
import CakeAgentLib
import SwiftTerm

extension UTType {
	static var virtualMachine: UTType {
		UTType(importedAs: "com.aldunelabs.caker.caked-vm")
	}

	static var iso9660: UTType {
		UTType(importedAs: "public.iso-image")
	}
	
	static var ipsw: UTType {
		UTType(filenameExtension: "ipsw")!
	}

	static var sshPublicKey: UTType {
		UTType(filenameExtension: "pub")!
	}

	static var unixSocketAddress: UTType {
		UTType(importedAs: "public.socket-address")
	}
}

class VirtualMachineDocument: FileDocument, VirtualMachineDelegate, FileDidChangeDelegate, ObservableObject, Equatable, Identifiable {
	typealias ShellHandlerResponse = (Cakeagent_CakeAgent.ExecuteResponse) -> Void

	static func == (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		lhs.virtualMachine == rhs.virtualMachine
	}

	static var readableContentTypes: [UTType] { [.virtualMachine] }

	enum Status: String {
		case none
		case running
		case external
		case suspended
		case stopped
	}

	private var client: CakeAgentClient!
	private var stream: CakeAgentExecuteStream!
	private var shellHandlerResponse: ShellHandlerResponse!
	private var monitor: FileMonitor?
	private var inited = false

	var virtualMachine: VirtualMachine!
	var location: VMLocation?
	var name: String = ""
	var description: String {
		name
	}

	@Published var virtualMachineConfig: VirtualMachineConfig = .init()
	@Published var status: Status = .none
	@Published var canStart: Bool = false
	@Published var canStop: Bool = false
	@Published var canPause: Bool = false
	@Published var canResume: Bool = false
	@Published var canRequestStop: Bool = false
	@Published var suspendable: Bool = false

	init() {
		self.virtualMachine = nil
		self.virtualMachineConfig = VirtualMachineConfig()
	}

	init(name: String) {
		self.name = name
	}

	required init(configuration: ReadConfiguration) throws {
		let file = configuration.file

		guard file.isDirectory else {
			throw ServiceError("Internal error")
		}

		if let fileName = file.filename {
			let vmName = fileName.deletingPathExtension
			let location = StorageLocation(runMode: .app).location(vmName)

			if file.matchesContents(of: location.rootURL) {
				AppState.shared.replaceVirtualMachineDocument(location.rootURL, with: self)
				
				try DispatchQueue.main.sync {
					if loadVirtualMachine(from: location.rootURL) == false {
						throw ServiceError("Unable to load virtual machine")
					}
				}
			}
		}
	}

	func close() {
		self.virtualMachine = nil
		self.inited = false
		self.status = .none
		
		if let monitor = self.monitor {
			monitor.stop()
		}
		
		if self.client != nil {
			self.client.close().whenComplete { _ in
				self.client = nil
				self.stream = nil
			}
		}
	}

	func alertError(_ error: Error) {
		if let error = error as? ServiceError {
			let alert = NSAlert()
			
			alert.messageText = "Failed to start VM"
			alert.informativeText = error.description
			alert.runModal()
		} else {
			let alert = NSAlert(error: error)
			
			alert.messageText = "Failed to start VM"
			alert.runModal()
		}
	}

	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		throw ServiceError("Unimplemented")
	}

	func loadVirtualMachine(from fileURL: URL) -> Bool {
		if inited {
			return true
		}

		defer {
			inited = true
		}

		do {
			let vmLocation = try VMLocation(rootURL: fileURL, template: false).validatate(userFriendlyName: fileURL.lastPathComponent)
			let config = try vmLocation.config()

			try fileURL.updateAccessDate()

			self.virtualMachineConfig = VirtualMachineConfig(vmname: vmLocation.name, config: config)
			self.name = vmLocation.name
			self.location = vmLocation

			if vmLocation.pidFile.isPIDRunning("caked") {
				self.status = .external
				
				self.canStart = false
				self.canStop = true
				self.canPause = true
				self.canResume = false
				self.canRequestStop = true
				self.suspendable = config.suspendable
							}
			else
			{
				let virtualMachine = try VirtualMachine(vmLocation: vmLocation, config: config, runMode: .app)

				self.virtualMachine = virtualMachine
				self.didChangedState(virtualMachine)

				virtualMachine.delegate = self
			}

			if monitor == nil {
				let monitor = try FileMonitor(directory: fileURL, delegate: self )
				try monitor.start()
				
				self.monitor = monitor
			}

			return true
		} catch {
            DispatchQueue.main.async {
                self.alertError(error)
            }
		}

		return false
	}

	func loadVirtualMachine() -> URL? {
		guard let virtualMachine = self.virtualMachine else {
			do {
				let location = try StorageLocation(runMode: .app).find(name)
				let config = try location.config()

				self.virtualMachineConfig = VirtualMachineConfig(vmname: name, config: config)
				self.location = location

				if location.pidFile.isPIDRunning("caked") {
					self.status = .external

					self.canStart = false
					self.canStop = true
					self.canPause = true
					self.canResume = false
					self.canRequestStop = true
					self.suspendable = config.suspendable
				} else {
					let virtualMachine = try VirtualMachine(vmLocation: location, config: config, runMode: .app)

					self.virtualMachine = virtualMachine
					self.didChangedState(virtualMachine)
					virtualMachine.delegate = self
				}

				return location.rootURL
			} catch {
                DispatchQueue.main.async {
                    self.alertError(error)
                }
			}

			return nil
		}
		
		return virtualMachine.vmLocation.rootURL
	}

	func startFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.startFromUI()
		}
	}

	func restartFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.restartFromUI()
		} else if self.status == .external {
			do {
				let result = try StopHandler.restart(name: self.name, force: false, runMode: .app)
				
				if result.stopped == false {
					self.alertError(ServiceError(result.reason))
				}
			} catch {
				self.alertError(error)
			}
		}
	}

	func stopFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.stopFromUI()
		} else if self.status == .external {
			do {
				let result = try StopHandler.stopVM(name: self.name, force: true, runMode: .app)
				
				if result.stopped == false {
					self.alertError(ServiceError(result.reason))
				}
			} catch {
				self.alertError(error)
			}
		}
	}

	func requestStopFromUI() {
		if let virtualMachine = self.virtualMachine {
			try? virtualMachine.requestStopFromUI()
		} else if self.status == .external {
			do {
				let result = try StopHandler.stopVM(name: self.name, force: false, runMode: .app)
				
				if result.stopped == false {
					self.alertError(ServiceError(result.reason))
				}
			} catch {
				self.alertError(error)
			}
		}
	}

	func suspendFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.suspendFromUI()
		}
	}

	func createTemplateFromUI(name: String) -> CreateTemplateReply {
		do {
			return try TemplateHandler.createTemplate(on: Utilities.group.next(), sourceName: self.virtualMachine!.vmLocation.name, templateName: name, runMode: .app)
		} catch {
			guard let error = error as? ServiceError else {
				return .init(name: name, created: false, reason: error.localizedDescription)
			}

			return .init(name: name, created: false, reason: error.description)
		}
	}

	func didChangedState(_ vm: VirtualMachine) {
		guard let status = Status(rawValue: vm.status.rawValue) else {
			self.status = .none
			return
		}

		self.canStart = vm.virtualMachine.canStart
		self.canStop = vm.virtualMachine.canStop
		self.canPause = vm.virtualMachine.canPause
		self.canResume = vm.virtualMachine.canResume
		self.canRequestStop = vm.virtualMachine.canRequestStop
		self.suspendable = vm.suspendable
		self.status = status
	}

	func fileDidChanged(event: FileChangeEvent) {
		guard let location = self.location, self.virtualMachine == nil else {
			return
		}

		let check: (URL) -> Void = { file in
			if file == location.pidFile {
				if file.isPIDRunning("caked") {
					self.status = .external

					self.canStart = false
					self.canStop = true
					self.canPause = true
					self.canResume = false
					self.canRequestStop = true
					self.suspendable = self.virtualMachineConfig.suspendable
				} else {
					self.status = .stopped

					self.canStart = true
					self.canStop = false
					self.canPause = false
					self.canResume = false
					self.canRequestStop = false
					self.suspendable = false
				}
			}
		}

		switch event {
			case .added(let file):
				check(file)
			case .deleted(let file):
				check(file)
			case .changed(let file):
				check(file)
		}
	}
}

extension VirtualMachineDocument {
	func sendTerminalSize(rows: Int, cols: Int) {
		if let stream = self.stream {
			stream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
		}
	}

	func sendDatas(data: ArraySlice<UInt8>) {
		if let stream = self.stream {
			data.withUnsafeBytes { ptr in
				let message = CakeAgent.ExecuteRequest.with {
					$0.input = Data(bytes: ptr.baseAddress!, count: ptr.count)
				}

				try? stream.sendMessage(message).wait()
			}
		}
	}

	func closeShell(_ completionHandler: (() -> Void)? = nil) {
		if self.stream == nil {
			return
		}

		self.client.close().whenComplete { _ in
			DispatchQueue.main.async {
				completionHandler?()
			}
		}
		self.client = nil
		self.stream = nil
	}

	func startShell(rows: Int, cols: Int, handler: @escaping (Cakeagent_CakeAgent.ExecuteResponse) -> Void) throws {
		self.shellHandlerResponse = handler

		guard self.stream == nil else {
			return
		}

		if self.client == nil {
			self.client = try Utilities.createCakeAgentClient(on: Utilities.group.next(), runMode: .app, name: name)
		}

		self.stream = client.execute(callOptions: CallOptions(timeLimit: .none)) { response in
			self.shellHandlerResponse(response)
		}
		
		stream.sendTerminalSize(rows: Int32(rows), cols: Int32(cols))
		stream.sendShell()
	}
}

extension NSNotification {
	static let NewVirtualMachine = NSNotification.Name("NewVirtualMachine")
	static let OpenVirtualMachine = NSNotification.Name("OpenVirtualMachine")
	static let StartVirtualMachine = NSNotification.Name("StartVirtualMachine")
	static let DeleteVirtualMachine = NSNotification.Name("DeleteVirtualMachine")
}
