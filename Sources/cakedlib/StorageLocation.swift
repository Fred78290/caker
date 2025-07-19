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

	public init(runMode: Utils.RunMode, name: String = "vms") {
		self.template = name != "vms"
		self.rootURL = try! Utils.getHome(runMode: runMode).appendingPathComponent(name, isDirectory: true)
		try? FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
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

		try location.validatate(userFriendlyName: name).rootURL.updateAccessDate()

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
		_ = try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
		_ = try FileManager.default.replaceItemAt(vmURL(name), withItemAt: from.rootURL)
	}
}
