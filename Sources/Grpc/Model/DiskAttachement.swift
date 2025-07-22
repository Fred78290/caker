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

public struct DiskAttachement: CustomStringConvertible, ExpressibleByArgument, Codable, Hashable, Identifiable {
	public var diskPath: String
	public var diskOptions: DiskOptions

	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.description == rhs.description
	}

	public var defaultValueDescription: String {
		"[local path|nbd://url|nbds://url|nbd+unix://url|nbds+unix://url][,ro][,sync=none|full][,caching=automatic|cached|uncached]"
	}

	public var description: String {
		var value: [String] = [diskPath]
		let options = self.diskOptions.description

		if !options.isEmpty {
			value.append(options)
		}

		return value.joined(separator: ":")
	}

	public var id: String {
		self.description
	}
	
	public struct DiskOptions: CustomStringConvertible, Codable, Hashable {
		public var readOnly: Bool = false
		public var syncMode: String = "none"
		public var cachingMode: String = VZDiskImageCachingMode.automatic.description

		public var description: String {
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

	public init() {
		self.diskPath = ""
		self.diskOptions = .init(readOnly: false, syncMode: "full", cachingMode: VZDiskImageCachingMode.automatic.description)
	}

	public init(diskPath: URL) {
		self.diskPath = diskPath.absoluteURL.path
		self.diskOptions = .init(readOnly: false, syncMode: "full", cachingMode: VZDiskImageCachingMode.automatic.description)
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

	public func configuration(relativeTo: URL) throws -> VZStorageDeviceConfiguration {
		if #available(macOS 14, *) {
			let diskURL = URL(string: diskPath)!
			
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

		let diskURL = URL(fileURLWithPath: self.diskPath.expandingTildeInPath, relativeTo: relativeTo).absoluteURL
		let diskPath = diskURL.path

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
					throw ValidationError("\(diskPath) already in use, try umounting it")
				case EACCES:
					throw ValidationError("\(diskPath) permission denied, consider changing the disk's owner using \"sudo chown $USER \(diskPath)\" or run as a superuser")
				default:
					throw ValidationError("\(details), \(diskPath)")
				}
			}

			let blockAttachment = try VZDiskBlockDeviceStorageDeviceAttachment(
				fileHandle: FileHandle(fileDescriptor: fd, closeOnDealloc: true),
				readOnly: self.diskOptions.readOnly,
				synchronizationMode: try VZDiskSynchronizationMode(description: self.diskOptions.syncMode))

			return VZVirtioBlockDeviceConfiguration(attachment: blockAttachment)
		}

		if try self.diskOptions.readOnly == false && !FileLock(lockURL: diskURL).trylock() {
			throw ValidationError("disk \(diskURL.path) seems to be already in use, unmount it first in Finder")
		}

		let diskImageAttachment = try VZDiskImageStorageDeviceAttachment(
			url: diskURL,
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
			let diskPath = diskPath.expandingTildeInPath

			if diskPath.isEmpty {
				throw ValidationError("Disk path is empty")
			}

			// Check if the disk path is a valid local file path
			if diskPath.contains("/") {
				if FileManager.default.fileExists(atPath: diskPath) == false {
					throw ValidationError("disk \(diskPath) does not exist")
				}

				if Self.isBlockingDevice(diskPath) {
					guard #available(macOS 14, *) else {
						throw ValidationError("Attaching block devices prior MacOS 14")
					}
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

extension DiskAttachement: Validatable {
	public func validate() -> Bool {
		if diskPath.isEmpty || diskOptions.syncMode.isEmpty || diskOptions.cachingMode.isEmpty {
			return false
		}

		return true
	}
}
