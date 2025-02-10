import Foundation
import Virtualization
import ArgumentParser

extension String {
	var expandingTildeInPath: String {
		if self.hasPrefix("~") {
			return NSString(string: self).expandingTildeInPath
		}

		return self
	}
}

public struct DirectorySharingAttachment: CustomStringConvertible, ExpressibleByArgument, Codable {
	public let readOnly: Bool
	
	let _name: String?
	let _mountTag: String?
	let _path: String

	public var name: String {
		if let name = _name {
			return name
		}
		
		return path.lastPathComponent
	}

	public var path: URL {
		URL(fileURLWithPath: _path.expandingTildeInPath)
	}

	public var mountTag: String {
		_mountTag ?? VZVirtioFileSystemDeviceConfiguration.macOSGuestAutomountTag
	}

	public var description: String {
		var options: [String] = []
		var result: String

		if readOnly {
			options.append("ro")
		}

		if let mountTag = _mountTag {
			options.append("tag=\(mountTag)")
		}

		if let name = self._name {
			result = "\(name):\(_path)"
		} else {
			result = _path
		}
		
		if !options.isEmpty {
			result += ":\(options.joined(separator: ","))"
		}

		return result
	}

	public init?(argument: String) {
		do {
			try self.init(parseFrom: argument)
		} catch {
			return nil
		}
	}

	public init(parseFrom: String) throws {
		(self.readOnly, self._mountTag, self._name, self._path) = try Self.parseOptions(parseFrom)
	}

	private static func parseOptions(_ description: String) throws -> (Bool, String?, String?, String) {
		var arguments = description.split(separator: ":")
		let options = arguments.last!.split(separator: ",")
		var readOnly: Bool = false
		var found: Bool = false
		var mountTag: String? = nil
		var name: String? = nil
		var path: String

		options.forEach { option in
			if option == "ro" {
				readOnly = true
				found = true
			} else if option.hasPrefix("tag=") {
				mountTag = String(option.dropFirst(4))
				found = true
			}
		}

		if found {
			arguments.removeLast()
		}

		if arguments.count > 1{
			name = String(arguments[0])
			path = String(arguments[1])
		} else {
			path = String(arguments[0])
		}

		if path.hasPrefix("http:") || path.hasPrefix("https:") {
			throw ValidationError("Remote directories are not supported")
		}

		return (readOnly, mountTag, name, path)
	}

	public var configuration: VZSharedDirectory? {
		if path.isFileURL {
			return VZSharedDirectory(url: path, readOnly: readOnly)
		}

		return nil
	}
}
