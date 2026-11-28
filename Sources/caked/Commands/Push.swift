//
//  Push.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib

struct Push: AsyncParsableCommand {
	static let configuration = PushOptions.configuration

	@OptionGroup(title: String(localized: "Global options"))
	var common: CommonOptions

	@OptionGroup(title: String(localized: "Push VM options"))
	var options: PushOptions

	func validate() throws {
		Logger.setLevel(self.common.logLevel)

		guard StorageLocation(runMode: self.common.runMode).exists(self.options.localName) else {
			throw ValidationError(String(localized: "\(self.options.localName) does not exists"))
		}

	}

	func run() async throws {
		let options = self.options
		let runMode = self.common.runMode

		// Ctrl-C cancels: the temporary VM is killed and deleted, or the upload stops. References
		// already pushed stay in the registry.
		let reply = await Root.runCancellingOnInterrupt {
			await CakedLib.PushHandler.push(localName: options.localName,
											remoteNames: options.remoteNames,
											insecure: options.insecure,
											chunkSizeInMB: options.chunkSize,
											concurrency: options.concurrency,
											startMode: options.foreground ? .foreground : .attach,
											runMode: runMode,
											progressHandler: ProgressObserver.progressHandler)
		}

		Logger.appendNewLine(self.common.format.render(reply))

		// A cancelled push is not a success: the usual status of a command stopped by Ctrl-C
		if reply.success == false && TemporaryVMCancellation.isCancelled(reason: reply.message) {
			throw ArgumentParser.ExitCode(130)
		}
	}
}
