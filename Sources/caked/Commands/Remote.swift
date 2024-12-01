import Foundation
import ArgumentParser

struct Remote: ParsableCommand {
	static var configuration = CommandConfiguration(abstract: "caked as launchctl agent",
	                                                subcommands: [AddRemote.self, DeleteRemote.self, ListRemote.self])
	static let SyncSemaphore = DispatchSemaphore(value: 0)

	struct AddRemote : ParsableCommand {
		mutating func run() throws {
		}
	}

	struct DeleteRemote : ParsableCommand {
		mutating func run() throws {
		}
	}

	struct ListRemote : ParsableCommand {
		mutating func run() throws {
		}
	}
}

