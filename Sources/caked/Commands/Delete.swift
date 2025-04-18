//
//  Delete.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/02/2025.
//

import Foundation
import ArgumentParser
import GRPCLib
import TextTable
import Logging

struct Delete: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Delete a VM")
	
	@OptionGroup var common: CommonOptions

	@Argument(help: "VM name")
	var names: [String] = []

	@Flag(name: [.short, .long], help: "Delete all VM")
	var all: Bool = false

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		if all {
			if !names.isEmpty {
				throw ValidationError("You cannot specify both --all and VM names.")
			}
		} else if names.isEmpty {
			throw ValidationError("You must specify at least one VM name.")
		}
	}

	func run() throws {
		Logger.appendNewLine(self.common.format.render(try DeleteHandler.delete(all: self.all, names: self.names, asSystem: self.common.asSystem)))
	}
}
