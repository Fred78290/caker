//
//  Compose.swift
//  Caker
//
//  Created by Frederic BOLTZ on 26/06/2026.
//
public struct ComposeReplyUp: Codable {
	public var name: String
	public var success: Bool
	public var reason: String

	public init(name: String, success: Bool, reason: String) {
		self.name = name
		self.success = success
		self.reason = reason
	}

	public init(_ from: Caked_ComposeReply.ComposeReplyUp) {
		self.name = from.name
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_ComposeReply.ComposeReplyUp {
		.with {
			$0.name = self.name
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct ComposeReplyDown: Codable {
	public var name: String
	public var success: Bool
	public var reason: String

	public init(name: String, success: Bool, reason: String) {
		self.name = name
		self.success = success
		self.reason = reason
	}

	public init(_ from: Caked_ComposeReply.ComposeReplyDown) {
		self.name = from.name
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_ComposeReply.ComposeReplyDown {
		.with {
			$0.name = self.name
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct ComposeReplyDelete: Codable {
	public var name: String
	public var success: Bool
	public var reason: String

	public init(name: String, success: Bool, reason: String) {
		self.name = name
		self.success = success
		self.reason = reason
	}

	public init(_ from: Caked_ComposeReply.ComposeReplyDelete) {
		self.name = from.name
		self.success = from.success
		self.reason = from.reason
	}

	public var caked: Caked_ComposeReply.ComposeReplyDelete {
		.with {
			$0.name = self.name
			$0.success = self.success
			$0.reason = self.reason
		}
	}
}

public struct ComposeServiceInfo: Codable {
	public var name: String
	public var image: String
	public var status: String
	public var running: Bool

	public init(name: String, image: String, status: String, running: Bool) {
		self.name = name
		self.image = image
		self.status = status
		self.running = running
	}

	public init(_ from: Caked_ComposeReply.ComposeServiceInfo) {
		self.name = from.serviceName
		self.image = from.image
		self.status = from.status
		self.running = from.running
	}

	public var caked: Caked_ComposeReply.ComposeServiceInfo {
		.with {
			$0.serviceName = self.name
			$0.image = self.image
			$0.status = self.status
			$0.running = self.running
		}
	}
}

public struct ComposeReplyPs: Codable {
	public var name: String
	public var services: [ComposeServiceInfo]
	public var success: Bool
	public var reason: String

	public init(name: String, services: [ComposeServiceInfo], success: Bool, reason: String) {
		self.name = name
		self.services = services
		self.success = success
		self.reason = reason
	}

	public init(_ from: Caked_ComposeReply.ComposeReplyPs) {
		self.name = from.composeName
		self.success = from.success
		self.reason = from.reason
		self.services = from.services.map { ComposeServiceInfo($0) }
	}

	public var caked: Caked_ComposeReply.ComposeReplyPs {
		.with {
			$0.composeName = self.name
			$0.success = self.success
			$0.reason = self.reason
			$0.services = self.services.map { $0.caked }
		}
	}
}

public struct ComposeReplyList: Codable {
	public struct ComposeInfo: Codable {
		public var name: String
		public var services: [ComposeServiceInfo]

		public var caked: Caked_ComposeReply.ComposeReplyList.ComposeInfo {
			.with {
				$0.composeName = self.name
				$0.services = self.services.map { $0.caked }
			}
		}

		public init(name: String, services: [ComposeServiceInfo]) {
			self.name = name
			self.services = services
		}

		public init(_ from: Caked_ComposeReply.ComposeReplyList.ComposeInfo) {
			self.name = from.composeName
			self.services = from.services.map { ComposeServiceInfo($0) }
		}
	}

	public var composeFiles: [ComposeInfo]
	public var success: Bool
	public var reason: String

	public var caked: Caked_ComposeReply.ComposeReplyList {
		.with {
			$0.composeFiles = self.composeFiles.map { $0.caked }
			$0.success = self.success
			$0.reason = self.reason
		}
	}

	public init(composeFiles: [ComposeInfo], success: Bool, reason: String) {
		self.composeFiles = composeFiles
		self.success = success
		self.reason = reason
	}

	public init(_ from: Caked_ComposeReply.ComposeReplyList) {
		self.composeFiles = from.composeFiles.map { ComposeInfo($0) }
		self.success = from.success
		self.reason = from.reason
	}
}
