//
//  InfosHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/03/2026.
//

import Foundation
import CakedLib
import CakeAgentLib
import GRPCLib
import GRPC
import NIO

extension InfosHandler {
	public static func infos(client: CakedServiceClient?, rootURL: URL, runMode: Utils.RunMode) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {
		guard let client else {
			return try self.infos(rootURL: rootURL, runMode: runMode, client: try CakeAgentHelper.createCakeAgentHelper(rootURL: rootURL, runMode: runMode), callOptions: .init(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
		}

		guard let host = rootURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		let reply = try client.info(.with {
			$0.name = host
			$0.includeConfig = true
		}).response.wait().vms.status

		return (VMInformations(reply.infos), CakedConfiguration(reply.config))
	}
}
