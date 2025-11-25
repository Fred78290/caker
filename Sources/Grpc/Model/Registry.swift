//
//  Registry.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//

public struct LoginReply: Codable {
	public var message: String
	public var success: Bool

	public init(success: Bool, message: String) {
		self.message = message
		self.success = success
	}

	public init(from: Caked_LoginReply) {
		self.message = from.message
		self.success = from.success
	}

	public var caked: Caked_LoginReply {
		Caked_LoginReply.with {
			$0.success = success
			$0.message = message
		}
	}
}

public struct LogoutReply: Codable {
	public var message: String
	public var success: Bool

	public init(success: Bool, message: String) {
		self.message = message
		self.success = success
	}

	public init(from: Caked_LogoutReply) {
		self.message = from.message
		self.success = from.success
	}

	public var caked: Caked_LogoutReply {
		Caked_LogoutReply.with {
			$0.success = success
			$0.message = message
		}
	}
}

public struct PullReply: Codable {
	public enum ImageTypeEnum: String, Codable, Equatable, CustomStringConvertible {
		case docker
		case tart
		case unknown

		public var description: String {
			self.rawValue
		}
	}

	public var message: String
	public var success: Bool
	public var imageType: ImageTypeEnum

	public init(_ imageType: ImageTypeEnum, success: Bool, message: String) {
		self.imageType = imageType
		self.message = message
		self.success = success
	}

	public init(from: Caked_PullReply) {
		self.imageType = ImageTypeEnum(rawValue: from.imageType)!
		self.message = from.message
		self.success = from.success
	}

	public var caked: Caked_PullReply {
		Caked_PullReply.with {
			$0.imageType = self.imageType.rawValue
			$0.success = success
			$0.message = message
		}
	}
}

public struct PushReply: Codable {
	public var message: String
	public var success: Bool

	public init(success: Bool, message: String) {
		self.message = message
		self.success = success
	}

	public init(from: Caked_PushReply) {
		self.message = from.message
		self.success = from.success
	}

	public var caked: Caked_PushReply {
		Caked_PushReply.with {
			$0.success = success
			$0.message = message
		}
	}
}
