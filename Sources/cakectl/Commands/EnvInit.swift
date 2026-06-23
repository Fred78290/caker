//
//  EnvInit.swift
//  cakectl
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import ArgumentParser
import CakedLib
import CakeAgentLib
import Foundation

struct EnvInit: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "init",
		abstract: String(localized: "Create a .cakerenv template in the current directory"),
		discussion: String(localized: "Writes a commented .cakerenv YAML file with sensible defaults. Edit it, then run `cakectl up` to start the VM.")
	)

	@Flag(
		name: [.customLong("force"), .customShort("f")],
		help: ArgumentHelp(String(localized: "Overwrite an existing .cakerenv")))
	var force: Bool = false

	func run() throws {
		let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		let dest = cwd.appendingPathComponent(CakerEnv.filename)

		if FileManager.default.fileExists(atPath: dest.path) && !force {
			throw ValidationError(String(localized: "\(CakerEnv.filename) already exists — use --force to overwrite."))
		}

		try CakerEnv.template.write(to: dest, atomically: true, encoding: .utf8)
		Logger.appendNewLine(String(localized: "Created \(dest.path)"))
		Logger.appendNewLine(String(localized: "Edit \(CakerEnv.filename) then run `cakectl up` to start your VM."))
	}
}
