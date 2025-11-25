//
//  Pull.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import ArgumentParser
import CakedLib
import GRPCLib
import Logging

struct Pull: AsyncParsableCommand {
	static let configuration = PullOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Clone OCI image options")
	var options: PullOptions

	mutating func validate() throws {
		Logger.setLevel(self.common.logLevel)

		try options.validate()
	}

	func run() async throws {
		Logger.appendNewLine(
			self.common.format.render(await CakedLib.PullHandler.pull(name: self.options.name, image: self.options.image, insecure: self.options.insecure, runMode: self.common.runMode, progressHandler: ProgressObserver.progressHandler)))
	}
}
