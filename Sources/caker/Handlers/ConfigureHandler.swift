//
//  ConfigureHandler.swift
//  CakerAppStore
//
//  Created by Frederic BOLTZ on 05/07/2026.
//

import Foundation
import CakedLib
import GRPCLib

extension ConfigureHandler {
	public static func configure(client: CakedServiceClient?, name: String, options: ConfigureOptions, runMode: Utils.RunMode) throws -> ConfiguredReply {

		guard let client = client else {
			return ConfigureHandler.configure(name: name, options: options, runMode: runMode)
		}

		return try ConfiguredReply(client.configure(Caked_ConfigureRequest(options: options)).response.wait().vms.configured)
	}
}
