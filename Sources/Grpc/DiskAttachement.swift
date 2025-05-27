import ArgumentParser
import Foundation
import System
import Virtualization

@available(macOS 14, *)
extension VZDiskSynchronizationMode: @retroactive CustomStringConvertible {
	public var description: String {
		if self == .none {
			return "none"
		}

		return "full"
	}

	public init?(rawValue: String) {
		do {
			try self.init(description: rawValue)
		} catch {
			return nil
		}
	}

	public init(description: String) throws {
		switch description {
		case "none":
			self = .none
		case "full":
			self = .full
		case "":
			self = .full
		default:
			throw ValidationError("Unsupported disk synchronization mode: \"\(description)\"")
		}
	}
}

extension VZDiskImageSynchronizationMode: @retroactive CustomStringConvertible {
	public var description: String {
		if self == .none {
			return "none"
		} else if self == .fsync {
			return "fsync"
		}

		return "full"
	}

	public init?(rawValue: String) {
		do {
			try self.init(description: rawValue)
		} catch {
			return nil
		}
	}

	public init(description: String) throws {
		switch description {
		case "none":
			self = .none
		case "fsync":
			self = .fsync
		case "full":
			self = .full
		case "":
			self = .full
		default:
			throw ValidationError("Unsupported disk image synchronization mode: \"\(description)\"")
		}
	}
}

extension VZDiskImageCachingMode: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
		case .automatic:
			return "automatic"
		case .cached:
			return "cached"
		case .uncached:
			return "uncached"
		@unknown default:
			fatalError()
		}
	}

	public init?(rawValue: String) {
		do {
			try self.init(description: rawValue)
		} catch {
			return nil
		}
	}

	public init(description: String) throws {
		switch description {
		case "automatic":
			self = .automatic
		case "cached":
			self = .cached
		case "uncached":
			self = .uncached
		case "":
			self = .uncached
		default:
			throw ValidationError("Unsupported disk image caching mode: \"\(description)\"")
		}
	}
}

public struct DiskAttachement: CustomStringConvertible, ExpressibleByArgument, Codable {
	public let diskPath: String
	private let diskOptions: DiskOptions

	public var defaultValueDescription: String {
		"[local path|nbd://url|nbds://url|nbd+unix://url|nbds+unix://url][,ro][,sync=none|full][,caching=automatic|cached|uncached]"
	}

	public var description: String {
		var value: [String] = [diskPath]
		let options = self.diskOptions.description

		if !value.isEmpty {
			value.append(options)
		}

		return value.joined(separator: ":")
	}

	private struct DiskOptions: CustomStringConvertible, Codable {
		let readOnly: Bool
		let syncMode: String
		let cachingMode: String

		var description: String {
			var options: [String] = []

			if readOnly {
				options.append("ro")
			}

			if !syncMode.isEmpty {
				options.append("sync=\(syncMode)")
			}

			if !cachingMode.isEmpty {
				options.append("caching=\(cachingMode)")
			}

			return options.joined(separator: ",")
		}

		static func parseOptions(_ parseFrom: String) -> (DiskOptions, Bool) {
			let options = parseFrom.split(separator: ",")
			var readOnly: Bool = false
			var syncMode: String = ""
			var cachingMode: String = ""
			var foundOptions: Bool = false

			options.forEach { option in
				if option == "ro" {
					readOnly = true
					foundOptions = true
				} else if option.hasPrefix("sync=") {
					syncMode = String(option.dropFirst("sync=".count))
					foundOptions = true
				} else if option.hasPrefix("caching=") {
					cachingMode = String(option.dropFirst("caching=".count))
					foundOptions = true
				}
			}

			return (.init(readOnly: readOnly, syncMode: syncMode, cachingMode: cachingMode), foundOptions)
		}
	}

	public init?(argument: String) {
		do {
			try self.init(parseFrom: argument)
		} catch {
			return nil
		}
	}

	public init(parseFrom: String) throws {
		(self.diskPath, self.diskOptions) = try Self.parseOptions(parseFrom)
	}

