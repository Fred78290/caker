//
//  RemoteEntry.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//

public struct RemoteEntry: Identifiable, Equatable, Hashable, Codable {
	public let name: String
	public let url: String

	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.url == rhs.url && lhs.name == rhs.name
	}

	public var id: String {
		self.url
	}
	
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
