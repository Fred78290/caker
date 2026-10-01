//
//  TaskEntryRepresentation.swift
//  Caker
//

public struct TaskEntryRepresentation: Codable {
	public var id: String
	public var title: String

	public init(_ from: Caked_TaskEntry) {
		self.id = from.id
		self.title = from.title
	}
}
