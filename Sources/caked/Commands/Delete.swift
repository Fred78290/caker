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

public struct Delete: ParsableCommand {
	public init() {}
	
	@Argument(help: "VM name")
	var name: [String]

	@Option(name: [.customLong("format")], help: "Output format")
	var format: Format = .text

	public mutating func run() throws {
		print(format.renderList(style: Style.grid, uppercased: true, try DeleteHandler.delete(names: name, asSystem: false)))
	}
}
