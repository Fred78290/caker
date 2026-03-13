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
	public static func infos(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {
		guard let client else {
			return try self.infos(vmURL: vmURL, runMode: runMode, client: try CakeAgentHelper.createCakeAgentHelper(vmURL: vmURL, runMode: runMode), callOptions: .init(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
		}

		if vmURL.isFileURL {
			return try self.infos(vmURL: vmURL, runMode: runMode, client: try CakeAgentHelper.createCakeAgentHelper(vmURL: vmURL, runMode: runMode), callOptions: .init(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
		}

		guard let host = vmURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		let reply = try client.info(.with {
			$0.name = host
			$0.includeConfig = true
		}).response.wait().vms.status

		if reply.success == false {
			throw ServiceError(reply.reason)
		}

		return (VMInformations(reply.infos), CakedConfiguration(reply.config))
	}
}
