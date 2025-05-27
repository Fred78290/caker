//
//  Delete.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/02/2025.
//

import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable

struct Delete: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Delete a VM")

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Delete options")
	var delete: DeleteOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try DeleteHandler.delete(all: self.delete.all, names: self.delete.names, asSystem: self.common.asSystem)))
	}
}
