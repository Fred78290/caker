import ArgumentParser
import Foundation
import Virtualization

public typealias DirectorySharingAttachments = [DirectorySharingAttachment]

public struct DirectorySharingAttachment: CustomStringConvertible, ExpressibleByArgument, Codable, Sendable, Hashable, Identifiable {
	public var readOnly: Bool

	public var _name: String? = nil
	public var _source: String = ""
	public var _destination: String? = nil
	public var _uid: Int? = nil
	public var _gid: Int? = nil

	public var defaultValueDescription: String {
		"<source>[:<destination>][,ro][,name=<name>][,uid=<uid>][,gid=<gid>]"
	}

	public var name: String {
		get {
			if let name = _name {
				return name
			}

			return _source.dropFirst().replacingOccurrences(of: "/", with: "_")
		}
		set {
			_name = newValue
		}
	}

	public var human: String {
		if let name = _name {
			return name
		}

		return self.path.lastPathComponent
	}

	public var path: URL {
		URL(fileURLWithPath: _source.expandingTildeInPath)
	}

	public var source: String {
		get {
			_source
		}
		set {
			_source = newValue
		}
	}

	public var destination: String? {
		get {
			_destination
		}
		set {
			_destination = newValue
		}
	}

	public var uid: Int {
		get {
			_uid ?? 0
		}
		set {
			_uid = newValue
		}
	}

	public var gid: Int {
		get {
			_gid ?? 0
		}
		set {
			_gid = newValue
		}
	}

	public var options: [String] {
		var options: [String] = []

		if let uid = _uid {
			options.append("uid=\(uid)")
		}

		if let gid = _gid {
			options.append("gid=\(gid)")
		}

		if readOnly {
			options.append("ro")
		}

		return options
	}

	public var description: String {
		let options: [String] = self.options
		var result: String

		if let destination = _destination {
			result = "\(path.path):\(destination)"
		} else {
			result = path.path
		}

		if options.isEmpty == false {
			result = "\(result),\(options.joined(separator: ","))"
		}

		return result
	}

	public var id: String {
		self.description
	}

	public init(source: String = "~", destination: String? = nil, readOnly: Bool = false, name: String? = nil, uid: Int? = nil, gid: Int? = nil) {
		self.readOnly = readOnly
		self._name = name
		self._source = source.expandingTildeInPath
		self._destination = destination
		self._uid = uid
		self._gid = gid
	}

	public init?(argument: String) {
		do {
			try self.init(parseFrom: argument)
		} catch {
			return nil
		}
	}

	public init(parseFrom: String) throws {
		let arguments = try Self.parseOptions(parseFrom)
		self.init(source: arguments.source, destination: arguments.destination, readOnly: arguments.readOnly, name: arguments.name, uid: arguments.uid, gid: arguments.gid)
	}

	// format = source:destination,ro,tag=tag,name=name,uid=uid,gid=gid
	private static func parseOptions(_ description: String) throws -> (readOnly: Bool, name: String?, source: String, destination: String?, uid: Int?, gid: Int?) {
		let options = description.split(separator: ",")
		let arguments = options.first!.split(separator: ":")
		var readOnly: Bool = false
		var name: String? = nil
		var source: String
		var destination: String? = nil
		var uid: Int? = nil
		var gid: Int? = nil

		options.forEach { option in
			if option == "ro" {
				readOnly = true
			} else if option.hasPrefix("uid=") {
				uid = Int(option.dropFirst(4))
			} else if option.hasPrefix("gid=") {
				gid = Int(option.dropFirst(4))
			} else if option.hasPrefix("name=") {
				name = String(option.dropFirst(5))
			}
		}

		source = String(arguments[0])

		if arguments.count > 1 {
			destination = String(arguments[1])
		}

		if source.hasPrefix("http:") || source.hasPrefix("https:") {
			throw ValidationError("Remote directories are not supported")
		}

		return (readOnly, name, source, destination, uid, gid)
	}

	public var configuration: VZSharedDirectory? {
		if path.isFileURL {
			return VZSharedDirectory(url: path, readOnly: readOnly)
		}

		return nil
	}

	public mutating func resetUID() {
		_uid = nil
	}

	public mutating func resetGID() {
		_gid = nil
	}
}

extension DirectorySharingAttachment: Validatable {
	public func validate() -> Bool {
		if _source.isEmpty {
			return false
		}

		return true
	}
}
