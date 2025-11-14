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
	public var message: String
	public var success: Bool
	
	public init(success: Bool, message: String) {
		self.message = message
		self.success = success
	}
	
	public init(from: Caked_PullReply) {
		self.message = from.message
		self.success = from.success
	}
	
	public var caked: Caked_PullReply {
		Caked_PullReply.with {
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

