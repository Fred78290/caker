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


class VirtualMachineDocument: FileDocument {
	static var readableContentTypes: [UTType] { [.VirtualMachine] }
	
	var virtualMachine: VirtualMachine?
	
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
			
			self.virtualMachine = try VirtualMachine(vmLocation: vmLocation, config: config, asSystem: false)
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
	
	func requestStopFromUI() throws {
		if let virtualMachine = self.virtualMachine {
			try virtualMachine.requestStopFromUI()
		}
	}
}
