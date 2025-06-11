//
//  VirtualMachineDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 31/05/2025.
//
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
	static var VirtualMachine: UTType {
		UTType(importedAs: "com.aldunelabs.caker.caked-vm")
	}
}


class VirtualMachineDocument: FileDocument, VirtualMachineDelegate {
	static var readableContentTypes: [UTType] { [.VirtualMachine] }
	
	enum Status: String {
		case none
		case running
		case suspended
		case stopped
	}
	
	var virtualMachine: VirtualMachine? = nil
	var status: Status = .none
	var canStart: Bool = false
	var canStop: Bool = false
	var canPause: Bool = false
	var canResume: Bool = false
	var canRequestStop: Bool = false
	var suspendable: Bool = false
	
	init() {
		self.virtualMachine = nil
	}
	
	required init(configuration: ReadConfiguration) throws {
		self.virtualMachine = nil
		
		guard configuration.file.isDirectory else {
			throw ServiceError("Internal error")
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
			self.didChangedState(virtualMachine)

			virtualMachine.delegate = self
		} catch {
			print("Error loading \(fileURL): \(error)")
			return false
		}
		
		return true
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
	
	func didChangedState(_ vm: VirtualMachine) {
		guard let status = Status(rawValue: vm.vmLocation.status.rawValue) else {
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
