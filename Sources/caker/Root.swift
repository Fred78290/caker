//
//  Root.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/03/2026.
//
import Foundation
import ArgumentParser
import CakeAgentLib
import CakedLib
import GRPCLib
import Logging

//@main
struct Root {
	public static func main() async throws {
		_ = try? MainAppParseArgument.parse(CommandLine.arguments)

		await AppState.loadSharedAppState()

		CakeAgentLib.Logger("main").info("Caker is starting...")
		//MainApp.main()

		try? await Utilities.group.shutdownGracefully()
    }
}