	public func configuration() throws -> VZStorageDeviceConfiguration {
		let diskURL = URL(string: diskPath)!
		let diskPath = NSString(string: diskPath).expandingTildeInPath
		let diskFileURL = URL(fileURLWithPath: diskPath)

		if #available(macOS 14, *) {
			if ["nbd", "nbds", "nbd+unix", "nbds+unix"].contains(diskURL.scheme) {
				let nbdAttachment = try VZNetworkBlockDeviceStorageDeviceAttachment(
					url: diskURL,
					timeout: 30,
					isForcedReadOnly: self.diskOptions.readOnly,
					synchronizationMode: try VZDiskSynchronizationMode(description: self.diskOptions.syncMode)
				)

				return VZVirtioBlockDeviceConfiguration(attachment: nbdAttachment)
			}
		}

		if FileManager.default.fileExists(atPath: diskPath) == false {
			throw ValidationError("disk \(diskPath) does not exist")
		}

		if Self.isBlockingDevice(diskPath) {
			guard #available(macOS 14, *) else {
				throw ValidationError("Attaching block devices prior MacOS 14")
			}

			let fd = open(diskPath, self.diskOptions.readOnly ? O_RDONLY : O_RDWR)

			if fd == -1 {
				let details = Errno(rawValue: CInt(errno))

				switch details.rawValue {
				case EBUSY:
					throw ValidationError("\(diskFileURL.path) already in use, try umounting it")
				case EACCES:
					throw ValidationError("\(diskFileURL.path) permission denied, consider changing the disk's owner using \"sudo chown $USER \(diskFileURL.path)\" or run as a superuser")
				default:
					throw ValidationError("\(details), \(diskFileURL.path)")
				}
			}

			let blockAttachment = try VZDiskBlockDeviceStorageDeviceAttachment(
				fileHandle: FileHandle(fileDescriptor: fd, closeOnDealloc: true),
				readOnly: self.diskOptions.readOnly,
				synchronizationMode: try VZDiskSynchronizationMode(description: self.diskOptions.syncMode))

			return VZVirtioBlockDeviceConfiguration(attachment: blockAttachment)
		}

		if try self.diskOptions.readOnly == false && !FileLock(lockURL: diskFileURL).trylock() {
			throw ValidationError("disk \(diskFileURL.path) seems to be already in use, unmount it first in Finder")
		}

		let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(
			url: diskFileURL,
			readOnly: self.diskOptions.readOnly,
			cachingMode: try VZDiskImageCachingMode(description: self.diskOptions.cachingMode),
			synchronizationMode: try VZDiskImageSynchronizationMode(description: self.diskOptions.syncMode)
		)

		return VZVirtioBlockDeviceConfiguration(attachment: diskImageAttachment)
	}

	private static func parseOptions(_ parseFrom: String) throws -> (String, DiskOptions) {
		var arguments = parseFrom.split(separator: ":")

		let options = DiskOptions.parseOptions(String(arguments.last!))

		if options.1 {
			arguments.removeLast()
		}

		let diskPath = arguments.joined(separator: ":")
		let diskURL = URL(string: diskPath)

		if ["nbd", "nbds", "nbd+unix", "nbds+unix"].contains(diskURL?.scheme) {
			guard #available(macOS 14, *) else {
				throw ValidationError("Attaching Network Block Devices are not supported prior MacOS 14")
			}
		} else {
			let diskPath = NSString(string: diskPath).expandingTildeInPath

			if diskPath.isEmpty {
				throw ValidationError("Disk path is empty")
			}

			if FileManager.default.fileExists(atPath: diskPath) == false {
				throw ValidationError("disk \(diskPath) does not exist")
			}

			if Self.isBlockingDevice(diskPath) {
				guard #available(macOS 14, *) else {
					throw ValidationError("Attaching block devices prior MacOS 14")
				}
			}
		}

		return (diskPath, options.0)
	}

	static func isBlockingDevice(_ path: String) -> Bool {
		var st: stat = stat()

		if stat(path, &st) < 0 {
			return false
		}

		return (st.st_mode & S_IFMT) == S_IFBLK
	}
}
