import Foundation
import Virtualization
import ArgumentParser

public typealias DirectorySharingAttachments = [DirectorySharingAttachment]

public struct DirectorySharingAttachment: CustomStringConvertible, ExpressibleByArgument, Codable, Sendable {
	public let readOnly: Bool
	
	let _name: String?
	let _source: String
	let _destination: String?
	let _uid: Int?
	let _gid: Int?

	public var defaultValueDescription: String {
		"<source>[:<destination>][,ro][,name=<name>][,uid=<uid>][,gid=<gid>]"
	}

	public var name: String {
		if let name = _name {
			return name
		}
		
		return _source.dropFirst().replacingOccurrences(of: "/", with: "_")
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
		_source
	}

	public var destination: String? {
		_destination
	}

	public var uid: Int {
		_uid ?? 0
	}

	public var gid: Int {
		_gid ?? 0
	}

	public var options: [String] {
		var options: [String] = []

		if readOnly {
			options.append("ro")
		}

		if let name = _name {
			options.append("name=\(name)")
		}

		if let uid = _uid {
			options.append("uid=\(uid)")
		}

		if let gid = _gid {
			options.append("gid=\(gid)")
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

	public init(source: String, destination: String? = nil, readOnly: Bool = false, name: String? = nil, uid: Int? = nil, gid: Int? = nil) {
		self.readOnly = readOnly
		self._name = name
		self._source = source
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
		(self.readOnly, self._name, self._source, self._destination, self._uid, self._gid) = try Self.parseOptions(parseFrom)
	}

	// format = source:destination,ro,tag=tag,name=name,uid=uid,gid=gid
	private static func parseOptions(_ description: String) throws -> (Bool, String?, String, String?, Int?, Int?) {
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
}
