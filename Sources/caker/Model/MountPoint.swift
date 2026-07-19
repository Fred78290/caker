//
//  MountPoint.swift
//  CakerAppStore
//
//  Created by Frederic BOLTZ on 23/06/2026.
//
import Foundation
import GRPCLib

typealias MountPoints = [MountPoint]

struct MountPoint: Identifiable, Hashable, Codable, Validatable {

	var shared: Bool
	var readOnly: Bool
	var name: String?
	var source: String
	var destination: String?
	var uid: Int?
	var gid: Int?

	var currentDestination: String {
		guard let destination else {
			if let name {
				return name
			}

			let source = self.source.expandingTildeInPath
			let name = source.dropFirst().replacingOccurrences(of: "/", with: "_")

			if name.count > 36 {
				let u = URL(fileURLWithPath: source)

				return u.lastPathComponent
			}

			return name
		}

		return destination
	}

	var currentName: String {
		if let name {
			return name
		}

		let source = self.source.expandingTildeInPath
		let name = source.dropFirst().replacingOccurrences(of: "/", with: "_")

		if name.count > 36 {
			let u = URL(fileURLWithPath: source)

			return u.lastPathComponent
		}

		return name
	}

	var options: [String] {
		var options: [String] = []

		if let uid {
			options.append("uid=\(uid)")
		}

		if let gid {
			options.append("gid=\(gid)")
		}

		if readOnly {
			options.append("ro")
		}

		if shared {
			options.append("shared")
		}

		return options
	}

	var description: String {
		let options: [String] = self.options
		var result: String

		if let destination {
			result = "\(source):\(destination)"
		} else {
			result = source
		}

		if options.isEmpty == false {
			result = "\(result),\(options.joined(separator: ","))"
		}

		return result
	}

	var id: String {
		self.description
	}

	var directorySharingAttachment: DirectorySharingAttachment {
		if self.shared {
			.init(source: source, readOnly: readOnly, name: name, uid: uid, gid: gid)
		} else {
			.init(source: source, destination: destination, readOnly: readOnly, name: name, uid: uid, gid: gid)
		}
	}

	init(source: String = "~/Public/", destination: String? = nil, readOnly: Bool = false, name: String? = nil, uid: Int? = nil, gid: Int? = nil) {
		self.shared = (destination ?? "").isEmpty
		self.readOnly = readOnly
		self.name = name
		self.source = source
		self.destination = destination
		self.uid = uid
		self.gid = gid
	}

	init(_ from: DirectorySharingAttachment) {
		self.readOnly = from.readOnly
		self.shared = (from._destination ?? "").isEmpty
		self.name = from._name
		self.source = from._source
		self.destination = from._destination
		self.uid = from.uid
		self.gid = from.gid
	}

	func validate() -> Bool {
		if self.source.isEmpty {
			return false
		}

		guard self.shared else {
			guard let destination, destination.isEmpty == false else {
				return false
			}

			return true
		}

		return true
	}

}
