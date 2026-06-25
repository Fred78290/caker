import Foundation
import GRPCLib

extension NSError {
	func fileNotFound() -> Bool {
		return self.code == NSFileNoSuchFileError || self.code == NSFileReadNoSuchFileError
	}
}

extension Error {
	func fileNotFound() -> Bool {
		let nsError: NSError = self as NSError

		return nsError.fileNotFound()
			|| nsError.underlyingErrors.contains(where: {
				$0.fileNotFound()
			})
	}
}

public struct StorageLocation {
	public let rootURL: URL
	public let template: Bool

	public init(_ home: Home, runMode: Utils.RunMode, name: String = "vms") {
		self.template = name != "vms"
		self.rootURL = home.cakeHomeDirectory.appendingPathComponent(name, isDirectory: true)
		try? FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
	}

	public init(runMode: Utils.RunMode, name: String = "vms") {
		self.init(try! Home(runMode: runMode), runMode: runMode, name: name)
	}

	public init(runMode: Utils.RunMode, template: Bool) {
		self.init(runMode: runMode, name: template ? "templates" : "vms")
	}

	private func vmURL(_ name: String) -> URL {
		if name.starts(with: "vm://") {
			return rootURL.appendingPathComponent(String(name.dropFirst("vm://".count)), isDirectory: true)
		}

		return rootURL.appendingPathComponent("\(name).cakedvm", isDirectory: true)
	}

	public func exists(_ name: String) -> Bool {
		VMLocation(rootURL: vmURL(name), template: self.template).inited
	}

	public func location(_ name: String) -> VMLocation {
		VMLocation(rootURL: vmURL(name), template: self.template)
	}

	public func find(_ name: String) throws -> VMLocation {
		let location = self.location(name)

		try location.validate().rootURL.updateAccessDate()

		return location
	}

	public func list() throws -> [String: VMLocation] {
		do {
			let vms: [VMLocation] = try FileManager.default.contentsOfDirectory(
				at: rootURL,
				includingPropertiesForKeys: [.isDirectoryKey],
				options: .skipsSubdirectoryDescendants
			).compactMap { url in
				let vmDir = VMLocation(rootURL: url, template: self.template)

				if !vmDir.inited {
					return nil
				}

				return vmDir
			}
			var result: [String: VMLocation] = [:]

			for vm in vms {
				result[vm.name] = vm
			}

			return result
		} catch {
			if error.fileNotFound() {
				return [:]
			}

			throw error
		}
	}

	public func relocate(_ name: String, from: VMLocation) throws {
		let vmURL = vmURL(name)
		
		_ = try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
		do {
			_ = try FileManager.default.replaceItemAt(vmURL, withItemAt: from.rootURL)
		} catch let nsError as NSError where nsError.domain == NSCocoaErrorDomain {
			guard let nsError = nsError.underlyingErrorForDomain(NSPOSIXErrorDomain), nsError.code == POSIXError.EXDEV.rawValue else {
				throw nsError
			}
			
			try FileManager.default.copyItem(at: from.rootURL, to: vmURL)
			try? FileManager.default.removeItem(at: from.rootURL)
		}
	}
}

extension NSError {
	func underlyingErrorForDomain(_ userDomain: String) -> NSError? {
		return self.underlyingErrors.compactMap {
			let error = $0 as NSError

			if error.domain == userDomain {
				return error
			}

			return error.underlyingErrorForDomain(userDomain)
		}.first
	}
}

extension StorageLocation: PurgeableStorage {
	func type() -> String {
		"file"
	}

	func fqn(_ purgeable: any Purgeable) -> [String] {
		[purgeable.url.absoluteString]
	}

	func purgeables() throws -> [any Purgeable] {
		return try self.list().compactMap {
			if case .running = $1.status { return nil }
			return $1
		}
	}

}

