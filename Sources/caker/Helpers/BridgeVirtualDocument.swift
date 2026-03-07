import CakedLib
//
//  BridgeVirtualDocument.swift
//  Caker
//
//  Created by Frederic BOLTZ on 01/11/2025.
//
import SwiftUI
import UniformTypeIdentifiers

struct BridgeVirtualDocument: FileDocument {
	static var readableContentTypes: [UTType] { [.virtualMachine] }

	var attachedVirtualDocument: VirtualMachineDocument

	init(configuration: ReadConfiguration) throws {
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
			self.attachedVirtualDocument = try VirtualMachineDocument.createVirtualMachineDocument(vmURL: vmURL)
		}

		func loadVM() throws {
			if self.attachedVirtualDocument.loadVirtualMachine() == nil {
				throw ServiceError("Unable to load virtual machine")
			}

			AppState.shared.replaceVirtualMachineDocument(self.attachedVirtualDocument.location.rootURL, with: self.attachedVirtualDocument)
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
		if self.attachedVirtualDocument.url.isFileURL {
			var cakeConfig: CakeConfig? = nil

			if let config = self.attachedVirtualDocument.virtualMachine?.config {
				cakeConfig = config
			} else if self.attachedVirtualDocument.url.isFileURL {
				cakeConfig = CakeConfig(config: self.attachedVirtualDocument.virtualMachineConfig)
			}

			if let cakeConfig {
				return try cakeConfig.fileWrapper()
			}
		}

		throw ServiceError("Virtual machine is remote")
	}
}
