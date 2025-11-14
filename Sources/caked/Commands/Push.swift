//
//  Push.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import ArgumentParser
import CakedLib
import GRPCLib
import Logging

struct Push: AsyncParsableCommand {
	static let configuration = PushOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Push VM options")
	var options: PushOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		guard StorageLocation(runMode: self.common.runMode).exists(self.options.localName) else {
			throw ValidationError("\(self.options.localName) does not exists")
		}

	}

	func run() async throws {
		Logger.appendNewLine(self.common.format.render(await CakedLib.PushHandler.push(localName: self.options.localName, remoteNames: self.options.remoteNames, insecure: self.options.insecure, chunkSize: self.options.chunkSize, runMode: self.common.runMode, progressHandler: ProgressObserver.progressHandler)))
	}
}
