//
//  StartHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/02/2026.
//
import Foundation
import CakedLib
import GRPCLib
import GRPC
import NIO

extension StartHandler {
	public static func startVM(client: CakedServiceClient?, rootURL: URL, screenSize: GRPCLib.ViewSize?, vncPassword: String?, vncPort: Int?, waitIPTimeout: Int, startMode: StartMode, runMode: Utils.RunMode, promise: EventLoopPromise<String>? = nil) throws -> StartedReply {

		guard let client else {
			return try startVM(rootURL: rootURL, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode, promise: promise)
		}

		if rootURL.isFileURL {
			return try startVM(rootURL: rootURL, screenSize: screenSize, vncPassword: vncPassword, vncPort: vncPort, waitIPTimeout: waitIPTimeout, startMode: startMode, runMode: runMode, promise: promise)
		}

		guard let host = rootURL.host(percentEncoded: false) else {
			throw ServiceError("Internal error")
		}

		return try StartedReply(client.start(.with {
			$0.name = host
			if let screenSize {
				$0.screenSize = .with {
					$0.width = Int32(screenSize.width)
					$0.height = Int32(screenSize.height)
				}
			}

			if let vncPassword {
				$0.vncPassword = vncPassword
			}
			if let vncPort {
				$0.vncPort = Int32(vncPort)
			}
			$0.waitIptimeout = Int32(waitIPTimeout)
		}).response.wait().vms.started)
	}
}
