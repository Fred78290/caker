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
import SwiftUI

extension InfosHandler {
	public static func infos(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> (infos: VMInformations, config: any VirtualMachineConfiguration) {
		guard let client, vmURL.isFileURL == false else {
			return try self.infos(vmURL: vmURL, runMode: runMode, client: try CakeAgentHelper.createCakeAgentHelper(vmURL: vmURL, runMode: runMode), callOptions: .init(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
		}

		let reply = try client.info(.with {
			$0.name = vmURL.vmName
			$0.includeConfig = true
		}).response.wait().vms.status

		if reply.success == false {
			throw ServiceError(reply.reason)
		}

		return (VMInformations(reply.infos), CakedConfiguration(reply.config))
	}
}
