//
//  CakeAgentHelper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/03/2026.
//
import Foundation
import CakeAgentLib
import GRPCLib
import GRPC

extension CakeAgentHelper {
	public static func createCakeAgentHelper(name: String, connectionTimeout: Int64 = 1, retries: ConnectionBackoff.Retries = .upTo(1), runMode: Utils.RunMode) throws -> CakeAgentHelper {
		// Create a short-lived client for the health check
		let eventLoop = Utilities.group.next()
		let client = try Utilities.createCakeAgentClient(
			on: eventLoop.next(),
			runMode: runMode,
			name: name,
			connectionTimeout: connectionTimeout,
			retries: retries
		)

		return CakeAgentHelper(on: eventLoop, client: client)
	}

	public static func createCakeAgentHelper(location: VMLocation, connectionTimeout: Int64 = 1, retries: ConnectionBackoff.Retries = .upTo(1), runMode: Utils.RunMode) throws -> CakeAgentHelper {
		// Create a short-lived client for the health check
		let eventLoop = Utilities.group.next()
		let client = try Utilities.createCakeAgentClient(
			on: eventLoop.next(),
			runMode: runMode,
			location: location,
			connectionTimeout: connectionTimeout,
			retries: retries
		)

		return CakeAgentHelper(on: eventLoop, client: client)
	}

	public static func createCakeAgentHelper(rootURL: URL, connectionTimeout: Int64 = 1, retries: ConnectionBackoff.Retries = .upTo(1), runMode: Utils.RunMode) throws -> CakeAgentHelper {
		// Create a short-lived client for the health check
		let eventLoop = Utilities.group.next()
		let client = try Utilities.createCakeAgentClient(
			on: eventLoop.next(),
			runMode: runMode,
			rootURL: rootURL,
			connectionTimeout: connectionTimeout,
			retries: retries
		)

		return CakeAgentHelper(on: eventLoop, client: client)
	}
}
