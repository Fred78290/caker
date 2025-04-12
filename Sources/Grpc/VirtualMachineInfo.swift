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

public struct DeleteReply: Codable {
	public let source: String
	public let name: String
	public let deleted: Bool
	
	public init(from: Caked_DeletedObject) {
		self.source = from.source
		self.name = from.name
		self.deleted = from.deleted
	}
	
	public init(source: String, name: String, deleted: Bool) {
		self.name = name
		self.source = source
		self.deleted = deleted
	}
	
	public func toCaked_DeletedObject() -> Caked_DeletedObject{
		Caked_DeletedObject.with { object in
			object.source = source
			object.name = name
			object.deleted = deleted
		}
	}
}

public struct VirtualMachineInfo: Codable {
	public let type: String
	public let source: String
	public let name: String
	public let fqn: [String]
	public let instanceID: String?
	public let diskSize: UInt32
	public let totalSize: UInt32
	public let state: String
	public let ip: String?
	public let fingerprint: String?

	public init(from: Caked_VirtualMachineInfo) {
		self.type = from.type
		self.source = from.source
		self.name = from.name
		self.fqn = from.fqn
		self.instanceID = from.instanceID
		self.diskSize = from.diskSize
		self.totalSize = from.totalSize
		self.state = from.state
		self.ip = from.ip
		self.fingerprint = from.fingerprint
	}

	public init(type: String, source: String, name: String, fqn: [String], instanceID: String?, diskSize: UInt32, totalSize: UInt32, state: String, ip: String?, fingerprint: String?) {
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
			info.diskSize = self.diskSize
			info.totalSize = self.totalSize
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
	public let fqn: String
	public let instanceID: String
	public let ip: String
	public let diskSize: String
	public let totalSize: String
	public let state: String
	public let fingerprint: String

	public init(from: VirtualMachineInfo) {
		self.type = from.type
		self.fqn = from.fqn.joined(separator: " ")
		self.ip = from.ip ?? ""
		self.instanceID = from.instanceID ?? ""
		self.diskSize = ByteCountFormatter.string(fromByteCount: Int64(from.diskSize), countStyle: .file)
		self.totalSize = ByteCountFormatter.string(fromByteCount: Int64(from.totalSize), countStyle: .file)
		self.state = from.state
		self.fingerprint = from.fingerprint != nil ? from.fingerprint!.substring(..<12) : ""
	}
}
