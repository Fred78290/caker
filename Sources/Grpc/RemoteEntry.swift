//
//  RemoteEntry.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

public struct RemoteEntry: Codable {
	public let name: String
	public let url: String

	public init(name: String, url: String) {
		self.name = name
		self.url = url
	}

	public init(from: Caked_RemoteEntry) {
		self.name = from.name
		self.url = from.url
	}

	public func toCaked_RemoteEntry() -> Caked_RemoteEntry {
		Caked_RemoteEntry.with {
			$0.name = name
			$0.url = url
		}
	}
}

