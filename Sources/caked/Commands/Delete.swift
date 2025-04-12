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

struct Delete: ParsableCommand {
	static let configuration = CommandConfiguration(abstract: "Delete a VM")
	
	@Argument(help: "VM name")
	var name: [String]

	@Option(name: .shortAndLong, help: "Output format")
	var format: Format = .text

	func run() throws {
		Logger.appendNewLine(self.format.render(try DeleteHandler.delete(names: name, asSystem: false)))
	}
}
