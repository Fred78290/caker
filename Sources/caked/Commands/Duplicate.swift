//
//  Duplicate.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/02/2025.
//

import Foundation
import ArgumentParser
import GRPCLib
import TextTable
import Logging

struct Duplicate: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Duplicate a VM to a new name")
	
	@OptionGroup var common: CommonOptions

	@Argument(help: "Source VM name")
	var from: String

	@Argument(help: "Duplicated VM name")
	var to: String

	@Option(name: .shortAndLong, help: "Reset mac address")
	var resetMacAddress: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let storageLocation = StorageLocation(asSystem: self.common.asSystem)
		let fromLocation = try storageLocation.find(from)

		// Check if the VM exists
		if fromLocation.status == .running {
			throw ServiceError("VM \(from) is running")
		}

		if storageLocation.exists(to) {
			throw ServiceError("VM \(to) already exists")
		}
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try DuplicateHandler.duplicate(from: self.from, to: self.to, resetMacAddress:  self.resetMacAddress, asSystem: self.common.asSystem)))
	}
}
