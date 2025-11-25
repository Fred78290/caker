import ArgumentParser
//
//  ViewSize.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/10/2025.
//
import Foundation

public struct VMScreenSize: Identifiable, ExpressibleByArgument, CustomStringConvertible, Hashable, Sendable {
	public static let standard = VMScreenSize(width: 1024, height: 768)

	public var id: String {
		self.description
	}
	public var width: Int
	public var height: Int
	public var size: CGSize {
		.init(width: CGFloat(width), height: CGFloat(height))
	}

	public var description: String {
		"\(width)x\(height)"
	}

	public init?(argument: String) {
		do {
			try self.init(parseFrom: argument)
		} catch {
			return nil
		}
	}

	public init?(parseFrom: String) throws {
		let components = parseFrom.split(separator: "x")

		guard components.count == 2, let width = Int(String(components[0])), let height = Int(String(components[1])) else {
			throw NSError(domain: "Invalid view size format", code: 0, userInfo: nil)
		}

		self.width = width
		self.height = height
	}

	public init(width: Int, height: Int) {
		self.width = width
		self.height = height
	}
}

extension VMScreenSize {
	public func validating() throws -> VMScreenSize {
		guard width > 0, height > 0 else {
			throw NSError(domain: "Invalid view size format", code: 0, userInfo: nil)
		}

		return self
	}
}
