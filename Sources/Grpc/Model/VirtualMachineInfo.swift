//
//  VMInfos.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/04/2025.
//
import Foundation
import TextTable

public typealias VirtualMachineInfos = [VirtualMachineInfo]

extension VirtualMachineInfos {
	public init(from: [Caked_VirtualMachineInfo]) {
		self = from.compactMap {
			VirtualMachineInfo(from: $0)
		}
	}
}

public struct SuspendReply: Codable {
	public let name: String
	public let status: String
	public let suspended: Bool
	public let reason: String

	public init(from: Caked_SuspendedObject) {
		self.name = from.name
		self.status = from.status
		self.suspended = from.suspended
		self.reason = from.reason
	}

	public init(name: String, status: String, suspended: Bool, reason: String) {
		self.name = name
		self.status = status
		self.suspended = suspended
		self.reason = reason
	}

	public func toCaked_SuspendedObject() -> Caked_SuspendedObject {
		Caked_SuspendedObject.with { object in
			object.name = name
			object.status = status
			object.suspended = suspended
			object.reason = reason
		}
	}
}

public struct StopReply: Codable {
	public let name: String
	public let status: String
	public let stopped: Bool
	public let reason: String

	public init(from: Caked_StoppedObject) {
		self.name = from.name
		self.status = from.status
		self.stopped = from.stopped
		self.reason = from.reason
	}

	public init(name: String, status: String, stopped: Bool, reason: String) {
		self.name = name
		self.status = status
		self.stopped = stopped
		self.reason = reason
	}

	public func toCaked_StoppedObject() -> Caked_StoppedObject {
		Caked_StoppedObject.with { object in
			object.name = name
			object.status = status
			object.stopped = stopped
			object.reason = reason
		}
	}
}

public struct DeleteReply: Codable {
	public let source: String
	public let name: String
	public let deleted: Bool
	public let reason: String

	public init(from: Caked_DeletedObject) {
		self.source = from.source
		self.name = from.name
		self.deleted = from.deleted
		self.reason = from.reason
	}

	public init(source: String, name: String, deleted: Bool, reason: String) {
		self.name = name
		self.source = source
		self.deleted = deleted
		self.reason = reason
	}

	public func toCaked_DeletedObject() -> Caked_DeletedObject {
		Caked_DeletedObject.with { object in
			object.source = source
			object.name = name
			object.deleted = deleted
			object.reason = reason
		}
	}
}

public struct VirtualMachineInfo: Codable, Identifiable, Hashable {
	public typealias ID = String

	public let type: String
	public let source: String
	public let name: String
	public let fqn: [String]
	public let instanceID: String?
	public let diskSize: Int
	public let totalSize: Int
	public let state: String
	public let ip: String?
	public let fingerprint: String?

	public var id: String {
		self.instanceID ?? self.name
	}

	public init(from: Caked_VirtualMachineInfo) {
		self.type = from.type
		self.source = from.source
		self.name = from.name
		self.fqn = from.fqn
		self.instanceID = from.instanceID
		self.diskSize = Int(from.diskSize)
		self.totalSize = Int(from.totalSize)
		self.state = from.state
		self.ip = from.ip
		self.fingerprint = from.fingerprint
	}

	public init(type: String, source: String, name: String, fqn: [String], instanceID: String?, diskSize: Int, totalSize: Int, state: String, ip: String?, fingerprint: String?) {
		self.type = type
		self.source = source
		self.name = name
		self.fqn = fqn
		self.instanceID = instanceID
		self.diskSize = diskSize
		self.totalSize = totalSize
		self.state = state
		self.ip = ip
		self.fingerprint = fingerprint
	}

	public func toCaked_VirtualMachineInfo() -> Caked_VirtualMachineInfo {
		Caked_VirtualMachineInfo.with { info in
			info.type = self.type
			info.source = self.source
			info.name = self.name
			info.fqn = self.fqn
			info.diskSize = UInt64(self.diskSize)
			info.totalSize = UInt64(self.totalSize)
			info.state = self.state

			if let instanceID: String = self.instanceID {
				info.instanceID = instanceID
			}

			if let ip = self.ip {
				info.ip = ip
			}

			if let fingerprint = self.fingerprint {
				info.fingerprint = fingerprint
			}
		}
	}
}

public struct ShortVirtualMachineInfo: Codable {
	public let type: String
	public let name: String
	public let fqn: String
	public let instanceID: String
	public let ip: String
	public let diskSize: String
	public let totalSize: String
	public let state: String
	public let fingerprint: String

	public init(from: VirtualMachineInfo) {
		self.type = from.type
		self.name = from.name
		self.fqn = from.fqn.joined(separator: " ")
		self.ip = from.ip ?? ""
		self.instanceID = from.instanceID ?? ""
		self.diskSize = ByteCountFormatter.string(fromByteCount: Int64(from.diskSize), countStyle: .file)
		self.totalSize = ByteCountFormatter.string(fromByteCount: Int64(from.totalSize), countStyle: .file)
		self.state = from.state
		self.fingerprint = from.fingerprint != nil ? from.fingerprint!.substring(..<12) : ""
	}
}
