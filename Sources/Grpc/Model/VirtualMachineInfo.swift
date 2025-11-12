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

public struct LaunchReply: Codable {
	public let name: String
	public let ip: String
	public let launched: Bool
	public let reason: String
	
	public init(from: Caked_LaunchReply) {
		self.name = from.name
		self.ip = from.address
		self.launched = from.launched
		self.reason = from.reason
	}

	public init(name: String, ip: String, launched: Bool, reason: String) {
		self.name = name
		self.ip = ip
		self.launched = launched
		self.reason = reason
	}

	public var caked: Caked_LaunchReply {
		Caked_LaunchReply.with { object in
			object.name = name
			object.launched = launched
			object.reason = reason
		}
	}
}

public struct StartedReply: Codable {
	public let name: String
	public let ip: String
	public let started: Bool
	public let reason: String
	
	public init(from: Caked_StartedReply) {
		self.name = from.name
		self.ip = from.address
		self.started = from.started
		self.reason = from.reason
	}

	public init(name: String, ip: String, started: Bool, reason: String) {
		self.name = name
		self.ip = ip
		self.started = started
		self.reason = reason
	}

	public var caked: Caked_StartedReply {
		Caked_StartedReply.with { object in
			object.name = name
			object.address = ip
			object.started = started
			object.reason = reason
		}
	}
}

public struct BuildedReply: Codable {
	public let name: String
	public let builded: Bool
	public let reason: String
	
	public init(from: Caked_BuildedReply) {
		self.name = from.name
		self.builded = from.builded
		self.reason = from.reason
	}

	public init(name: String, builded: Bool, reason: String) {
		self.name = name
		self.builded = builded
		self.reason = reason
	}

	public var caked: Caked_BuildedReply {
		Caked_BuildedReply.with { object in
			object.name = name
			object.builded = builded
			object.reason = reason
		}
	}
}

public struct ClonedReply: Codable {
	public let sourceName: String
	public let targetName: String
	public let cloned: Bool
	public let reason: String
	
	public init(from: Caked_ClonedReply) {
		self.sourceName = from.sourceName
		self.targetName = from.targetName
		self.cloned = from.cloned
		self.reason = from.reason
	}

	public init(sourceName: String, targetName: String, cloned: Bool, reason: String) {
		self.sourceName = sourceName
		self.targetName = targetName
		self.cloned = cloned
		self.reason = reason
	}

	public var caked: Caked_ClonedReply {
		Caked_ClonedReply.with { object in
			object.sourceName = sourceName
			object.targetName = targetName
			object.cloned = cloned
			object.reason = reason
		}
	}
}

public struct ConfiguredReply: Codable {
	public let name: String
	public let configured: Bool
	public let reason: String
	
	public init(from: Caked_ConfiguredReply) {
		self.name = from.name
		self.configured = from.configured
		self.reason = from.reason
	}

	public init(name: String, configured: Bool, reason: String) {
		self.name = name
		self.configured = configured
		self.reason = reason
	}

	public var caked: Caked_ConfiguredReply {
		Caked_ConfiguredReply.with { object in
			object.name = name
			object.configured = configured
			object.reason = reason
		}
	}
}

public struct DuplicatedReply: Codable {
	public let from: String
	public let to: String
	public let duplicated: Bool
	public let reason: String
	
	public init(from: Caked_DuplicatedReply) {
		self.from = from.from
		self.to = from.to
		self.duplicated = from.duplicated
		self.reason = from.reason
	}

	public init(from: String, to: String, duplicated: Bool, reason: String) {
		self.from = from
		self.to = to
		self.duplicated = duplicated
		self.reason = reason
	}

	public var caked: Caked_DuplicatedReply {
		Caked_DuplicatedReply.with { object in
			object.from = from
			object.to = to
			object.duplicated = duplicated
			object.reason = reason
		}
	}
}

public struct ImportedReply: Codable {
	public let source: String
	public let name: String
	public let imported: Bool
	public let reason: String
	
	public init(from: Caked_ImportedReply) {
		self.source = from.source
		self.name = from.name
		self.imported = from.imported
		self.reason = from.reason
	}

	public init(source: String, name: String, imported: Bool, reason: String) {
		self.source = source
		self.name = name
		self.imported = imported
		self.reason = reason
	}

	public var caked: Caked_ImportedReply {
		Caked_ImportedReply.with { object in
			object.name = name
			object.source = source
			object.imported = imported
			object.reason = reason
		}
	}
}

public struct WaitIPReply: Codable {
	public let name: String
	public let ip: String
	public let success: Bool
	public let reason: String
	
	public init(from: Caked_WaitIPReply) {
		self.name = from.name
		self.ip = from.ip
		self.success = from.success
		self.reason = from.reason
	}

	public init(name: String, ip: String, success: Bool, reason: String) {
		self.name = name
		self.ip = ip
		self.success = success
		self.reason = reason
	}

	public var caked: Caked_WaitIPReply {
		Caked_WaitIPReply.with { object in
			object.name = name
			object.ip = ip
			object.success = success
			object.reason = reason
		}
	}
}

public struct PurgeReply: Codable {
	public let purged: Bool
	public let reason: String
	
	public init(from: Caked_PurgeReply) {
		self.purged = from.purged
		self.reason = from.reason
	}

	public init(purged: Bool, reason: String) {
		self.purged = purged
		self.reason = reason
	}

	public var caked: Caked_PurgeReply {
		Caked_PurgeReply.with { object in
			object.purged = purged
			object.reason = reason
		}
	}
}

public struct RenameReply: Codable {
	public let newName: String
	public let oldName: String
	public let renamed: Bool
	public let reason: String
	
	public init(from: Caked_RenameReply) {
		self.oldName = from.oldName
		self.newName = from.newName
		self.renamed = from.renamed
		self.reason = from.reason
	}

	public init(oldName: String, newName: String, renamed: Bool, reason: String) {
		self.oldName = oldName
		self.newName = newName
		self.renamed = renamed
		self.reason = reason
	}

	public var caked: Caked_RenameReply {
		Caked_RenameReply.with { object in
			object.oldName = oldName
			object.newName = newName
			object.renamed = renamed
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
