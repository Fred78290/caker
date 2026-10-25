//
//  ComposeOptions.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/10/2026.
//

import ArgumentParser

public struct ComposeOptions: ParsableArguments {
	@Option(
		name: [.customLong("file"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Path to compose file"), valueName: "path"))
	public var file: String? = nil

	@Option(
		name: [.customLong("name"), .customShort("n")],
		help: ArgumentHelp(String(localized: "Name of the registered compose project"), valueName: "name"))
	public var name: String? = nil

	@Argument(help: ArgumentHelp(String(localized: "Services to apply (default: all)")))
	public var services: [String] = []
	
	public init() {
	}
}
