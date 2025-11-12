import ArgumentParser
import Foundation
import GRPCLib
import Logging
import NIO

public struct CloneHandler {
	public static func clone(name: String, from: String, concurrency: UInt = 4, deduplicate: Bool = false, insecure: Bool = false, direct: Bool, runMode: Utils.RunMode) -> ClonedReply {
		do {
			if StorageLocation(runMode: runMode).exists(name) {
				return ClonedReply(sourceName: from, targetName: name, cloned: false, reason: "VM already exists")
			}
			
			if Utilities.checkIfTartPresent() == false {
				return ClonedReply(sourceName: from, targetName: name, cloned: false, reason: "Tart is not installed")
			}
			
			var arguments = [from, "\(name).cakedvm"]
			
			if concurrency != 4 {
				arguments.append("--concurrency=\(concurrency)")
			}
			
			if insecure {
				arguments.append("--insecure")
			}
			
			if deduplicate {
				arguments.append("--deduplicate")
			}
			
			try Shell.runTart(command: "clone", arguments: arguments, direct: direct, runMode: runMode)
			
			let location = try StorageLocation(runMode: runMode).find(name)
			let cakeConfig = try CakeConfig(location: location.rootURL, configuredUser: "admin", configuredPassword: "admin")
			
			try cakeConfig.save()
			
			return ClonedReply(sourceName: from, targetName: name, cloned: true, reason: "VM Cloned")
		} catch {
			return ClonedReply(sourceName: from, targetName: name, cloned: false, reason: "\(error)")
		}
	}
}
