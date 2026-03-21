//
//  ViewSize.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/09/2025.
//

import Foundation
import SwiftUI
import GRPCLib

final class ViewSize: ObservableObject, Observable, Equatable, Codable {
	@Published var width: CGFloat = 0
	@Published var height: CGFloat = 0

	static let zero: ViewSize = .init(width: 0, height: 0)
	static let standard: ViewSize = .init(width: 1280, height: 720)

	enum CodingKeys: String, CodingKey {
		case width
		case height
	}

	var size: GRPCLib.ViewSize {
		get {
			return .init(width: Int(width), height: Int(height))
		}
		set {
			width = CGFloat(newValue.width)
			height = CGFloat(newValue.height)
		}
	}

	var cgSize: CGSize {
		get {
			return .init(width: width, height: height)
		}
		set {
			width = newValue.width
			height = newValue.height
		}
	}

	var description: String {
		return "(\(width), \(height))"
	}

	init(width: CGFloat, height: CGFloat) {
		self.width = width
		self.height = height
	}

	init(_ size: CGSize) {
		self.width = size.width
		self.height = size.height
	}

	init(_ size: GRPCLib.ViewSize) {
		self.width = CGFloat(size.width)
		self.height = CGFloat(size.height)
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<ViewSize.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		self.width = try container.decode(CGFloat.self, forKey: .width)
		self.height = try container.decode(CGFloat.self, forKey: .height)
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(self.width, forKey: .width)
		try container.encode(self.height, forKey: .height)
	}

	func toJSON() throws -> Data {
		let encoder = JSONEncoder()

		encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]

		return try encoder.encode(self)
	}

	static func fromJSON(fromJSON: Data) throws -> ViewSize {
		return try JSONDecoder().decode(Self.self, from: fromJSON)
	}

	static func == (lhs: ViewSize, rhs: ViewSize) -> Bool {
		return lhs.width == rhs.width && lhs.height == rhs.height
	}
}
