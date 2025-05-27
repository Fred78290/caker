import ArgumentParser
import Foundation
import GRPCLib
import Logging

struct Clone: ParsableCommand {
	static let configuration = CloneOptions.configuration

	@OptionGroup(title: "Global options")
	var common: CommonOptions

	@OptionGroup(title: "Clone options")
	var clone: CloneOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)
	}

	func run() throws {
		Logger.appendNewLine(
			self.common.format.render(
				try CloneHandler.clone(
					name: self.clone.newName,
					from: self.clone.sourceName,
					concurrency: self.clone.concurrency,
					deduplicate: self.clone.deduplicate,
					insecure: self.clone.insecure,
					direct: true,
					asSystem: self.common.asSystem)))
	}
}
