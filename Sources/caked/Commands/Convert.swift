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
	enum InputFormat: String, ExpressibleByArgument {
		case vmdk
		case qcow2
	}

	static let configuration = CommandConfiguration(commandName: "convert", abstract: String(localized: "Convert vmdk or qcow2 image to raw"))

	@Argument(help: ArgumentHelp(String(localized: "Source image disk to convert")))
	var source: String

	@Argument(help: ArgumentHelp(String(localized: "Destination raw image")))
	var destination: String

	@Option(name: [ .customLong("source-format"), .customShort("f")], help: ArgumentHelp(String(localized: "Source image disk format")))
	var format: InputFormat = .qcow2

	func run() throws {
		let logger = Logger("Convert")

		logger.info(String(localized: "Converting \(source) to \(destination)"))

		let sourceURL = URL(fileURLWithPath: source.expandingTildeInPath)
		let destinationURL = URL(fileURLWithPath: destination.expandingTildeInPath)

		switch format {
		case .vmdk:
			try CloudImageConverter.convertVmdkToRaw(from: sourceURL, to: destinationURL, progressHandler: ProgressObserver.progressHandler)
		case .qcow2:
			try CloudImageConverter.convertCloudImageToRaw(from: sourceURL, to: destinationURL, progressHandler: ProgressObserver.progressHandler)
		}

		logger.info(String(localized: "Conversion completed successfully"))
	}
}
