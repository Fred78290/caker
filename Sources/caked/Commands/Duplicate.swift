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
	static let configuration = DuplicateOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Duplicate options")
	var duplicate: DuplicateOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let storageLocation = StorageLocation(asSystem: self.common.asSystem)
		let fromLocation = try storageLocation.find(self.duplicate.from)

		// Check if the VM exists
		if fromLocation.status == .running {
			throw ServiceError("VM \(self.duplicate.from) is running")
		}

		if storageLocation.exists(self.duplicate.to) {
			throw ServiceError("VM \(self.duplicate.to) already exists")
		}
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try DuplicateHandler.duplicate(from: self.duplicate.from,
		                                                                              to: self.duplicate.to,
		                                                                              resetMacAddress: self.duplicate.resetMacAddress,
		                                                                              asSystem: self.common.asSystem)))
	}
}
