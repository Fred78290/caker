//
//  Duplicate.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/02/2025.
//

import ArgumentParser
import CakedLib
import Foundation
import GRPCLib
import CakeAgentLib
import TextTable

struct Duplicate: AsyncParsableCommand {
	static let configuration = DuplicateOptions.configuration

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Duplicate options"))
	var duplicate: DuplicateOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		let storageLocation = StorageLocation(runMode: self.common.runMode)
		let fromLocation = try storageLocation.find(self.duplicate.from)

		// Check if the VM exists
		if case .running = fromLocation.status {
			throw ServiceError(String(localized: "VM \(self.duplicate.from) is running"))
		}

		if storageLocation.exists(self.duplicate.to) {
			throw ServiceError(String(localized: "VM \(self.duplicate.to) already exists"))
		}
	}

	func run() async throws {
		let (from, to, resetMacAddress, runMode) = (self.duplicate.from, self.duplicate.to, self.duplicate.resetMacAddress, self.common.runMode)

		// Ctrl-C cancels: the temporary VM is killed and deleted, and the reply says "Cancelled".
		let reply = await Root.runCancellingOnInterrupt {
			await CakedLib.DuplicateHandler.duplicate(from: from, to: to, resetMacAddress: resetMacAddress, runMode: runMode)
		}

		Logger.appendNewLine(self.common.format.render(reply))

		// A cancelled duplicate is not a success: the usual status of a command stopped by Ctrl-C
		if reply.duplicated == false && TemporaryVMCancellation.isCancelled(reason: reply.reason) {
			throw ArgumentParser.ExitCode(130)
		}
	}
}
