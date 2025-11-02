//
//  BridgeVirtualDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 01/11/2025.
//
import SwiftUI
import CakedLib
import UniformTypeIdentifiers

class BridgeVirtualDocument: FileDocument {
	static var readableContentTypes: [UTType] { [.virtualMachine] }

	var attachedVirtualDocument: VirtualMachineDocument

	init() {
		self.attachedVirtualDocument = VirtualMachineDocument()
	}

	required init(configuration: ReadConfiguration) throws {
		let file = configuration.file

		guard file.isDirectory else {
			throw ServiceError("Internal error")
		}

		guard let fileName = file.filename else {
			throw ServiceError("Internal error")
		}

		guard let vmURL = file.contentsURL?.absoluteURL else {
			throw ServiceError("Unable to get URL for \(fileName)")
		}

		if let existingDocument = AppState.shared.findVirtualMachineDocument(vmURL) {
			self.attachedVirtualDocument = existingDocument
		} else {
			let location = VMLocation(rootURL: vmURL)

			try location.validatate(userFriendlyName: location.name)

			self.attachedVirtualDocument = try .init(location: location)
			AppState.shared.replaceVirtualMachineDocument(location.rootURL, with: self.attachedVirtualDocument)
		}

		func loadVM() throws {
			if self.attachedVirtualDocument.loadVirtualMachine() == nil {
				throw ServiceError("Unable to load virtual machine")
			}
		}

		if Thread.isMainThread {
			try loadVM()
		} else {
			try DispatchQueue.main.sync {
				try loadVM()
			}
		}
	}
	
	func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		throw ServiceError("Unimplemented")
	}
}
