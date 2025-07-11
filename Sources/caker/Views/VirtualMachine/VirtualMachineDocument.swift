//
//  VirtualMachineDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import SwiftUI
import UniformTypeIdentifiers
import CakedLib
import GRPCLib

extension UTType {
	static var virtualMachine: UTType {
		UTType(importedAs: "com.aldunelabs.caker.caked-vm")
	}

	static var iso9660: UTType {
		UTType(importedAs: "public.iso-image")
	}
	
	static var unixSocketAddress: UTType {
		UTType(importedAs: "public.socket-address")
	}
}

class VirtualMachineDocument: FileDocument, VirtualMachineDelegate, ObservableObject, Equatable, Identifiable {
	static func == (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		lhs.virtualMachine == rhs.virtualMachine
	}

	static var readableContentTypes: [UTType] { [.virtualMachine] }

	enum Status: String {
		case none
		case running
		case suspended
		case stopped
	}

	var virtualMachine: VirtualMachine? = nil
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
		self.virtualMachine = nil
		self.name = name
	}

	required init(configuration: ReadConfiguration) throws {
		self.virtualMachine = nil

		guard configuration.file.isDirectory else {
			throw ServiceError("Internal error")
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
		if self.virtualMachine != nil {
			return true
		}

		do {
			let vmLocation = VMLocation(rootURL: fileURL, template: false)

			try vmLocation.validatate(userFriendlyName: vmLocation.name)
			try fileURL.updateAccessDate()

			let config = try vmLocation.config()

			let virtualMachine = try VirtualMachine(vmLocation: vmLocation, config: config, runMode: .app)

			self.virtualMachine = virtualMachine
			self.virtualMachineConfig = VirtualMachineConfig(vmname: vmLocation.name, config: config)
			self.name = vmLocation.name
			self.didChangedState(virtualMachine)

			virtualMachine.delegate = self
			return true
		} catch {
			alertError(error)
		}

		return false
	}

	func loadVirtualMachine() -> URL? {
		guard let virtualMachine = self.virtualMachine else {
			do {
				let storage = StorageLocation(runMode: .app)
				let location = try storage.find(name)
				let config = try location.config()
				let virtualMachine = try VirtualMachine(vmLocation: location, config: config, runMode: .app)

				self.virtualMachine = virtualMachine
				self.virtualMachineConfig = VirtualMachineConfig(vmname: name, config: config)
				self.didChangedState(virtualMachine)
				virtualMachine.delegate = self

				return location.rootURL
			} catch {
				alertError(error)
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

	func stopFromUI() {
		if let virtualMachine = self.virtualMachine {
			virtualMachine.stopFromUI()
		}
	}

	func requestStopFromUI() {
		if let virtualMachine = self.virtualMachine {
			try? virtualMachine.requestStopFromUI()
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

}
