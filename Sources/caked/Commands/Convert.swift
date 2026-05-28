//
//  Convert.swift
//  Caker
//
//  Created by Frederic BOLTZ on 28/05/2026.
//
import ArgumentParser
import CakedLib
import GRPCLib
import CakeAgentLib
import Foundation

struct Convert: ParsableCommand {
	public static let build = CommandConfiguration(commandName: "convert", abstract: String(localized: "Convert qcow2 to raw"))

	@Argument(help: ArgumentHelp(String(localized: "Source qcow2")))
	public var source: String

	@Argument(help: ArgumentHelp(String(localized: "Destination raw image")))
	public var destination: String

	func run() throws {
		let context = ProgressObserver.ProgressHandlerContext()
		let logger = Logger("Convert")

		logger.info("Converting \(source) to \(destination)")

		let sourceURL = URL(fileURLWithPath: source)
		let destinationURL = URL(fileURLWithPath: destination)

		try CloudImageConverter.convertCloudImageToRaw(from: sourceURL, to: destinationURL, progressHandler: ProgressObserver.progressHandler)

		logger.info("Conversion completed successfully")
	}



}
