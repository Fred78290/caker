import Foundation

struct StorageLocation {
	let rootURL: URL

	init(asSystem: Bool) {
		self.rootURL = try! Utils.getHome(asSystem: asSystem).appendingPathComponent("vms", isDirectory: true)
	}

	private func vmURL(_ name: String) -> URL {
		rootURL.appendingPathComponent(name, isDirectory: true)
	}

	func exists(_ name: String) -> Bool {
		VMLocation(rootURL: vmURL(name)).inited
	}

	func find(_ name: String) throws -> VMLocation {
		let location = VMLocation(rootURL: vmURL(name))

		try location.validatate(userFriendlyName: name)

		try location.rootURL.updateAccessDate()

		return location
	}

	func relocate(_ name: String, from: VMLocation) throws {
		_ = try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
		_ = try FileManager.default.replaceItemAt(vmURL(name), withItemAt: from.rootURL)
	}
}