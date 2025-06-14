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

class VirtualMachineDocument: FileDocument, VirtualMachineDelegate, ObservableObject, Equatable {
	static func == (lhs: VirtualMachineDocument, rhs: VirtualMachineDocument) -> Bool {
		lhs.virtualMachine == rhs.virtualMachine
	}

	static var readableContentTypes: [UTType] { [.VirtualMachine] }

	enum Status: String {
		case none
		case running
		case suspended
		case stopped
	}

	var virtualMachine: VirtualMachine? = nil
	var name: String = ""

	@Published var status: Status = .none
	@Published var canStart: Bool = false
	@Published var canStop: Bool = false
	@Published var canPause: Bool = false
	@Published var canResume: Bool = false
	@Published var canRequestStop: Bool = false
	@Published var suspendable: Bool = false

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
			self.name = vmLocation.name
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
		let vmStatus = vm.status

		print("didChangedState: \(vmStatus)")

		guard let status = Status(rawValue: vmStatus.rawValue) else {
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
